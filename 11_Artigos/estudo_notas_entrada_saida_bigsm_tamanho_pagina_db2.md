# Estudo de tamanho de pagina DB2 na NOTAS_ENTRADA_SAIDA - BIGSM

## Objetivo

Este estudo avalia a tabela `DBA.NOTAS_ENTRADA_SAIDA` no banco `BIGSM`, host `10.250.4.45`, porta `50013`, sob a otica de arquitetura fisica DB2: tamanho de pagina, limite de linha, risco de row overflow e impacto da inclusao de uma nova coluna.

O objetivo e comparar o risco de evolucao estrutural da tabela em outro ambiente, usando o mesmo criterio aplicado nos estudos anteriores.

## Resultado validado no banco

Validacao executada no banco `BIGSM`, Db2 LUW `11.5.9.0`, usuario `DBA`, usando a tabela `DBA.NOTAS_ENTRADA_SAIDA`.

| Metrica | Valor |
| --- | ---: |
| Host / porta | `10.250.4.45:50013` |
| Database | `BIGSM` |
| Tablespace | `USERSPACE1` |
| Page size | 32.768 bytes |
| Limite de linha para 32K | 32.677 bytes |
| Quantidade de colunas | 126 |
| Cardinalidade estatistica (`CARD`) | 7.128.505 |
| Paginas alocadas (`FPAGES`) | 20.360 |
| Paginas com dados (`NPAGES`) | 20.308 |
| Overflow estatistico | 52.240 |
| Data da estatistica (`STATS_TIME`) | 26/07/2026 01:27:27 |
| Compressao | `R` |
| Modo de compressao de linha | `A` |
| Linha base estimada | 3.519 bytes |
| Uso atual do limite da pagina | 10,76% |
| Folga tecnica atual | 29.158 bytes |
| Simulacao: nova coluna `VARCHAR(500)` anulavel | 505 bytes |
| Linha estimada apos inclusao | 4.024 bytes |
| Folga apos inclusao | 28.653 bytes |
| Uso apos inclusao | 12,31% |

## Conclusao executiva

No banco `BIGSM`, a `DBA.NOTAS_ENTRADA_SAIDA` esta em tablespace com pagina 32K. Isso muda completamente o risco em relacao ao ambiente em que a mesma tabela estava em pagina 4K.

Ao simular a inclusao de uma coluna `VARCHAR(500)` anulavel, a linha estimada passa de `3.519` para `4.024 bytes`, usando apenas `12,31%` do limite de linha de uma pagina 32K. Do ponto de vista de limite de tamanho de pagina, a inclusao nao representa risco.

O ponto de atencao neste ambiente nao e a falta de espaco na pagina. O ponto de atencao e o `OVERFLOW = 52.240`, mesmo com pagina 32K e compressao de linha ativa. Isso sugere que ja existe fragmentacao ou movimentacao fisica de linhas por historico de atualizacoes, crescimento de linhas, reorganizacao pendente ou comportamento de armazenamento associado a dados variaveis.

Minha recomendacao: a coluna `VARCHAR(500)` poderia ser aprovada sob a otica de limite de pagina, mas a tabela deveria passar por analise de `REORG/RUNSTATS` e investigacao do overflow antes ou junto da mudanca.

## Comparacao arquitetural com pagina 4K

Para a mesma definicao estrutural:

| Cenario | Page size | Linha apos `VARCHAR(500)` | Limite | Folga |
| --- | ---: | ---: | ---: | ---: |
| Ambiente com pagina 4K | 4.096 bytes | 4.024 bytes | 4.005 bytes | -19 bytes |
| `BIGSM` | 32.768 bytes | 4.024 bytes | 32.677 bytes | 28.653 bytes |

Esse comparativo mostra por que o tamanho da pagina precisa fazer parte da decisao. A mesma coluna que excede o limite de uma tabela em pagina 4K fica confortavel em uma tabela 32K.

## Colunas que mais pesam na linha base

As maiores contribuicoes estimadas sao:

| Coluna | Tipo | Bytes estimados |
| --- | --- | ---: |
| `OBSFISCAL` | `VARCHAR(2000)` | 2.005 |
| `IDENTIFICADORRENNER` | `VARCHAR(300)` | 305 |
| `OBSNOTA` | `CLOB(1M)` | 169 |
| `COMPLEMENTO` | `VARCHAR(80)` | 85 |
| `NOME` | `VARCHAR(80)` | 85 |
| `ENDERECO` | `VARCHAR(80)` | 85 |
| `BAIRRO` | `VARCHAR(40)` | 45 |
| `FONE1` | `VARCHAR(20)` | 25 |
| `INSCRESTADUAL` | `CHAR(20)` | 21 |
| `CNPJCPF` | `VARCHAR(14)` | 19 |

