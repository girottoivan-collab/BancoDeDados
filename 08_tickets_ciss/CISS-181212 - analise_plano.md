# CISS-181212 - Analise do plano de acesso

Ambiente validado em 2026-08-18:

- Banco: `NOPONTO`
- Servidor: `10.250.0.14:50016`
- DB2: `DB2/LINUXX8664 11.5.9.0`
- Plano coletado com `SET CURRENT EXPLAIN MODE EXPLAIN`
- Registro do plano: `EXPLAIN_TIME = 2026-08-18-13.37.50.588654`, `SOURCE_NAME = SQLC2O27`, `STMTNO = 1`, `SECTNO = 201`

## Resumo do plano

O custo estimado total ficou baixo em custo I/O (`TOTAL_COST = 303,71`), mas com CPU estimada alta (`36.267.076`). O plano possui `UNION ALL`, `SORT`, `TBSCAN` sobre o resultado intermediario e `GRPBY` final.

Os principais acessos observados:

- `PISCOFINS_MOVIMENTO`: tabela com `495.260.071` linhas, acessada em ambos os ramos e tambem como `PM_ORIGEM` no ramo de devolucao.
- `NOTAS`: tabela com `60.897.008` linhas.
- `NOTA_FISCAL_CONSUMIDOR_ELETRONICA`: tabela com `50.846.068` linhas, acessada via PK.
- `NOTAS_DEVOLUCAO`: `442.710` linhas, acessada por indice de produto/subproduto.
- `NOTAS_ENTRADA_SAIDA`: estatisticas de tabela aparecem como `-1`, embora haja indices com `STATS_TIME`.

## Pontos de atencao

1. Estatisticas incompletas/stale:
   - `NOTAS_ENTRADA_SAIDA` esta com `CARD = -1`, `NPAGES = -1`, `FPAGES = -1`.
   - `NOTA_FISCAL_ELETRONICA` tambem aparece com estatisticas de tabela ausentes.
   - As principais estatisticas existentes sao de 2025-08-17, cerca de um ano antes do periodo consultado (`2026-07-01` a `2026-07-31`).

2. `PISCOFINS_MOVIMENTO` e o maior ponto de risco:
   - O plano usa indices existentes para localizar por `IDEMPRESA/IDPLANILHA/NUMSEQUENCIA`, mas os filtros `PERPIS = 0`, `PERCOFINS = 0` e `VALBASEPISCOFINS > 0` entram como predicados SARG/residuais apos o acesso.
   - Como a tabela tem quase 500 milhoes de linhas, qualquer lookup repetido sem boa seletividade adicional pode pesar.

3. `NOTAS_ENTRADA_SAIDA` e o melhor ponto de partida logico:
   - A consulta filtra `IDEMPRESA = 3` e `DTEMISSAO` em um mes.
   - O plano estima `78.633` linhas para streams envolvendo NES, mas a ausencia de estatistica de tabela enfraquece a confianca dessa estimativa.

4. O `GROUP BY` final provavelmente nao e o principal vilao:
   - O resultado estimado depois dos joins aparece muito pequeno nos streams finais.
   - O `SORT`/`GRPBY` existe, mas o maior risco esta antes: acesso repetido a `PISCOFINS_MOVIMENTO` e qualidade das estatisticas.

## Recomendacoes

### 1. Atualizar estatisticas antes de criar indice

Executar `RUNSTATS` nas tabelas principais, com indices, distribuicao e colunas envolvidas nos filtros/joins. Depois disso, gerar novo `EXPLAIN` e comparar.

Prioridade:

- `DBA.NOTAS_ENTRADA_SAIDA`
- `DBA.PISCOFINS_MOVIMENTO`
- `DBA.NOTAS`
- `DBA.NOTAS_DEVOLUCAO`
- `DBA.NOTA_FISCAL_ELETRONICA`
- `DBA.NOTA_FISCAL_CONSUMIDOR_ELETRONICA`

### 2. Avaliar indice composto em `NOTAS_ENTRADA_SAIDA`

Como a consulta sempre parte de empresa + emissao e depois junta por planilha/operacao, avaliar:

```sql
CREATE INDEX DBA.IDX_NES_EMP_DTEMIS_CAT_PLA_OPE
    ON DBA.NOTAS_ENTRADA_SAIDA
    (IDEMPRESA, DTEMISSAO, TIPOCATEGORIA, IDPLANILHA, IDOPERACAO);
```

Esse indice tende a ajudar principalmente quando o filtro mensal por `DTEMISSAO` e seletivo.

### 3. Avaliar indice composto em `PISCOFINS_MOVIMENTO`

Para reduzir leituras repetidas em uma tabela de 495M linhas, avaliar um indice orientado ao join por nota mais os filtros fiscais:

```sql
CREATE INDEX DBA.IDX_PM_EMP_PLA_PIS_COF_BASE_PROD
    ON DBA.PISCOFINS_MOVIMENTO
    (IDEMPRESA, IDPLANILHA, PERPIS, PERCOFINS, VALBASEPISCOFINS, IDPRODUTO, IDSUBPRODUTO, NUMSEQUENCIA);
```

Observacao: esse indice deve ser validado em ambiente controlado antes de producao, pois `PISCOFINS_MOVIMENTO` e grande e provavelmente sofre escrita pesada. O custo de manutencao pode ser relevante.

### 4. Avaliar reescrita para reduzir duplicacao entre ramos

Os dois ramos repetem muitos joins. Uma alternativa e materializar logicamente as notas do periodo em CTE e reaproveitar nos dois ramos, deixando o otimizador com um conjunto menor antes de entrar em `PISCOFINS_MOVIMENTO`.

Essa reescrita deve ser validada por comparacao de resultado, porque o ramo de devolucao usa `NES_ORIGEM.IDOPERACAO`, enquanto o ramo normal usa `NES.IDOPERACAO`.

## Conclusao

Minha recomendacao pratica e:

1. Rodar `RUNSTATS` primeiro, porque ha estatisticas ausentes/desatualizadas em tabelas decisivas.
2. Recoletar o `EXPLAIN`.
3. Se a lentidao persistir, testar primeiro o indice de `NOTAS_ENTRADA_SAIDA`.
4. Se ainda houver custo alto em `PISCOFINS_MOVIMENTO`, testar o indice composto em `PISCOFINS_MOVIMENTO` com medicao de tempo e impacto de escrita.
