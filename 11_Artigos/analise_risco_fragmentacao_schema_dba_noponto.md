# Analise de risco de fragmentacao de linha no schema DBA - NOPONTO

## Objetivo

Este estudo avalia as tabelas catalogadas no schema `DBA` do banco de testes `NOPONTO`, host `10.250.0.14`, porta `50016`, com foco no risco de fragmentacao de linha e possivel impacto em plano de acesso ao adicionar uma nova coluna.

A simulacao adotada foi a inclusao de:

```sql
ALTER TABLE DBA.<TABELA>
    ADD COLUMN NOVA_FLAG CHAR(1);
```

Para um `CHAR(1)` anulavel, o calculo considera `2 bytes`: `1` byte do dado mais `1` byte de controle de nulidade.

## Ambiente validado

| Metrica | Valor |
| --- | ---: |
| Database | `NOPONTO` |
| Host / porta | `10.250.0.14:50016` |
| Db2 | `11.5.9.0` |
| Schema avaliado | `DBA` |
| Tabelas avaliadas | 2.541 |
| Page size das tabelas avaliadas | 32.768 bytes |
| Limite de linha para 32K | 32.677 bytes |

Todas as tabelas `DBA` avaliadas estao em tablespaces de pagina 32K. Isso reduz bastante o risco de estouro imediato ao adicionar uma coluna pequena como `CHAR(1)`.

## Classificacao geral

| Classificacao | Quantidade |
| --- | ---: |
| Alto: excede limite apos `CHAR(1)` | 0 |
| Medio: acima de 85% do limite apos `CHAR(1)` | 7 |
| Atencao: nao esta acima de 85%, mas ja possui overflow estatistico | 115 |
| Baixo: abaixo de 85% e sem overflow estatistico | 2.419 |

Conclusao direta: nenhuma tabela do schema `DBA` estoura o limite de pagina 32K ao adicionar um `CHAR(1)` anulavel. Porem, 7 tabelas ja estao muito proximas do limite maximo da linha e 115 tabelas ja possuem overflow estatistico, o que merece atencao por manutencao fisica e possivel influencia em custo de acesso.

## Tabelas em zona de risco por largura de linha

Essas tabelas nao estouram com `CHAR(1)`, mas ficam acima de 85% do limite de uma pagina 32K. O risco principal nao e o `CHAR(1)` isolado; e a proximidade do teto estrutural, normalmente causada por colunas `VARCHAR(32000)`.

| Tabela | Page size | Colunas | Linha atual | Apos `CHAR(1)` | Folga apos | Uso apos | Card | Overflow |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `PRODUTO_INTEGRACAO_LETT` | 32K | 9 | 32.148 | 32.150 | 527 | 98,38% | 0 | 0 |
| `LOGS_EMALOTE` | 32K | 9 | 32.101 | 32.103 | 574 | 98,24% | 0 | 0 |
| `CONFIG_ECOMMERCE_LISTA` | 32K | 8 | 32.087 | 32.089 | 588 | 98,20% | 0 | 0 |
| `MODELO_CONTRATO_ACORDO` | 32K | 3 | 32.072 | 32.074 | 603 | 98,15% | 5 | 0 |
| `CONTRATO_TIPO` | 32K | 4 | 32.063 | 32.065 | 612 | 98,12% | 0 | 0 |
| `CONFIG_ECOMMERCE_PROPRIEDADES` | 32K | 11 | 32.043 | 32.045 | 632 | 98,06% | 9 | 0 |
| `PRODUTO_GRADE_ECOMMERCE` | 32K | 7 | 32.036 | 32.038 | 639 | 98,04% | 4.119 | 16 |

Minha leitura arquitetural: nessas 7 tabelas, `CHAR(1)` ainda cabe, mas qualquer evolucao alem disso deve ser tratada com cuidado. Uma coluna `VARCHAR(1000)`, por exemplo, ja poderia exceder o limite em varias delas.

## Colunas que explicam o risco

O principal padrao encontrado foi a existencia de colunas `VARCHAR(32000)`. Elas consomem quase todo o limite teorico de uma linha em pagina 32K.