Assim como no outro ambiente, `OBSFISCAL VARCHAR(2000)` e a coluna que mais pesa na definicao da linha. Os `CLOB` entram como descritores na linha base, nao pelo tamanho maximo total do LOB.

## Leitura dos dados reais preenchidos

Foi feita uma leitura complementar das colunas variaveis mais relevantes:

| Metrica | Valor |
| --- | ---: |
| Linhas lidas | 7.171.098 |
| Linhas com `OBSFISCAL` preenchido | 233.400 |
| Tamanho medio observado em `OBSFISCAL` | 19,00 bytes |
| Tamanho maximo observado em `OBSFISCAL` | 619 bytes |
| Linhas com `IDENTIFICADORRENNER` preenchido | 85.635 |
| Tamanho medio observado em `IDENTIFICADORRENNER` | 0,00 byte |
| Tamanho maximo observado em `IDENTIFICADORRENNER` | 0 byte |
| Linhas com `OBSNOTA` preenchido | 296.712 |
| Tamanho medio observado em `OBSNOTA` | 73,00 bytes |
| Tamanho maximo observado em `OBSNOTA` | 2.325 bytes |

O uso real das colunas largas e bem menor do que o tamanho declarado. Ainda assim, como a tabela esta em pagina 32K, esse ponto nao pressiona o limite de pagina neste ambiente.

## Observacao sobre overflow

O catalogo indica:

```text
OVERFLOW = 52.240
NPAGES   = 20.308
FPAGES   = 20.360
```

Mesmo que o percentual de uso do limite de linha seja baixo, esse overflow merece investigacao. Possiveis causas:

- atualizacoes que aumentaram o tamanho fisico de linhas apos inseridas;
- paginas com pouco espaco livre para acomodar crescimento de `VARCHAR`;
- necessidade de `REORG`;
- efeito historico anterior a mudancas de compressao ou tablespace;
- estatisticas capturando linhas que foram movidas para areas de overflow.

Antes de uma alteracao estrutural relevante, recomendo:

```sql
RUNSTATS ON TABLE DBA.NOTAS_ENTRADA_SAIDA
    WITH DISTRIBUTION AND DETAILED INDEXES ALL;
```

E, caso a janela operacional permita, avaliar:

```sql
REORG TABLE DBA.NOTAS_ENTRADA_SAIDA;
RUNSTATS ON TABLE DBA.NOTAS_ENTRADA_SAIDA
    WITH DISTRIBUTION AND DETAILED INDEXES ALL;
```

A decisao de `REORG` deve considerar volume, janela de indisponibilidade, estrategia online/offline e impacto em logs.

## Consulta usada para o calculo

A consulta abaixo simula uma coluna `VARCHAR(500)` anulavel. Para testar outro caso, ajuste a CTE `nova_coluna`.

