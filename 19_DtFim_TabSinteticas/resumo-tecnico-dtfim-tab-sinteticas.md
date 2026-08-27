# Materialização de DTFIM em Tabelas Sintéticas

## Resumo executivo

O script `script-stbd-51 (2).sql` propõe adicionar uma coluna de fim de vigência (`DTFIM`) em quatro tabelas de natureza sintética/histórica: `DBA.ESTOQUE_SINTETICO`, `DBA.CONTABIL_SALDO`, `DBA.PRODUTO_CUSTO` e `DBA.MOVIMENTO_CUSTO`. A solução transforma um relacionamento temporal atualmente inferido por busca do próximo `DTMOVIMENTO` em um atributo persistido, mantido por procedures e triggers.

Arquiteturalmente, a proposta é coerente para cenários em que consultas de saldo, custo e posição histórica precisam localizar faixas de validade com menor custo. Em vez de calcular repetidamente o próximo movimento por subconsulta ou função analítica, cada registro passa a carregar explicitamente o limite superior de sua vigência. Isso tende a beneficiar filtros do tipo `data_referencia >= dtmovimento and data_referencia < dtfim`, especialmente em tabelas volumosas.

A validação no ambiente DB2 `NOPONTO` em `10.250.0.14:50016` confirmou que as tabelas existem, que a coluna `DTFIM` ainda não está criada, que os índices/triggers propostos ainda não existem e que não há duplicidades nas chaves candidatas dos índices únicos de `ESTOQUE_SINTETICO` e `CONTABIL_SALDO`. Porém, o script ainda não deve ser promovido sem ajustes: há risco operacional alto pela volumetria, chamadas de procedures com parâmetro `OUT` sem argumento, uso de `DROP` sem tolerância a inexistência e um erro lógico na procedure incremental de `CONTABIL_SALDO`.

## Proposição técnica

A alteração adiciona `DTFIM` com dois tipos:

- `DATE` em `ESTOQUE_SINTETICO` e `CONTABIL_SALDO`, acompanhando o tipo de `DTMOVIMENTO` dessas tabelas.
- `TIMESTAMP` em `PRODUTO_CUSTO` e `MOVIMENTO_CUSTO`, também alinhado ao tipo de `DTMOVIMENTO`.

O valor de `DTFIM` é calculado como o menor `DTMOVIMENTO` posterior dentro da mesma chave de negócio. Quando não existe registro posterior, o script usa uma data sentinela retornada por `DBA.UF_MAX_DTFIM()`, definida como `2199-01-01 00.00.00.000000`.

Após o preenchimento inicial, o script cria índices orientados a consultas por vigência e instala triggers `AFTER INSERT`, `AFTER DELETE` e `AFTER UPDATE OF DTMOVIMENTO` para manter a cadeia temporal consistente em novas movimentações.

## Exemplo prático em `ESTOQUE_SINTETICO`

Na prática, o `DTFIM` transforma cada linha da tabela em uma faixa de vigência. Hoje, uma linha da `ESTOQUE_SINTETICO` informa o saldo a partir de um determinado `DTMOVIMENTO`, mas não informa diretamente até quando aquele saldo permaneceu válido.

Exemplo simplificado sem `DTFIM`:

```sql
IDEMPRESA | IDPRODUTO | IDSUBPRODUTO | IDLOCALESTOQUE | DTMOVIMENTO | QTDSALDO
1         | 100       | 100          | 1              | 2026-01-10  | 50
```

Essa linha indica que, em `2026-01-10`, o produto/local passou a ter saldo 50. Entretanto, para descobrir se esse saldo ainda valia em `2026-01-12`, a consulta precisa procurar o próximo movimento ou o maior movimento menor ou igual à data desejada.

Com `DTFIM`, a mesma informação passa a ficar explícita:

```sql
IDEMPRESA | IDPRODUTO | IDSUBPRODUTO | IDLOCALESTOQUE | DTMOVIMENTO | DTFIM      | QTDSALDO
1         | 100       | 100          | 1              | 2026-01-10  | 2026-01-15 | 50
```

Nesse formato, a linha representa a regra: o saldo 50 passou a valer em `2026-01-10` e permaneceu válido até antes de `2026-01-15`. A próxima linha da sequência temporal começaria em `2026-01-15`; a última linha de cada chave recebe uma data sentinela, como `2199-01-01`, indicando que é o registro vigente mais recente.

Sem `DTFIM`, uma consulta para obter o saldo de um produto em uma data de referência tende a depender de uma subconsulta com `MAX(DTMOVIMENTO)`:

```sql
SELECT *
FROM DBA.ESTOQUE_SINTETICO ES
WHERE ES.IDEMPRESA = 1
  AND ES.IDPRODUTO = 100
  AND ES.IDSUBPRODUTO = 100
  AND ES.IDLOCALESTOQUE = 1
  AND ES.DTMOVIMENTO = (
      SELECT MAX(ES2.DTMOVIMENTO)
      FROM DBA.ESTOQUE_SINTETICO ES2
      WHERE ES2.IDEMPRESA = ES.IDEMPRESA
        AND ES2.IDPRODUTO = ES.IDPRODUTO
        AND ES2.IDSUBPRODUTO = ES.IDSUBPRODUTO
        AND ES2.IDLOCALESTOQUE = ES.IDLOCALESTOQUE
        AND ES2.DTMOVIMENTO <= DATE('2026-01-12')
  );
```