| Tabela | Principal coluna de peso | Tipo | Bytes estimados |
| --- | --- | --- | ---: |
| `PRODUTO_INTEGRACAO_LETT` | `PROPRIEDADESJSON` | `VARCHAR(32000)` | 32.005 |
| `LOGS_EMALOTE` | `DSLOG` | `VARCHAR(32000)` | 32.005 |
| `CONFIG_ECOMMERCE_LISTA` | `DESCRICAO` | `VARCHAR(32000)` | 32.004 |
| `MODELO_CONTRATO_ACORDO` | `LAYOUTCONTRATO` | `VARCHAR(32000)` | 32.004 |
| `CONTRATO_TIPO` | `LAYOUTCONTRATO` | `VARCHAR(32000)` | 32.004 |
| `CONFIG_ECOMMERCE_PROPRIEDADES` | `DESCRICAO` | `VARCHAR(32000)` | 32.005 |
| `PRODUTO_GRADE_ECOMMERCE` | `DESCRICAO` | `VARCHAR(32000)` | 32.005 |

Essas tabelas parecem ter sido modeladas com colunas de texto muito grandes dentro da linha base. Para dados como JSON, log, layout de contrato ou descricao longa, a alternativa mais segura normalmente e `CLOB` ou tabela complementar, dependendo do padrao de leitura.

## Tabelas com maior overflow estatistico

Estas tabelas nao estao necessariamente em risco por limite de linha ao adicionar `CHAR(1)`, mas ja apresentam overflow estatistico. Isso pode afetar leituras, estimativas de custo e escolhas de plano, principalmente em tabelas grandes.

| Tabela | Card | NPAGES | FPAGES | Overflow |
| --- | ---: | ---: | ---: | ---: |
| `ESTOQUE_ANALITICO` | 509.631.102 | 1.256.199 | 1.256.265 | 2.122.264 |
| `SINC_SCANNTECH_VENDA_TEMP` | 37.929.141 | 26.528 | 26.604 | 988.502 |
| `PISCOFINS_MOVIMENTO` | 495.260.071 | 765.319 | 766.028 | 556.040 |
| `CONTAS_RECEBER` | 78.227.537 | 184.828 | 184.895 | 500.703 |
| `VENDA_IDENTIFICADA_CLUBE_BENEFICIO` | 9.982.092 | 11.069 | 11.131 | 468.378 |
| `ESTOQUE_SINTETICO` | 115.853.470 | 257.739 | 257.741 | 459.199 |
| `FECHAMENTO_CARTAO_AUTOMATICO` | 15.457.839 | 18.378 | 18.458 | 341.951 |
| `CONTABIL_MOVIMENTO` | 73.159.460 | 93.530 | 93.560 | 338.425 |
| `POLITICA_PRECO_PRODUTO` | 12.096.160 | 23.165 | 23.219 | 281.158 |
| `EXTRATO_BANCARIO` | 3.927.430 | 6.509 | 6.565 | 151.115 |
| `PRODUTO_EMPRESA` | 2.043.199 | 2.086 | 2.100 | 115.013 |
| `ANALISE_COMPRA_DADOS_SUGESTAO_ATUAL` | 2.968.976 | 2.456 | 2.458 | 108.028 |
| `CONTAS_PAGAR` | 1.693.046 | 4.663 | 4.666 | 79.629 |
| `ABASTECIMENTO_SUGESTAO` | 1.315.735 | 1.742 | 1.766 | 43.055 |
| `LOG_SOLICITACOES_LIBERACAO` | 9.881.990 | 18.588 | 18.590 | 42.937 |
| `NOTA_FISCAL_CONSUMIDOR_ELETRONICA` | 50.846.068 | 173.899 | 173.909 | 30.596 |
| `PEDIDO_COMPRA_PROD` | 5.608.176 | 10.247 | 10.249 | 25.056 |
| `PRODUTO_COMPRAS` | 265.589 | 233 | 238 | 19.452 |
| `PRODUTO_DESCONTO_QTDE` | 340.052 | 571 | 575 | 17.387 |
| `ETIQUETA_GONPRO` | 15.644.908 | 14.868 | 14.872 | 16.796 |

Nessas tabelas, uma coluna `CHAR(1)` nao muda significativamente o tamanho de linha. Mesmo assim, se a tabela ja tem overflow, qualquer `ALTER TABLE` deve ser acompanhado de uma avaliacao de manutencao fisica, principalmente se houver historico de updates que aumentam tamanho de colunas variaveis.

