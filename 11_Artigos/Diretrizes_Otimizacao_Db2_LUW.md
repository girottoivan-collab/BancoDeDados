# Diretrizes de otimização no Db2 LUW: catálogo, exemplos e critérios de uso

**Referência:** Db2 LUW 11.5; caso prático em 11.5.9.0, MEUPRATA. **Data:** 19/10/2026.

Este artigo reúne as famílias públicas de optimization guidelines documentadas para o Db2 LUW 11.5. A abrangência inclui acesso, junções, reescrita, parâmetros gerais, XML, MQTs e particionamento computacional. Não existe uma lista única válida para todos os produtos chamados Db2: Db2 for z/OS, Db2 for i e versões posteriores do LUW possuem mecanismos e diferenças próprios. A autoridade final de sintaxe é o **Current Optimization Profile Schema — COPS**, também distribuído como `sqllib/misc/DB2OptProfile.xsd` na instalação que o fornece. Validar o esquema do servidor e seu nível de manutenção antes de usar extensões. [IBM: COPS 11.5](https://www.ibm.com/docs/en/db2/11.5.x?topic=guidelines-current-optimization-profile-schema).

Os exemplos são didáticos, exceto a medição explicitamente identificada como MEUPRATA. Ganho potencial significa uma hipótese técnica para teste, sem percentual garantido. Não foram criados índices ou perfis para elaborar este artigo.

## 1. O que uma diretriz controla

O compilador transforma o SQL e depois escolhe acessos e junções. Uma diretriz pode interferir na reescrita, no espaço de alternativas ou em partes do plano. É possível direcionar somente um acesso e deixar o restante livre. Essas três famílias são distinguidas pela documentação da IBM. [IBM: tipos de diretrizes](https://www.ibm.com/docs/en/db2/11.1.0?topic=guidelines-types-optimization).

Existem duas formas usuais de fornecê-las:

- **Embutida:** comentário XML ao final da instrução, antes do terminador.
- **Perfil externo:** documento XML com `OPTPROFILE`, `STMTPROFILE`, `STMTKEY` e `OPTGUIDELINES`, associado ao contexto de compilação.

```sql
SELECT CR.IDEMPRESA, CR.IDTITULO, CR.DTVENCIMENTO
FROM DBA.CONTAS_RECEBER CR
WHERE CR.IDEMPRESA = 1
  AND CR.DTVENCIMENTO = DATE('2026-10-18')
FOR READ ONLY
/* <OPTGUIDELINES>
     <IXSCAN TABLE='CR' INDEX='CON_REC_IDEDTVFBX'/>
   </OPTGUIDELINES> */;
```

O comentário deve chegar intacto ao servidor; ferramentas que removem comentários podem retirar a diretriz. Um pedido inválido ou inaplicável pode ser ignorado e produzir advertência: a consulta executar não comprova que ele foi obedecido. [IBM: perfis e guidelines](https://www.ibm.com/docs/en/db2/11.5.0?topic=plans-optimization-profiles-guidelines).

## 2. Catálogo de acesso aos dados

| Elemento | Pedido |
|---|---|
| `IXSCAN` | Acesso por índice relacional |
| `TBSCAN` | Varredura da tabela |
| `LPREFETCH` | Acesso com list prefetch |
| `IXAND` | Interseção de acessos por índices |
| `IXOR` | Combinação OR de acessos por índices |
| `ACCESS` | Deixar o método ao otimizador, identificando a entrada |
| `XISCAN` | Acesso por índice XML |
| `XANDOR` | Combinação especializada de índices XML |

Os pedidos de método concreto destinam-se a tabelas locais. Não se deve aplicar `IXSCAN` diretamente ao resultado de uma subconsulta ou a um nickname remoto. Para entrada derivada, utiliza-se `ACCESS`. [IBM: access requests](https://www.ibm.com/docs/en/db2/11.5.x?topic=guidelines-access-requests).

### 2.1 IXSCAN: corrigir o caminho de leitura

**Problema:** índice aparentemente seletivo provoca buscas de muitos registros históricos e descarte posterior pela data.

```xml
<OPTGUIDELINES>
  <IXSCAN TABLE='CR' INDEX='CON_REC_IDEDTVFBX'/>
</OPTGUIDELINES>
```

`TABLE` identifica o alias exposto; `INDEX` identifica o índice. Sem `INDEX`, pede-se acesso por índice deixando sua escolha ao otimizador.

**Ganho potencial:** reduzir leituras e acessos à tabela base. **Risco:** o índice escolhido pode piorar consultas de intervalo amplo. Não basta encontrar `IXSCAN` no plano: conferir START/STOP, predicados e FETCHes. Um índice também pode evitar ordenação ou permitir acesso index-only, dependendo das colunas disponíveis. [IBM: acesso por index scans](https://www.ibm.com/docs/en/db2/11.5.x?topic=methods-data-access-through-index-scans).

### 2.2 TBSCAN: quando ler sequencialmente é melhor

```sql
SELECT SUM(V.VALOR)
FROM DBA.VENDAS V
WHERE V.ANO = 2026
/* <OPTGUIDELINES><TBSCAN TABLE='V'/></OPTGUIDELINES> */;
```

**Problema:** consulta analítica lê grande parte da tabela por um índice mal agrupado, gerando muitas leituras dispersas. **Ganho potencial:** substituir acessos aleatórios por leitura mais sequencial. **Risco:** péssima escolha para poucas linhas em tabela enorme. O fato de retornar uma única soma não significa que processa poucos registros. O otimizador normalmente considera tamanho, proporção lida e agrupamento do índice ao comparar scan e índice. [IBM: comparação de acessos](https://www.ibm.com/docs/en/db2/11.5.x?topic=methods-data-access-through-index-scans).

### 2.3 LPREFETCH: organizar a leitura das páginas

```xml
<OPTGUIDELINES>
  <LPREFETCH TABLE='CR' INDEX='CON_REC_IDEDTVFBX'/>
</OPTGUIDELINES>
```

**Problema:** o índice localiza muitos RIDs espalhados. **Ganho potencial:** organizar esses identificadores e antecipar páginas, reduzindo espera de I/O. **Risco:** preparação da lista e consumo de memória podem aumentar a latência da primeira linha; não é necessariamente melhor para poucas linhas. O índice informado precisa ser relacional. [IBM: exemplos de plano](https://www.ibm.com/docs/en/db2/12.1?topic=guidelines-plan-optimization), [IBM: restrições de índices](https://www.ibm.com/docs/en/db2/11.5.x?topic=messages-exp).

### 2.4 IXAND: combinar filtros AND

Suponha índices existentes `IX_PED_CLIENTE` e `IX_PED_STATUS` em `PEDIDOS`:

```sql
SELECT P.IDPEDIDO
FROM DBA.PEDIDOS P
WHERE P.IDCLIENTE = 100 AND P.STATUS = 'A'
/* <OPTGUIDELINES>
     <IXAND TABLE='P'>
       <INDEX IXNAME='IX_PED_CLIENTE'/>
       <INDEX IXNAME='IX_PED_STATUS'/>
     </IXAND>
   </OPTGUIDELINES> */;
```

**Problema:** cada filtro isolado deixa candidatos demais. **Ganho potencial:** intersectar candidatos antes do acesso à tabela. **Risco:** processar dois índices pode custar mais que um índice composto adequado. `INDEX='nome'` indica um índice inicial; filhos `INDEX IXNAME` especificam o conjunto e a sequência. Não confundir os dois formatos. [IBM: index ANDing](https://public.dhe.ibm.com/ps/products/db2/info/vr121/pdf/en_US/db2_perf_tune_1212.pdf).

### 2.5 IXOR: atender alternativas OR

```sql
SELECT P.IDPEDIDO
FROM DBA.PEDIDOS P
WHERE P.IDCLIENTE = 100 OR P.IDVENDEDOR = 20
/* <OPTGUIDELINES><IXOR TABLE='P'/></OPTGUIDELINES> */;
```

**Problema:** um OR entre colunas leva a uma leitura extensa. **Ganho potencial:** combinar acessos indexáveis para as alternativas. **Risco:** alternativas pouco seletivas geram listas grandes. É necessário haver predicados e índices elegíveis. `IXOR` não recebe uma lista arbitrária de índices neste formato: o otimizador seleciona predicados e índices. [IBM: index ORing](https://www.ibm.com/docs/en/db2/11.1.0?topic=requests-index-oring-access).

### 2.6 ACCESS: controlar uma parte sem fixar tudo

```xml
<OPTGUIDELINES>
  <JOIN>
    <ACCESS TABLE='C'/>
    <ACCESS TABLE='P'/>
  </JOIN>
</OPTGUIDELINES>
```

**Problema:** deseja-se controlar a composição da junção, preservando a liberdade dos acessos. **Ganho potencial:** corrigir uma decisão sem fixar índices desnecessariamente. **Risco:** a composição imposta também pode envelhecer. `ACCESS` sozinho não significa acesso por índice nem ausência de scan. [IBM: access requests](https://www.ibm.com/docs/en/db2/11.5.x?topic=guidelines-access-requests).

## 3. Junções e ordem das entradas

### 3.1 NLJOIN: poucas linhas externas e busca interna eficiente

```xml
<OPTGUIDELINES>
  <NLJOIN>
    <IXSCAN TABLE='CR' INDEX='CON_REC_IDEDTVFBX'/>
    <ACCESS TABLE='BANDEIRA'/>
  </NLJOIN>
</OPTGUIDELINES>
```

**Problema:** a tabela grande começa a junção por um filtro pouco eficaz. **Ganho potencial:** iniciar pelo conjunto reduzido e fazer buscas internas pontuais. **Risco:** cardinalidade externa subestimada multiplica trabalho. Em cada pedido binário, o primeiro filho representa a entrada externa e o segundo a interna; filhos podem ser acessos ou outras junções. O pedido depende da disponibilidade do método no espaço de busca. [IBM: diretrizes de junção](https://www.ibm.com/docs/en/db2/11.1.0?topic=guidelines-plan-optimization).

### 3.2 HSJOIN: evitar buscas repetidas em conjuntos grandes

```xml
<OPTGUIDELINES>
  <HSJOIN>
    <ACCESS TABLE='P'/>
    <ACCESS TABLE='C'/>
  </HSJOIN>
</OPTGUIDELINES>
```

**Problema:** nested loops executam muitas buscas internas para uma junção de igualdade volumosa. **Ganho potencial:** processamento por hash. **Risco:** memória insuficiente e spill para temporários. Não presumir o lado de construção física apenas pela ordem escrita: confirmar os argumentos do operador no plano. O pedido pode ser ignorado se o método não estiver disponível. [IBM: hash join requests](https://www.ibm.com/docs/en/db2/11.5.x?topic=requests-hash-join).

### 3.3 MSJOIN: aproveitar fluxos ordenados

```xml
<OPTGUIDELINES>
  <MSJOIN>
    <IXSCAN TABLE='P' INDEX='IX_PED_CLIENTE'/>
    <IXSCAN TABLE='C' INDEX='PK_CLIENTES'/>
  </MSJOIN>
</OPTGUIDELINES>
```

**Problema:** duas entradas grandes podem ser percorridas por chaves compatíveis. **Ganho potencial:** merge com menor trabalho repetido. **Risco:** sorts adicionais anulam a vantagem; selecionar índices não garante a ordenação necessária. O nome XML é `MSJOIN`, e não `MERGEJOIN`. [IBM: merge join requests](https://www.ibm.com/docs/en/db2/11.1?topic=requests-merge-join).

### 3.4 JOIN e FIRST: restringir composição ou ponto inicial

`JOIN` deixa o método livre. O atributo `FIRST='TRUE'` pode identificar o acesso ou resultado de junção que deve iniciar a sequência correspondente:

```xml
<OPTGUIDELINES>
  <IXSCAN TABLE='CR' INDEX='CON_REC_IDEDTVFBX' FIRST='TRUE'/>
</OPTGUIDELINES>
```

**Problema:** o índice está correto, mas o otimizador inicia por outra tabela. **Ganho potencial:** reduzir linhas cedo. **Risco:** maior rigidez. Existe restrição a múltiplos FIRST no mesmo FROM; pedidos aninhados precisam referenciar entradas compatíveis no SQL otimizado. [IBM: ordem de junção e FIRST](https://www.ibm.com/docs/en/db2/12.1?topic=guidelines-plan-optimization).

### 3.5 Star join por IXAND

```xml
<OPTGUIDELINES>
  <IXAND TABLE='F' STARJOIN='TRUE'/>
</OPTGUIDELINES>
```

**Problema:** tabela fato muito grande com filtros seletivos nas dimensões. **Ganho potencial:** combinar restrições das dimensões para diminuir acessos à fato. **Risco:** o pedido exige estrutura e índices elegíveis. É uma modalidade de `IXAND`, não uma tag autônoma `STARJOIN`. Pode conter `NLJOIN` de semijoins, cuja entrada interna acessa por índice a própria fato. Há restrições de aninhamento. [IBM: star join e diagnósticos](https://www.ibm.com/docs/en/db2/11.1.0?topic=messages-exp0000-exp0499).

Operadores do EXPLAIN não correspondem automaticamente a tags públicas. Não inventar `<SORT>`, `<FETCH>`, `<FILTER>` ou `<ZZJOIN>` apenas porque aparecem operações parecidas no plano. Para zigzag, conferir as regras e o mecanismo exposto no nível de manutenção utilizado. [IBM: diagnósticos de zigzag](https://www.ibm.com/docs/en/db2/11.5.x?topic=messages-exp).

## 4. Diretrizes de reescrita

Cada fragmento abaixo deve ser colocado dentro de `OPTGUIDELINES` e, quando embutido em SQL, dentro do comentário final.

| Diretriz e exemplo | Problema candidato | Ganho potencial e limite |
|---|---|---|
| `<INLIST2JOIN TABLE='P' COLUMN='STATUS' OPTION='ENABLE'/>` | Lista IN cuja transformação pode melhorar o acesso | Criar alternativa de junção; medir o custo adicional |
| `<SUBQ2JOIN OPTION='ENABLE'/>` | Predicados com subconsulta elegível, como EXISTS ou IN | Oferecer tratamento como expressão de tabela/junção |
| `<NOTEX2AJ OPTION='ENABLE'/>` | Verificações repetidas de ausência por NOT EXISTS | Possibilitar anti-join |
| `<NOTIN2AJ OPTION='ENABLE'/>` | NOT IN elegível | Possibilitar anti-join preservando a semântica de NULL |

`OPTION='DISABLE'` serve para bloquear a transformação correspondente, por exemplo quando uma transformação introduz regressão. `SUBQ2JOIN`, `NOTEX2AJ` e `NOTIN2AJ` são controles da instrução; não se deve acrescentar `TABLE` para tentar escolher uma subconsulta específica. `INLIST2JOIN` admite alvo por tabela/coluna. Habilitar não elimina as condições de elegibilidade. [IBM: reescrita](https://www.ibm.com/docs/en/db2/11.5.x?topic=guidelines-query-rewrite-optimization), [IBM: regras e escopo](https://www.ibm.com/docs/en/db2/11.1?topic=guidelines-query-rewrite-optimization).

Exemplo completo:

```sql
SELECT P.IDPEDIDO FROM DBA.PEDIDOS P
WHERE NOT EXISTS
      (SELECT 1 FROM DBA.PAGAMENTOS B WHERE B.IDPEDIDO = P.IDPEDIDO)
/* <OPTGUIDELINES><NOTEX2AJ OPTION='ENABLE'/></OPTGUIDELINES> */;
```

Nunca substituir manualmente NOT IN por NOT EXISTS presumindo equivalência diante de NULL. O guideline solicita uma transformação válida; não autoriza mudar a regra de negócio.

## 5. Parâmetros gerais por instrução

### 5.1 REOPT

```xml
<OPTGUIDELINES><REOPT VALUE='ALWAYS'/></OPTGUIDELINES>
```

**Problema:** um plano genérico atende mal parâmetros com distribuições muito diferentes. **Ganho potencial:** escolher o plano considerando os valores da execução. `ALWAYS` reotimiza a cada execução elegível; `ONCE` usa os valores iniciais e reutiliza o plano. **Risco:** CPU e latência de compilação, ou primeiro valor pouco representativo em ONCE. O elemento XML documentado aceita ONCE e ALWAYS; não transportar automaticamente valores de opções BIND de outros produtos. [IBM: REOPT e execução](https://www.ibm.com/docs/en/db2/11.5.x?topic=bespdbc-performance-improvements-when-using-reopt-option-bind-command), [IBM: sintaxe XML](https://public.dhe.ibm.com/ps/products/db2/info/vr115/pdf/en_US/db2_perf_tune_115.pdf).

### 5.2 DEGREE

```xml
<OPTGUIDELINES><DEGREE VALUE='4'/></OPTGUIDELINES>
```

**Problema:** consulta volumosa pode aproveitar paralelismo, ou uma consulta pequena sofre com sua sobrecarga. **Ganho potencial:** reduzir tempo decorrido ou reduzir overhead usando `VALUE='1'`. O domínio documentado inclui 1 a 32767, ANY e -1. Depende da habilitação e dos limites efetivos do ambiente; quatro não garante quatro workers em toda operação. **Risco:** reduzir a latência individual e piorar a concorrência global. [IBM: DEGREE e parâmetros gerais](https://public.dhe.ibm.com/ps/products/db2/info/vr115/pdf/en_US/db2_perf_tune_115.pdf).

### 5.3 QRYOPT

```xml
<OPTGUIDELINES><QRYOPT VALUE='7'/></OPTGUIDELINES>
```

**Problema:** uma consulta complexa pode se beneficiar de outra classe de otimização. **Ganho potencial:** explorar alternativas diferentes. Valores documentados: 0, 1, 2, 3, 5, 7 e 9. **Risco:** mais tempo de compilação sem ganho na execução. Classe maior não significa índice correto nem melhoria garantida. Não usar 4, 6 ou 8 por extrapolação. [IBM: QRYOPT](https://www.ibm.com/docs/en/db2/11.5.x?topic=guidelines-qryopt-requests).

### 5.4 RTS

```xml
<OPTGUIDELINES><RTS OPTION='ENABLE' TIME='1000'/></OPTGUIDELINES>
```

**Problema:** coleta de estatísticas em tempo real aumenta a latência de compilação. **Ganho potencial:** limitar o tempo dessa coleta ou desabilitá-la para a instrução com `OPTION='DISABLE'`. `TIME` é em milissegundos e não é timeout da execução. A habilitação depende das configurações de estatísticas automáticas do banco. **Risco:** limitar informações úteis para o otimizador. [IBM: RTS](https://www.ibm.com/docs/en/db2/11.1?topic=guidelines-rts-requests).

### 5.5 REGISTRY / OPTION

```xml
<OPTGUIDELINES>
  <REGISTRY>
    <OPTION NAME='DB2_REDUCED_OPTIMIZATION' VALUE='NO'/>
  </REGISTRY>
</OPTGUIDELINES>
```

**Problema:** testar um comportamento do compilador sem alterar toda a instância. **Ganho potencial:** restringir a mudança à instrução ou perfil. **Risco:** valores não suportados são ignorados; nem toda variável db2set é elegível.

A documentação 11.5 lista: `DB2_ANTIJOIN`, `DB2_EXPLAIN_OPT`, `DB2_EXTENDED_OPTIMIZATION`, `DB2_INLIST_TO_NLJN`, `DB2_MINIMIZE_LISTPREFETCH`, `DB2_NEW_CORR_SQ_FF`, `DB2_OPT_MAX_TEMP_SIZE`, `DB2_OPTIMIZER_VERSION`, `DB2_REDUCED_OPTIMIZATION`, `DB2_RESOLVE_CALL_CONFLICT`, `DB2_SELECTIVITY`, `DB2_SELUDI_COMM_BUFFER` e `DB2_SORT_AFTER_TQ`. Valores e disponibilidade precisam ser conferidos individualmente; a lista mudou entre versões. [IBM: lista 11.5](https://www.ibm.com/docs/de/db2/11.5.x?topic=profiles-sql-compiler-registry-variables-in-optimization-profile).

`REGISTRY` é o contêiner; cada `OPTION` contém nome e valor. A aplicação local evita usar um ajuste de instância como primeira tentativa. Conferir no EXPLAIN as entradas ENVVAR e sua origem. [IBM: uso e precedência](https://www.ibm.com/docs/en/db2/11.1?topic=profiles-sql-compiler-registry-variables-in-optimization-profile).

## 6. XML: XISCAN, XANDOR e modalidades de ACCESS/IXAND

```xml
<OPTGUIDELINES>
  <XISCAN TABLE='D' INDEX='IX_XML_CLIENTE'/>
</OPTGUIDELINES>
```

Alternativa independente:

```xml
<OPTGUIDELINES><XANDOR TABLE='D'/></OPTGUIDELINES>
```

**Problema:** XMLEXISTS processa documentos demais. **Ganho potencial:** restringir por índices XML antes de avaliar documentos. **Risco:** índice incompatível com caminho ou tipo não atende ao pedido. XANDOR trabalha com índices XML, não é um substituto genérico de IXAND relacional. [IBM: exemplos XML](https://www.ibm.com/docs/en/db2/12.1?topic=expressions-examples-optimization-guidelines-xml-data).

Para combinar explicitamente índices XML:

```xml
<OPTGUIDELINES>
  <IXAND TABLE='D' TYPE='XMLINDEX'>
    <INDEX IXNAME='IX_XML_CLIENTE'/>
    <INDEX IXNAME='IX_XML_STATUS'/>
  </IXAND>
</OPTGUIDELINES>
```

Outras modalidades são `ACCESS TABLE='D' TYPE='XMLINDEX'` e `IXAND TABLE='D' TYPE='XMLINDEX' ALLINDEXES='TRUE'`. **Ganho potencial:** combinar condições; **risco:** usar todos os índices aplicáveis pode aumentar trabalho. `ALLINDEXES` não é opção genérica para índices relacionais. [IBM: combinações XML 11.5](https://www.ibm.com/docs/en/db2/11.5.x?topic=expressions-examples-optimization-guidelines-xml-data).

## 7. MQTs: MQTOPT, MQT e MQTENFORCE

MQTs armazenam resultados materializados. Os controles abaixo não criam nem atualizam a MQT.

| Controle | Exemplo XML | Uso, ganho potencial e risco |
|---|---|---|
| `MQTOPT` | `<MQTOPT OPTION='DISABLE'/>` | Excluir substituição por MQT ao investigar uma regressão; pode perder uma boa pré-agregação |
| `MQT` | `<MQT NAME='DBA.MQT_VENDAS_DIA'/>` | Limitar candidatas; a escolha entre candidatas continua baseada em custo |
| `MQTENFORCE` | `<MQTENFORCE NAME='DBA.MQT_VENDAS_DIA'/>` | Solicitar MQT semanticamente compatível independentemente da estimativa de custo |

`MQTOPT` e a lista `MQT` são opções globais do perfil, não pedidos de acesso para copiar indiscriminadamente ao comentário SQL. [IBM: MQT choices](https://www.ibm.com/docs/en/db2/11.5.x?topic=element-mqt-optimization-choices).

`MQTENFORCE` também possui `TYPE='NORMAL'`, `REPLICATED` ou `ALL`; utilizar NAME ou TYPE como alternativas. A imposição não elimina requisitos semânticos. **Ganho potencial:** substituir recomputação por resultado materializado. **Risco:** escolher MQT mais cara ou incompatível com expectativas de atualização; verificar elegibilidade e política de refresh. [IBM: MQT enforcement no COPS](https://www.ibm.com/docs/en/db2/11.5.x?topic=guidelines-current-optimization-profile-schema).

## 8. Particionamento: PARTOPT, PART e DPFXMLMOVEMENT

`PARTOPT` e `PART` tratam otimização de grupos de partição computacional em configurações federadas particionadas. Não são partition pruning de uma tabela particionada por data.

```xml
<OPTGUIDELINES><PARTOPT OPTION='DISABLE'/></OPTGUIDELINES>
```

Ou, em perfil global, como alternativa:

```xml
<OPTGUIDELINES><PART NAME='WORKPART'/></OPTGUIDELINES>
```

**Problema:** redistribuição dinâmica pode custar mais que o processamento alternativo. **Ganho potencial:** controlar essa consideração ou seu grupo de destino. **Risco:** pior distribuição do trabalho. `PART` requer grupo existente e não elimina a decisão por custo. [IBM: grupos computacionais](https://www.ibm.com/docs/en/db2/11.1?topic=element-computational-partition-group-optimization-choices).

```xml
<OPTGUIDELINES><DPFXMLMOVEMENT VALUE='REFERENCE'/></OPTGUIDELINES>
```

**Problema:** mover documentos XML grandes entre partições. **Ganho potencial:** mover referências; COMBINATION permite combinação de documentos e referências. **Risco:** acessos posteriores aos documentos ainda têm custo. Recurso específico de XML em ambiente particionado. [IBM: movimento de XML](https://www.ibm.com/docs/en/db2/12.1?topic=expressions-examples-optimization-guidelines-xml-data).

## 9. Perfis externos e identificação correta

Exemplo didático para associar uma diretriz a um SQL:

```xml
<?xml version='1.0' encoding='UTF-8'?>
<OPTPROFILE>
  <STMTPROFILE ID='CR_VENCIMENTO'>
    <STMTKEY SCHEMA='DBA'><![CDATA[
SELECT CR.IDTITULO FROM CONTAS_RECEBER CR
WHERE CR.IDEMPRESA = 1 AND CR.DTVENCIMENTO = DATE('2026-10-18')
    ]]></STMTKEY>
    <OPTGUIDELINES>
      <IXSCAN TABLE='CR' INDEX='CON_REC_IDEDTVFBX'/>
    </OPTGUIDELINES>
  </STMTPROFILE>
</OPTPROFILE>
```

O perfil externo permite administrar diretrizes fora do código da aplicação. Exige armazenamento/ativação apropriados e correspondência com a instrução. `STMTMATCH`, `STMTKEY`, `STMTPROFILE`, `OPTPROFILE`, `INDEX` e `OPTION` são elementos de estrutura ou auxiliares, não novos algoritmos de acesso. [IBM: perfis externos](https://www.ibm.com/docs/en/db2/11.5.0?topic=plans-optimization-profiles-guidelines).

`TABLE` usa o nome exposto da referência; `TABID` identifica a referência no SQL otimizado. Não copiar um Qn de outro EXPLAIN: reescritas e upgrades podem mudar identificadores. [IBM: referências nas diretrizes](https://www.ibm.com/docs/en/db2/11.1?topic=guidelines-forming-table-references-in-optimization).

## 10. Compatibilidade e limites do catálogo

Este catálogo descreve as famílias públicas do recorte 11.5 documentado, não todas as configurações de desempenho nem todas as combinações possíveis de atributos. Extensões de outros releases precisam de validação própria: por exemplo, documentação 12.1 apresenta pedidos de agrupamento `GRPBY`, que não devem ser transplantados para 11.5.9 sem comprovar suporte. [IBM: agrupamento em 12.1](https://www.ibm.com/docs/en/db2/12.1.x?topic=guidelines-plan-optimization).

Também há limitações para tabelas organizadas por coluna. Não transportar exemplos de índices de tabelas row-organized para BLU supondo compatibilidade. [IBM: guidelines e tabelas colunares](https://www.ibm.com/docs/en/db2/12.1.x?topic=guidelines-optimization-profiles-column-organized-tables).

`OPTIMIZE FOR`, registradores especiais, configurações do banco, opções BIND e APREUSE são controles relacionados, mas não tags XML intercambiáveis. APREUSE atende estabilidade de planos em SQL estático e possui suas próprias regras. [IBM: access plan reuse](https://www.ibm.com/docs/en/db2/11.5.x?topic=plans-access-plan-reuse).

## 11. Como comprovar o ganho

1. Medir a consulta original recuperando todo o resultado; separar primeira linha e total quando relevante.
2. Registrar parâmetros, isolamento, versão, estatísticas e plano.
3. Aplicar uma alteração por vez.
4. Gerar EXPLAIN e verificar índice, limites de busca, ordem e predicados.
5. Inspecionar SQL0437W, motivo 13, e mensagens EXP; um pedido não atendido pode ter sido ignorado.
6. Executar várias amostras, alternando original e variante quando operacionalmente adequado.
7. Comparar todas as colunas e multiplicidades, não somente COUNT(*).
8. Testar valores comuns, raros, intervalos curtos e longos; observar carga concorrente.
9. Documentar reversão e revalidar após mudanças relevantes.

Esse roteiro é uma proposta de validação operacional. Os diagnósticos oficiais explicam motivos específicos de rejeição, inclusive aliases inválidos, índices incompatíveis e pedidos conflitantes. [IBM: mensagens EXP](https://www.ibm.com/docs/en/db2/11.5.x?topic=messages-exp).

Ganho de tempo pode ser expresso por `tempo_original / tempo_novo`; redução percentual por `100 × (1 − tempo_novo / tempo_original)`. Timerons são custo estimado, não segundos. Tempo menor também não prova, isoladamente, redução de CPU ou de leituras: medir esses recursos separadamente.

## 12. Caso real: MEUPRATA

Medições da análise anterior nesta sessão, com recuperação integral:

| Variante | Linhas | Tempo |
|---|---:|---:|
| Sem administradora | 58 | 0,0797 s |
| Administradora 99, original | 30 | 201,6365 s |
| Administradora 99 com IXSCAN direcionado | 30 | 0,0697 s |
| Reescrita sem guideline, com `CR.IDBANDEIRA + 0` na junção | 30 | 0,3618 s |

A consulta filtrada escolhia `IE_FK_0000363 (IDEMPRESA, IDBANDEIRA, IDADMINISTRADORA)`, com vencimento aplicado depois do acesso pelo índice. A diretriz direcionou `CON_REC_IDEDTVFBX (IDEMPRESA, DTVENCIMENTO, FLAGBAIXADA)`, delimitando a data na busca. O resultado permaneceu idêntico, inclusive duplicidades.

O ganho observado da versão com diretriz foi de aproximadamente **2.893 vezes**, ou redução de **99,965%** do tempo. É uma medição deste cenário; não previsão para outras consultas. O teste posterior com filtro em `CR.IDADMINISTRADORA`, mantendo a junção original, continuou escolhendo o índice lento no EXPLAIN.

O `+ 0` alterou o caminho de junção de maneira indireta. Pode prejudicar outros parâmetros e ser simplificado de outra forma no futuro. A diretriz expressa a intenção diretamente; um índice composto e estatísticas adequadas são alternativas estruturais a homologar. Nenhuma dessas alternativas dispensa medição.

Evidências locais: [diagnóstico original](../output/prata_diagnostico/diagnostico.md), [medição original](../output/prata_diagnostico/com_filtro_execucao.json), [medição com diretriz](../output/prata_diagnostico/indice_direcionado_execucao.json), [equivalência](../output/prata_diagnostico/equivalencia.json), [reescrita sem diretriz](../output/prata_diagnostico/sem_diretriz_validacao.json).