Com `DTFIM`, a consulta passa a trabalhar diretamente com o intervalo de vigência:

```sql
SELECT *
FROM DBA.ESTOQUE_SINTETICO ES
WHERE ES.IDEMPRESA = 1
  AND ES.IDPRODUTO = 100
  AND ES.IDSUBPRODUTO = 100
  AND ES.IDLOCALESTOQUE = 1
  AND DATE('2026-01-12') >= ES.DTMOVIMENTO
  AND DATE('2026-01-12') < ES.DTFIM;
```

Para uma rotina de fechamento de estoque, por exemplo, a consulta dos saldos válidos em `2026-01-31` ficaria mais direta:

```sql
SELECT
    ES.IDEMPRESA,
    ES.IDPRODUTO,
    ES.IDSUBPRODUTO,
    ES.IDLOCALESTOQUE,
    ES.QTDSALDO
FROM DBA.ESTOQUE_SINTETICO ES
WHERE ES.IDEMPRESA = 1
  AND DATE('2026-01-31') >= ES.DTMOVIMENTO
  AND DATE('2026-01-31') < ES.DTFIM;
```

O benefício não está em alterar o significado do estoque, mas em materializar uma informação que já existe implicitamente na sequência dos movimentos. Com isso, a regra temporal fica explícita, indexável e mais barata de consultar. O banco deixa de recalcular repetidamente qual é o próximo movimento ou o último movimento válido para cada chave, e passa a localizar a linha pela faixa `DTMOVIMENTO` a `DTFIM`.

Os principais ganhos práticos são:

- melhora em consultas de posição histórica de estoque;
- redução de subconsultas com `MAX(DTMOVIMENTO)`;
- simplificação de joins por vigência com outras tabelas temporais;
- melhora de legibilidade e manutenção das queries;
- possibilidade de uso de índices específicos por `DTFIM`, `DTMOVIMENTO` e chaves de produto/local;
- redução de cálculo repetitivo sobre tabelas volumosas.

## Validação realizada no banco

Ambiente validado:

- Banco: `NOPONTO`
- Servidor DB2: `DB2/LINUXX8664 11.5.9.0`
- Usuário de validação: `DBA`
- Escopo: consultas somente-leitura em catálogo e checagens de duplicidade

Resultado de catálogo:

- As quatro tabelas existem em `DBA`.
- `DTMOVIMENTO` é `DATE` em `ESTOQUE_SINTETICO` e `CONTABIL_SALDO`.
- `DTMOVIMENTO` é `TIMESTAMP(6)` em `MOVIMENTO_CUSTO` e `PRODUTO_CUSTO`.
- `DTFIM` ainda não existe nas quatro tabelas.
- Não existem índices `IE_ESTSIN_DTFIM`, `IE_CONSAL_DTFIM`, `IE_PROCUS_DTFIM` e `IE_MOVCUS_DTFIM`.
- Não existem as triggers `TR_DTFIM_*` propostas no script.

Cardinalidade estimada pelo catálogo:

| Tabela | Linhas estimadas | Estatística |
|---|---:|---|
| `ESTOQUE_SINTETICO` | 115.853.470 | 2025-08-17 01:39:25 |
| `MOVIMENTO_CUSTO` | 17.113.518 | 2025-08-17 02:06:15 |
| `PRODUTO_CUSTO` | 16.709.573 | 2025-08-17 01:05:14 |
| `CONTABIL_SALDO` | 1.834.317 | 2025-08-17 01:03:22 |

Checagem de viabilidade dos índices únicos:

- `ESTOQUE_SINTETICO`: zero grupos duplicados para `IDEMPRESA`, `IDPRODUTO`, `IDSUBPRODUTO`, `IDLOCALESTOQUE`, `DTMOVIMENTO`.
- `CONTABIL_SALDO`: zero grupos duplicados para `IDEMPRESA`, `IDCTACONTABIL`, `DTMOVIMENTO`.

Esse resultado indica que os índices únicos propostos são compatíveis com o estado atual dos dados, assumindo que o cálculo de `DTFIM` seja executado corretamente antes da criação dos índices.

## Impactos esperados

O principal ganho está na leitura. Consultas temporais deixam de depender de busca correlacionada pelo próximo movimento e passam a poder usar uma coluna materializada, reduzindo custo de CPU e simplificando predicados de vigência. A modelagem também melhora a semântica do dado: cada linha passa a representar explicitamente um intervalo válido entre `DTMOVIMENTO` e `DTFIM`.

O maior custo está na escrita e na implantação. A carga inicial precisa atualizar aproximadamente 151,5 milhões de linhas somando as quatro tabelas, além de criar quatro índices novos sobre tabelas grandes. Em especial, `ESTOQUE_SINTETICO` concentra a maior exposição, com mais de 115 milhões de linhas. Essa operação tende a consumir log transacional, CPU, I/O, espaço temporário e tempo de janela.