## Impacto potencial em plano de acesso

A inclusao de uma coluna pequena como `CHAR(1)` tende a ter baixo impacto direto em seletividade, cardinalidade e estatisticas de filtros, desde que a coluna nao seja usada em predicados ou indices.

O risco indireto aparece em tres situacoes:

- a tabela esta proxima do limite de linha e a nova coluna contribui para row overflow;
- a tabela ja possui overflow e a alteracao aumenta a necessidade de reorganizacao;
- a nova coluna passa a participar de filtros, joins ou indices sem estatisticas adequadas.

Quando ha overflow, o otimizador pode continuar escolhendo planos baseados em estatisticas aparentemente boas, mas o custo real da leitura aumenta por causa de acessos adicionais a paginas de overflow. Em tabelas grandes como `ESTOQUE_ANALITICO`, `PISCOFINS_MOVIMENTO`, `CONTAS_RECEBER` e `ESTOQUE_SINTETICO`, esse detalhe pode se transformar em custo perceptivel.

## Recomendacao

Para o banco `NOPONTO`, a inclusao de um `CHAR(1)` anulavel no schema `DBA` nao deve causar estouro direto de pagina em nenhuma tabela avaliada.

Eu adotaria a seguinte regra:

1. Tabelas acima de 85% do limite devem exigir revisao de arquitetura antes de qualquer nova coluna, mesmo pequena.
2. Tabelas com `VARCHAR(32000)` devem ser revistas; em muitos casos, `CLOB` ou tabela complementar e melhor desenho.
3. Tabelas com overflow alto devem entrar em plano de manutencao com `REORG` e `RUNSTATS`, conforme janela operacional.
4. Se a nova coluna for indexada ou usada em filtros frequentes, executar `RUNSTATS` apos a carga/atualizacao inicial da coluna.
5. Para tabelas muito volumosas, validar o plano antes e depois com `EXPLAIN`, especialmente em queries criticas.

## Consulta reutilizavel

A consulta abaixo classifica todas as tabelas do schema `DBA` simulando a inclusao de `CHAR(1)` anulavel.