```sql
WITH nova_coluna(typename, length, scale, nulls) AS (
    VALUES ('VARCHAR', 500, 0, 'Y')
),
limite_pagina(pagesize, limite_linha) AS (
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
                c.length
        END AS bytes_base_estimados,
        CASE
            WHEN c.typename IN ('VARCHAR', 'CHARACTER VARYING', 'LONG VARCHAR', 'VARGRAPHIC')
                THEN 1
            ELSE 0
        END AS flag_variavel_larga
    FROM syscat.columns c
    WHERE c.tabschema = 'DBA'
      AND c.tabname = 'NOTAS_ENTRADA_SAIDA'
),
nova_coluna_calc AS (
    SELECT
        CASE
            WHEN typename IN ('VARCHAR', 'CHARACTER VARYING') THEN
                length + CASE WHEN nulls = 'Y' THEN 5 ELSE 4 END
            WHEN typename IN ('CHARACTER', 'CHAR') THEN
                length + CASE WHEN nulls = 'Y' THEN 1 ELSE 0 END
            WHEN typename IN ('INTEGER', 'INT') THEN
                CASE WHEN nulls = 'Y' THEN 5 ELSE 4 END
            WHEN typename = 'SMALLINT' THEN
                CASE WHEN nulls = 'Y' THEN 3 ELSE 2 END
            WHEN typename = 'BIGINT' THEN
                CASE WHEN nulls = 'Y' THEN 9 ELSE 8 END
            WHEN typename IN ('DECIMAL', 'NUMERIC') THEN
                INT(length / 2) + CASE WHEN nulls = 'Y' THEN 2 ELSE 1 END
            ELSE
                length
        END AS bytes_nova_coluna
    FROM nova_coluna
),
tabela AS (
    SELECT
        t.tabschema,
        t.tabname,
        t.tbspace,
        ts.pagesize,
        t.card,
        t.npages,
        t.fpages,
        t.overflow,
        t.stats_time,
        t.compression,
        t.rowcompmode,
        t.pctfree
    FROM syscat.tables t
    JOIN syscat.tablespaces ts
      ON ts.tbspace = t.tbspace
    WHERE t.tabschema = 'DBA'
      AND t.tabname = 'NOTAS_ENTRADA_SAIDA'
)
SELECT
    RTRIM(tabela.tabschema) AS tabschema,
    tabela.tabname,
    tabela.tbspace,
    tabela.pagesize,
    limite_pagina.limite_linha,
    COUNT(*) AS qtd_colunas,
    SUM(colunas.bytes_base_estimados) AS bytes_linha_base_estimado,
    MAX(nova_coluna_calc.bytes_nova_coluna) AS bytes_nova_coluna,
    SUM(colunas.bytes_base_estimados) + MAX(nova_coluna_calc.bytes_nova_coluna) AS bytes_pos_alter,
    limite_pagina.limite_linha
        - (SUM(colunas.bytes_base_estimados) + MAX(nova_coluna_calc.bytes_nova_coluna)) AS folga_pos_alter,
    DECIMAL(
        (SUM(colunas.bytes_base_estimados) + MAX(nova_coluna_calc.bytes_nova_coluna)) * 100.0
        / limite_pagina.limite_linha,
        9,
        2
    ) AS percentual_limite_usado,
    SUM(colunas.flag_variavel_larga) AS qtd_cols_variaveis,
    tabela.card,
    tabela.npages,
    tabela.fpages,
    tabela.overflow,
    tabela.stats_time,
    tabela.compression,
    tabela.rowcompmode,
    tabela.pctfree,
    CASE
        WHEN SUM(colunas.bytes_base_estimados) + MAX(nova_coluna_calc.bytes_nova_coluna) > limite_pagina.limite_linha
            THEN 'RISCO ALTO: excede limite da pagina'
        WHEN SUM(colunas.bytes_base_estimados) + MAX(nova_coluna_calc.bytes_nova_coluna) > limite_pagina.limite_linha * 0.85
            THEN 'RISCO MEDIO: acima da margem operacional de 85%'
        ELSE 'RISCO BAIXO: dentro da margem operacional'
    END AS avaliacao
FROM tabela
JOIN limite_pagina
  ON limite_pagina.pagesize = tabela.pagesize
CROSS JOIN nova_coluna_calc
JOIN colunas
  ON colunas.tabschema = tabela.tabschema
 AND colunas.tabname = tabela.tabname
GROUP BY
    tabela.tabschema,
    tabela.tabname,
    tabela.tbspace,
    tabela.pagesize,
    limite_pagina.limite_linha,
    tabela.card,
    tabela.npages,
    tabela.fpages,
    tabela.overflow,
    tabela.stats_time,
    tabela.compression,
    tabela.rowcompmode,
    tabela.pctfree;
```

## Recomendacao de arquitetura

Para o `BIGSM`, a recomendacao e:

1. Aprovar a inclusao de uma coluna `VARCHAR(500)` sob a perspectiva de limite de pagina, pois a tabela esta em 32K e a folga e ampla.
2. Nao ignorar o `OVERFLOW = 52.240`; ele nao bloqueia a coluna, mas indica oportunidade de manutencao fisica.
3. Avaliar `REORG` e novo `RUNSTATS` antes ou depois da alteracao, conforme janela operacional.
4. Continuar evitando crescimento indiscriminado da tabela, pois ela ja tem mais de 7 milhoes de linhas.
5. Para colunas pouco usadas, historicas ou de texto longo, ainda preferir tabela complementar, mesmo que o limite de pagina comporte a coluna.

Em resumo: no `BIGSM`, a nova coluna nao pressiona o limite da pagina. A preocupacao arquitetural principal passa a ser manutencao fisica e controle de crescimento em uma tabela volumosa.

## Referencias

- IBM Db2 12.1, `CREATE TABLE`: limites por tamanho de pagina e contagens de bytes por tipo de dado.
- IBM Db2 12.1, `Extended row size`: comportamento de linhas que excedem o tamanho maximo de registro e armazenamento fora da linha para `VARCHAR`/`VARGRAPHIC`.