Depois da implantação, cada inserção, exclusão ou alteração de `DTMOVIMENTO` passa a acionar manutenção incremental por trigger. O desenho limita o recalculo ao registro anterior, ao registro alterado e ao posterior dentro da mesma chave de negócio, o que é adequado. Ainda assim, qualquer carga massiva nessas tabelas sofrerá overhead adicional e deve ser avaliada com plano de execução e monitoramento.

## Pontos críticos identificados

1. O script chama procedures de reprocessamento sem informar o parâmetro `OUT`.

As procedures são criadas com assinatura `OUT rows_updated BIGINT`, mas as chamadas aparecem como `CALL DBA.SP_REPROCESSA_DTFIM_ESTSIN()` e equivalentes. Em DB2, isso tende a falhar por incompatibilidade de assinatura. O padrão esperado é chamar com marcador ou variável de saída, por exemplo `CALL DBA.SP_REPROCESSA_DTFIM_ESTSIN(?)` no CLP, ou adaptar as procedures para não expor parâmetro `OUT` se o retorno não for necessário.

2. Há erro lógico em `DBA.SP_PROCESSA_DTFIM_CONSAL`.

Na procedure incremental de `CONTABIL_SALDO`, o bloco que deveria localizar o próximo movimento usa `e2.dtmovimento < p_dtmovimento`. Pela própria regra comentada e pelo padrão das demais procedures, o correto deveria ser `e2.dtmovimento > p_dtmovimento`. Do jeito atual, o range de atualização pode ficar invertido ou incompleto, deixando `DTFIM` inconsistente após inserts, deletes ou updates em `CONTABIL_SALDO`.

3. Os `DROP` iniciais não são tolerantes a objetos inexistentes.

O catálogo validado mostra que os índices e triggers propostos ainda não existem. Como o script usa `DROP TRIGGER` e `DROP INDEX` diretamente, a execução pode parar logo no início dependendo da ferramenta e da configuração de tratamento de erro. A intenção comentada é "elimina se existirem", mas a implementação não garante isso.

4. A implantação é pesada e deve ser tratada como mudança estrutural de grande porte.

A inclusão de coluna, atualização total, criação de índices e alteração para `NOT NULL` em tabelas dessa volumetria exige janela controlada. O reprocessamento usa cursor por chave de negócio e `UPDATE` por grupos, com commits a cada 10.000 linhas acumuladas. A abordagem é segura do ponto de vista transacional, mas pode ser longa e gerar pressão significativa em log e I/O.

5. As triggers de update observam apenas `DTMOVIMENTO`.

As triggers `AFTER UPDATE OF DTMOVIMENTO` não reagem a alteração de componentes da chave de negócio, como `IDEMPRESA`, `IDPRODUTO`, `IDSUBPRODUTO`, `IDLOCALESTOQUE` ou `IDCTACONTABIL`. Se essas colunas forem imutáveis por regra de negócio, o desenho é aceitável. Se puderem ser alteradas, a manutenção de `DTFIM` ficará incompleta.

## Recomendações antes da promoção

Corrigir a procedure `DBA.SP_PROCESSA_DTFIM_CONSAL`, trocando a busca de `ld_next` para movimentos posteriores.

Revisar as chamadas das procedures com parâmetro `OUT`, adotando `CALL ... (?)`, variável local, bloco anônimo ou removendo o parâmetro de saída caso ele não seja usado operacionalmente.

Tornar o script idempotente ou tolerante a inexistência de objetos. Para DB2, isso pode ser feito por blocos SQL PL com handlers para SQLSTATE de objeto inexistente, ou pela separação do script em etapas controladas pela ferramenta de deploy.

Executar piloto em ambiente de homologação com estatísticas e volumetria próximas da produção, medindo duração, crescimento de log, tablespace temporária, impacto de locks e tempo de criação dos índices.

Separar a mudança em fases: criação de coluna, backfill, validação de consistência, criação de índices, criação de triggers e alteração para `NOT NULL`. Essa segmentação facilita rollback operacional e diagnóstico.

Validar amostras de consistência após o backfill com consultas que comparem `DTFIM` materializado contra `MIN(DTMOVIMENTO)` posterior por chave.

## Conclusão

A proposta é arquiteturalmente válida e ataca um problema clássico de tabelas temporais: substituir cálculo repetitivo de próximo evento por vigência materializada. O desenho deve melhorar consultas analíticas e operacionais que dependem de posição histórica de estoque, saldos contábeis e custos.

O script, porém, precisa de ajustes antes de execução produtiva. Os achados mais relevantes são o erro lógico em `CONTABIL_SALDO`, as chamadas incompatíveis das procedures com `OUT`, a ausência de tratamento para `DROP` de objetos inexistentes e o alto impacto operacional do backfill sobre mais de 150 milhões de linhas. Com essas correções e uma execução faseada, a alteração tem boa sustentação técnica.