```sql
WITH limite_pagina(pagesize, limite_linha) AS (
    VALUES
        (4096, 4005),
        (8192, 8101),
        (16384, 16293),
        (32768, 32677)
),
colunas AS (
    SELECT
        c.tabschema,
        c.tabname,
        c.colname,
        c.typename,
        c.length,
        c.scale,
        c.nulls,
        CASE
            WHEN c.typename = 'SMALLINT' THEN CASE WHEN c.nulls = 'Y' THEN 3 ELSE 2 END
            WHEN c.typename IN ('INTEGER', 'INT') THEN CASE WHEN c.nulls = 'Y' THEN 5 ELSE 4 END
            WHEN c.typename = 'BIGINT' THEN CASE WHEN c.nulls = 'Y' THEN 9 ELSE 8 END
            WHEN c.typename = 'REAL' THEN CASE WHEN c.nulls = 'Y' THEN 5 ELSE 4 END
            WHEN c.typename IN ('DOUBLE', 'DOUBLE PRECISION') THEN CASE WHEN c.nulls = 'Y' THEN 9 ELSE 8 END
            WHEN c.typename IN ('DECIMAL', 'NUMERIC') THEN
                INT(c.length / 2) + CASE WHEN c.nulls = 'Y' THEN 2 ELSE 1 END
            WHEN c.typename = 'DATE' THEN CASE WHEN c.nulls = 'Y' THEN 5 ELSE 4 END
            WHEN c.typename = 'TIME' THEN CASE WHEN c.nulls = 'Y' THEN 4 ELSE 3 END
            WHEN c.typename = 'TIMESTAMP' THEN
                INT((c.scale + 1) / 2) + CASE WHEN c.nulls = 'Y' THEN 8 ELSE 7 END
            WHEN c.typename IN ('CHARACTER', 'CHAR') THEN
                c.length + CASE WHEN c.nulls = 'Y' THEN 1 ELSE 0 END
            WHEN c.typename IN ('VARCHAR', 'CHARACTER VARYING') THEN
                c.length + CASE WHEN c.nulls = 'Y' THEN 5 ELSE 4 END
            WHEN c.typename = 'LONG VARCHAR' THEN
                CASE WHEN c.nulls = 'Y' THEN 25 ELSE 24 END
            WHEN c.typename = 'GRAPHIC' THEN
                (c.length * 2) + CASE WHEN c.nulls = 'Y' THEN 1 ELSE 0 END
            WHEN c.typename = 'VARGRAPHIC' THEN
                (c.length * 2) + CASE WHEN c.nulls = 'Y' THEN 5 ELSE 4 END
            WHEN c.typename IN ('CLOB', 'BLOB', 'DBCLOB') THEN
                CASE
                    WHEN c.length <= 1024 THEN CASE WHEN c.nulls = 'Y' THEN 73 ELSE 72 END
                    WHEN c.length <= 8192 THEN CASE WHEN c.nulls = 'Y' THEN 97 ELSE 96 END
                    WHEN c.length <= 65536 THEN CASE WHEN c.nulls = 'Y' THEN 121 ELSE 120 END
                    WHEN c.length <= 524000 THEN CASE WHEN c.nulls = 'Y' THEN 145 ELSE 144 END
                    WHEN c.length <= 4190000 THEN CASE WHEN c.nulls = 'Y' THEN 169 ELSE 168 END
                    ELSE CASE WHEN c.nulls = 'Y' THEN 201 ELSE 200 END
                END
            ELSE
                COALESCE(c.length, 0)
        END AS bytes_estimados
    FROM syscat.columns c
    WHERE c.tabschema = 'DBA'
),
base AS (
    SELECT
        RTRIM(t.tabschema) AS tabschema,
        t.tabname,
        t.tbspace,
        ts.pagesize,
        lp.limite_linha,
        COUNT(c.colname) AS qtd_colunas,
        SUM(c.bytes_estimados) AS bytes_linha_atual,
        SUM(c.bytes_estimados) + 2 AS bytes_pos_char1_nullable,
        lp.limite_linha - SUM(c.bytes_estimados) AS folga_atual,
        lp.limite_linha - (SUM(c.bytes_estimados) + 2) AS folga_pos_char1_nullable,
        DECIMAL(SUM(c.bytes_estimados) * 100.0 / lp.limite_linha, 9, 2) AS perc_atual,
        DECIMAL((SUM(c.bytes_estimados) + 2) * 100.0 / lp.limite_linha, 9, 2) AS perc_pos,
        COALESCE(t.card, 0) AS card,
        COALESCE(t.npages, 0) AS npages,
        COALESCE(t.fpages, 0) AS fpages,
        COALESCE(t.overflow, 0) AS overflow,
        t.stats_time,
        t.compression,
        t.rowcompmode
    FROM syscat.tables t
    JOIN syscat.tablespaces ts
      ON ts.tbspace = t.tbspace
    JOIN limite_pagina lp
      ON lp.pagesize = ts.pagesize
    JOIN colunas c
      ON c.tabschema = t.tabschema
     AND c.tabname = t.tabname
    WHERE t.tabschema = 'DBA'
      AND t.type = 'T'
    GROUP BY
        t.tabschema,
        t.tabname,
        t.tbspace,
        ts.pagesize,
        lp.limite_linha,
        t.card,
        t.npages,
        t.fpages,
        t.overflow,
        t.stats_time,
        t.compression,
        t.rowcompmode
)
SELECT
    base.*,
    CASE
        WHEN bytes_pos_char1_nullable > limite_linha
            THEN 'ALTO_EXCEDE_LIMITE'
        WHEN bytes_pos_char1_nullable > limite_linha * 0.85
            THEN 'MEDIO_ACIMA_85'
        WHEN overflow > 0
            THEN 'ATENCAO_OVERFLOW'
        ELSE 'BAIXO'
    END AS risco
FROM base
ORDER BY
    CASE
        WHEN bytes_pos_char1_nullable > limite_linha THEN 1
        WHEN bytes_pos_char1_nullable > limite_linha * 0.85 THEN 2
        WHEN overflow > 0 THEN 3
        ELSE 4
    END,
    folga_pos_char1_nullable ASC;
```

## Referencias

- IBM Db2, `CREATE TABLE`: limites de tamanho de linha por tamanho de pagina.
- IBM Db2, `RUNSTATS`, `REORG` e estatisticas de tabela em `SYSCAT.TABLES`.
