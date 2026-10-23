# Processamento de cartões — DB2 11.5

## Implantação vigente - release 1.3.2

A versão 1.3.2 removeu a criação/alteração de objetos do executável, inclusive a linha de comando `--install`. A implantação é manual e concentrada em **`objetos_v1.3.2.sql`** no ZIP distribuído; no projeto, o arquivo fica em `sql/releases/objetos_v1.3.2.sql`.

O arquivo é um bloco SQL completo com terminador `@`: inclui as tabelas de importação, movimentos, histórico e checkpoint, o cadastro de terminais, índices, migrações e comentários, além da SP V7. A SP conserva valor bruto, status 0 a 4, checkpoint de exclusão mútua e commit a cada 100 registros avaliados. As versões anteriores continuam preservadas no projeto para histórico; não fazem parte da sequência de implantação atual.

Executar com a equipe de banco, em conexão dedicada, sem trabalho pendente e com os agendamentos de importação e da SP suspensos. Os schemas TMP/DBA e a tabela de retorno devem existir. O usuário precisa das permissões de DDL e das funções de monitoramento usadas pelo script. Configurar o cliente para executar o bloco completo com `@` como terminador.

Antes de alterar objetos, o script recusa implantação se identificar atividade da SP em outra sessão ou checkpoint reservado por sessão viva. O timeout de lock é zero durante a implantação: se houver disputa, o script falha em vez de aguardar. O valor anterior é restaurado ao concluir ou falhar. O bloco confirma a implantação ao final e desfaz alterações em caso de erro.

O script pode ser repetido: preserva dados, cadastro e checkpoint, cria objetos ausentes e aplica as migrações incorporadas. Não chama a SP, não recupera valor bruto de arquivos e não reabre registros. Em ambiente já atualizado para V7, remover o botão exige apenas atualizar o aplicativo; a release SQL serve como referência/implantação em novos ambientes.

`13_consultar_checkpoint.sql` permanece disponível separadamente por ser somente leitura.

### Histórico técnico das versões anteriores

As menções abaixo ao botão **Criar tabelas** e à instalação pelo aplicativo descrevem os pacotes antigos. Elas não se aplicam à versão 1.3.2.


## Versão atual - V7 com checkpoint e commit de 100 (aplicativo 1.3.1)

Aplicar `11_migracao_checkpoint.sql` e depois `12_procedure_v7_checkpoint.sql`, em conexão dedicada e sem a versão anterior em execução. As migrações anteriores continuam necessárias em banco novo. O aplicativo 1.3.1 instala essa sequência no botão **Criar tabelas**; não chama a SP. A migração 11 é idempotente e não reinicializa uma reserva existente.

O bloqueio exclusivo da tabela de processados foi removido. O controle usa uma única linha em `TMP.CARTOES_PROCESSAMENTO_CONTROLE`, reservada por UPDATE condicional atômico e confirmada antes de processar. `CURRENT LOCK TIMEOUT = 0` vale apenas durante a tentativa de reserva; colisões de lock nessa etapa são tratadas como chamada ignorada. O valor anterior é restaurado. Com outra sessão ativa, a nova chamada sai sem esperar, com aviso SQLSTATE 01000, sem sobrescrever seu checkpoint.

A reserva guarda token exclusivo, application handle e application ID. Ela sobrevive aos commits e não mantém um lock físico aberto durante todo o processamento. A cada **100 linhas avaliadas**, o checkpoint e o lote são confirmados juntos; o último lote parcial também é confirmado. `QTD_AVALIADOS` inclui linhas retidas na origem, e `ULTIMO_ID` é informativo. A próxima execução revisita pendentes antigos, sem usar o checkpoint como filtro de ID.

Conclusão e falha fatal tratada liberam somente o token da execução proprietária; falhas desfazem o lote atual, preservando os anteriores. Se houver desconexão abrupta, a próxima chamada pode assumir a reserva apenas quando `MON_GET_CONNECTION` confirmar que o handle e o application ID proprietários não existem mais. Sessão ainda conectada não é liberada por idade: uma execução longa deve continuar protegida. Em cancelamento excepcional sem limpeza e com conexão mantida aberta, o suporte deve confirmar o término e encerrar essa conexão antes da nova tentativa; não limpar a flag durante uma execução ativa.

Consulta de acompanhamento: `13_consultar_checkpoint.sql` usa WITH UR para não aguardar uma escrita curta no controle. É uma visão de acompanhamento e pode observar uma atualização ainda não confirmada. Consultas normais aos processados continuam sujeitas aos bloqueios transacionais usuais; não existe mais o LOCK TABLE exclusivo explícito.

A SP usa `SYSPROC.MON_GET_APPLICATION_HANDLE`, `MON_GET_APPLICATION_ID` e `MON_GET_CONNECTION`; o responsável pela implantação precisa ter permissão para essas funções. Referência: [monitoramento de conexões IBM](https://www.ibm.com/docs/en/db2/11.5.x?topic=functions-mon-get-connection-get-connection-metrics).

As regras de busca da V6 continuam: autorização, CNPJ e VALBRUTOESPERADO; NSU e estabelecimento comentados, cadastro de terminais e status 0 a 4 preservados. O tamanho de lote vigente é 100, substituindo as referências históricas a 1.000 abaixo.


## Versão anterior - V6 com valor bruto (aplicativo 1.3.0)

Em uma instalação existente, aplique `09_migracao_valor_bruto.sql`, recupere o valor bruto dos movimentos legados a partir das planilhas originais e instale `10_procedure_v6_valor_bruto.sql`. A migração é idempotente, adiciona VALOR_BRUTO DECIMAL(15,2) nas duas tabelas e preserva NULL quando a origem ainda não foi recuperada. Não preenche zero artificialmente. As migrações 01 e 04 continuam necessárias em uma instalação nova. O botão **Criar tabelas** provisiona essa sequência e instala V6; não chama a SP nem recupera valores legados.

A correspondência atual é `AUTORIZACAO = IDAUTORIZACAO`, `CNPJ = CNPJ` e `VALOR_BRUTO = VALBRUTOESPERADO`, com igualdade decimal exata. As comparações de CODESTABELECIMENTO e IDNSUHOST estão comentadas temporariamente, tanto na contagem quanto no UPDATE. A validação numérica do NSU também fica comentada; seus dados permanecem importados e arquivados. V1 a V5 permanecem nos arquivos anteriores.

Os demais comportamentos da V5 continuam: FOR WITH HOLD, lotes de 1.000 avaliados, status 0 a 4, literal exato 'Nao identificado', nulos/vazios e cadastro de terminais. Para terminal permitido, VALOR_BRUTO nulo gera status 0 / SQLSTATE 75004. Um valor bruto diferente impede a correspondência e segue a regra de espera de cinco dias.

O utilitário `br.com.cartoes.Cli --backfill-values <planilhas>` recupera somente valores nulos em entrada e histórico, identificados por SHA-256, aba, linha, identificadores e data. Não chama a SP, não altera status e não reabre registros. Preservar as planilhas originais; um arquivo editado terá outro hash.

As seções históricas abaixo descrevem as versões anteriores. Onde mencionarem quatro chaves e conversão do NSU, prevalecem os critérios da V6 descritos acima.


## Objetos e instalação

### Versão anterior — V5 com FOR WITH HOLD

Execute `04_migracao_status4.sql` antes de `07_procedure_v5_for_with_hold.sql`, em conexão dedicada. A migração cria `DBA.BIGSM_CADTERMINAL (IDEMPRESA INTEGER, CODTERMINAL VARCHAR(40))` se ausente e permite status 4 na tabela de processados. Pode ser repetida sem apagar registros existentes. As procedures V1 a V4 permanecem preservadas nos arquivos 02, 03, 05 e 06. O botão **Criar tabelas** do aplicativo 1.2.5 instala a V5; pacotes anteriores podem reinstalar versões antigas.

A V5 usa diretamente `FOR MOVIMENTO AS C_MOVIMENTO INSENSITIVE CURSOR WITH HOLD FOR SELECT ... DO ... END FOR`. Não há declaração separada nem OPEN, FETCH ou CLOSE manuais: o FOR gerencia a varredura. WITH HOLD mantém a posição após os commits; INSENSITIVE fixa o conjunto selecionado, mesmo quando os movimentos são removidos durante o processamento. O registro é acessado por MOVIMENTO.ID, MOVIMENTO.NSU etc., eliminando as variáveis e a seleção manual da próxima linha. Tecnicamente existe um cursor implícito, conforme a [documentação IBM do FOR](https://www.ibm.com/docs/en/db2/11.5.x?topic=statements-).

As etapas continuam sendo selecionar, validar/classificar, atualizar o retorno e arquivar/remover da origem. As saídas antecipadas do bloco de validação evitam o aninhamento de IFs. O savepoint e o tratamento de erro por linha garantem que uma atualização de CODTERMINAL seja desfeita quando o arquivamento falha.

A rotina valida primeiro se `NUMERO_MAQUINA` existe em `DBA.BIGSM_CADTERMINAL.CODTERMINAL`, por comparação textual direta, preservando zeros. Sem correspondência no cadastro, arquiva com **status 4 — Processado terminal diferente**, sem consultar ou atualizar `DBA.CLW_RETORNO_CONTAS_RECEBER`, independentemente da idade da venda. Somente terminais cadastrados seguem para as regras 0/1/2/3. O cadastro é uma lista de códigos permitidos: `IDEMPRESA` não participa da busca porque não há essa coluna nem um vínculo empresa-estabelecimento nos movimentos. Códigos duplicados no cadastro não multiplicam o processamento, pois a validação usa EXISTS.

O cadastro não é preenchido automaticamente. **Cadastre os códigos antes de chamar a SP**; com o cadastro vazio, todos os movimentos ficam fora da lista e recebem status 4. O usuário da SP precisa também de SELECT nesse cadastro. O relatório do aplicativo apresenta os pendentes de TMP.CARTOES_MOVIMENTO, os registros dos status 2, 3 e 4 e somente a contagem do status 1 da tabela de processados. O filtro por DTMOVIMENTO é aplicado a todos os grupos; o padrão são os últimos dez dias, incluindo hoje. O status 4 também pode ser consultado pelo SQL abaixo.

`01_migracao.sql`: adiciona `DTMOVIMENTO DATE` aos movimentos existentes e cria `TMP.CARTOES_MOVIMENTO_PROCESSADOS`, com os mesmos identificadores e origem, status, contadores, diagnóstico SQL e data do processamento. Executar uma única vez no banco anterior, com terminador `@`.

`02_procedure.sql`: versão inicial preservada, sem alterações.

`03_procedure_v2_sem_cursor.sql`: versão atual de `TMP.SP_PROCESSAR_CARTOES_MOVIMENTO`, indentada e com um único laço WHILE. Não declara, abre ou percorre cursores e não retorna um result set. Compara diretamente `CODTERMINAL = 'Nao identificado'`, sem UPPER, conversão de caixa ou alternativa com acento. Valores nulos e vazios continuam sendo preenchidos, conforme confirmado. A expressão `ON ROLLBACK RETAIN CURSORS` pertence à sintaxe do SAVEPOINT no DB2 e não cria um cursor.

O usuário precisa de permissão de leitura/atualização em `DBA.CLW_RETORNO_CONTAS_RECEBER` e leitura/gravação nas tabelas TMP. No aplicativo 1.2.1, **Criar tabelas** instala a V2; no 1.2.2 instala a V3 descrita acima. Atualize o aplicativo antes de usar esse botão para não reinstalar uma versão antiga. O schema TMP deve existir.

Os registros anteriores sem data podem ter `DTMOVIMENTO` recuperado da planilha original com `--backfill-dates arquivo.xlsx ...`, definindo temporariamente `CARTOES_DB_PASSWORD` no ambiente. A recuperação exige coincidência do SHA-256, aba, linha e dos cinco identificadores; não usa a data de importação como se fosse a da venda. A coluna permite nulo para compatibilidade com clientes antigos, mas novas importações exigem a data da venda e a procedure classifica data ausente como erro. Atualize todos os clientes antes de novas importações.

## Execução

Em uma conexão dedicada, sem outras alterações pendentes:

```sql
CALL TMP.SP_PROCESSAR_CARTOES_MOVIMENTO();
```

A procedure faz commit a cada 1000 linhas avaliadas e também no último lote parcial. O limite inclui registros que precisam permanecer pendentes. Ela percorre IDs até o maior ID existente no início: não reavalia os mesmos pendentes na chamada nem fica em laço infinito. Novas importações durante a chamada ficam para a próxima execução. A V2 não retorna resumo tabular, eliminando também o cursor que existia somente para esse retorno na versão inicial. Consulte os status pelas consultas abaixo ou pela aba Relatório.

A procedure não é chamada automaticamente pelo aplicativo. Execute a chamada manualmente ou por agendador do banco, conforme a rotina operacional desejada.

## Regras

Correspondência pelos quatro campos: `AUTORIZACAO = IDAUTORIZACAO`, `NSU = IDNSUHOST`, `ESTABELECIMENTO = CODESTABELECIMENTO`, `CNPJ = CNPJ`. Como IDNSUHOST é DECIMAL(18,0), NSU é validado e convertido apenas para a busca; o texto original permanece arquivado. As outras chaves são comparadas como texto, sem remover zeros ou pontuação adicional.

| Status | Regra |
|---|---|
| 1 — Processado | Correspondência encontrada e pelo menos um CODTERMINAL atualizado com NUMERO_MAQUINA. Atualiza o literal `Nao identificado` (respeitando maiúsculas/minúsculas), nulo ou vazio. |
| 2 — Processado e não alterado | Correspondência encontrada e terminais já preenchidos com outro valor. |
| 3 — Processado e não encontrado | Nenhuma correspondência e DTMOVIMENTO estritamente anterior a CURRENT DATE - 5 DAYS. |
| 0 — Com erro | Falha na linha; desfaz as alterações daquela linha e arquiva com SQLSTATE, SQLCODE e mensagem. |
| 4 — Processado terminal diferente | NUMERO_MAQUINA não consta em DBA.BIGSM_CADTERMINAL.CODTERMINAL; não altera o retorno. |

Sem correspondência e com até cinco dias de idade (inclusive exatamente cinco dias), ou com data futura, o registro permanece na origem para uma próxima chamada. Se houver várias correspondências, atualiza todos os terminais que precisam de preenchimento, preserva os já identificados e registra QTD_ENCONTRADOS/QTD_ALTERADOS; o status é 1 quando qualquer um tiver sido alterado. A data da venda serve ao prazo de espera e não foi acrescentada às quatro chaves de busca solicitadas.

Atualização, arquivamento e remoção da origem usam um savepoint por linha. Se a própria gravação do erro for impossível (por exemplo, indisponibilidade, deadlock que desfaça a transação ou falha de armazenamento), a chamada retorna erro e desfaz o lote atual; os lotes anteriores permanecem commitados. Isso evita remover um movimento sem conseguir arquivá-lo. Chamadas simultâneas são serializadas por lote com lock exclusivo na tabela de processados; as importações não dependem desse lock.

## Consultas

```sql
SELECT STATUS, COUNT(*) AS QUANTIDADE
FROM TMP.CARTOES_MOVIMENTO_PROCESSADOS GROUP BY STATUS ORDER BY STATUS;

SELECT ID, DTMOVIMENTO, SQLSTATE_ERRO, SQLCODE_ERRO, MENSAGEM_ERRO
FROM TMP.CARTOES_MOVIMENTO_PROCESSADOS WHERE STATUS = 0;

SELECT ID, DTMOVIMENTO, CNPJ, NUMERO_MAQUINA
FROM TMP.CARTOES_MOVIMENTO_PROCESSADOS WHERE STATUS = 4;

SELECT COUNT(*) AS PENDENTES, MIN(DTMOVIMENTO) AS MENOR_DATA
FROM TMP.CARTOES_MOVIMENTO;
```

Referências de transações e diagnóstico: [IBM SAVEPOINT](https://www.ibm.com/docs/en/db2-as-a-service?topic=statements-savepoint), [IBM GET DIAGNOSTICS](https://www.ibm.com/docs/en/ias?topic=statements-get-diagnostics). A rotina foi compilada e testada no DB2 LUW 11.5.9 do ambiente.

O comentário da coluna STATUS descreve os status 0 a 4 e pode ser reaplicado com o script 08_comentario_status.sql. Também está incluído no provisionamento pela migração 04.
