# Estudo de tamanho de pagina DB2 na NOTAS_ENTRADA_SAIDA

## Objetivo

Este estudo avalia a tabela `DBA.NOTAS_ENTRADA_SAIDA` no banco `PRIVADO` sob a otica de arquitetura fisica DB2: tamanho de pagina, limite de linha, risco de row overflow e impacto da inclusao de uma nova coluna.

A motivacao e simples: em tabelas transacionais, largas e com muito volume historico, uma nova coluna pode deixar de ser apenas uma alteracao logica e passar a afetar o armazenamento fisico da linha.

## Resultado validado no banco

Validacao executada no banco `PRIVADO`, Db2 LUW `10.5.5`, usuario `DBA`, usando a tabela `DBA.NOTAS_ENTRADA_SAIDA`.

| Metrica | Valor |
| --- | ---: |
| Tablespace | `USERSPACE1` |
| Page size | 4.096 bytes |
| Limite de linha para 4K | 4.005 bytes |
| Quantidade de colunas | 126 |
| Cardinalidade estatistica (`CARD`) | 139.160 |
| Paginas alocadas (`FPAGES`) | 27.889 |
| Paginas com dados (`NPAGES`) | 27.889 |
| Overflow estatistico | 0 |
| Data da estatistica (`STATS_TIME`) | 07/01/2019 14:51:40 |
| Compressao | `N` |
| Linha base estimada | 3.519 bytes |
| Uso atual do limite da pagina | 87,87% |
| Folga tecnica atual | 486 bytes |
| Simulacao: nova coluna `VARCHAR(500)` anulavel | 505 bytes |
| Linha estimada apos inclusao | 4.024 bytes |
| Folga apos inclusao | -19 bytes |
| Uso apos inclusao | 100,47% |

## Conclusao executiva

A tabela `DBA.NOTAS_ENTRADA_SAIDA` esta em tablespace de pagina 4K e ja opera em uma zona sensivel: a linha base estimada usa aproximadamente 87,87% do limite maximo permitido para a pagina.

Ao simular a inclusao de uma coluna `VARCHAR(500)` anulavel, a linha estimada passa de `3.519` para `4.024 bytes`, ultrapassando em `19 bytes` o limite de `4.005 bytes` para pagina 4K.

Minha recomendacao como arquiteto DB2 senior: nao aprovar a inclusao direta de uma coluna `VARCHAR(500)` nessa tabela sem redesenho. O caminho mais seguro e criar uma tabela complementar 1:1 ou migrar a tabela para tablespace com pagina maior, preferencialmente apos medir impacto no bufferpool e na janela de manutencao.

## Por que o risco e maior nesta tabela

Diferente da `CLIENTE_FORNECEDOR`, que esta em tablespace 32K, a `NOTAS_ENTRADA_SAIDA` esta em `USERSPACE1` com pagina 4K. Isso reduz drasticamente a margem para evolucao estrutural.

Os limites DB2 para tabelas organizadas por linha sao:

| Tamanho da pagina | Limite de tamanho da linha | Limite de colunas |
| --- | ---: | ---: |
| 4 KB | 4.005 bytes | 500 |
| 8 KB | 8.101 bytes | 1.012 |
| 16 KB | 16.293 bytes | 1.012 |
| 32 KB | 32.677 bytes | 2.048 |

Como a tabela ja esta em `3.519 bytes`, a folga ate o limite fisico e de apenas `486 bytes`. Uma coluna `VARCHAR` anulavel consome, para efeito de definicao de linha, `n + 5` bytes. Portanto:

```text
Folga atual:                      486 bytes
VARCHAR(500) anulavel:             505 bytes
Excedente apos inclusao:            19 bytes
```

Mesmo uma coluna menor deve ser analisada com cuidado. Tecnicamente, um `VARCHAR` anulavel ate aproximadamente `VARCHAR(481)` ainda caberia no limite bruto, mas isso deixaria a tabela colada no teto. Para uma tabela transacional com `139.160` linhas estatisticas, essa nao e uma margem saudavel.

## Colunas que mais pesam na linha base

As maiores contribuicoes estimadas sao:

| Coluna | Tipo | Bytes estimados |
| --- | --- | ---: |
| `OBSFISCAL` | `VARCHAR(2000)` | 2.005 |
| `IDENTIFICADORRENNER` | `VARCHAR(300)` | 305 |
| `OBSNOTA` | `CLOB(1M)` | 169 |
| `COMPLEMENTO` | `VARCHAR(80)` | 85 |
| `ENDERECO` | `VARCHAR(80)` | 85 |
| `NOME` | `VARCHAR(80)` | 85 |
| `BAIRRO` | `VARCHAR(40)` | 45 |
| `FONE1` | `VARCHAR(20)` | 25 |
| `INSCRESTADUAL` | `CHAR(20)` | 21 |
| `CNPJCPF` | `VARCHAR(14)` | 19 |

O principal fator de pressao e `OBSFISCAL VARCHAR(2000)`. Ainda que poucos registros usem esse tamanho na pratica, o tamanho declarado pesa na avaliacao estrutural da tabela.

## Leitura dos dados reais preenchidos

Foi feita uma leitura complementar das colunas variaveis mais relevantes:

| Metrica | Valor |
| --- | ---: |
| Linhas lidas | 139.160 |
| Linhas com `OBSFISCAL` preenchido | 3.728 |
| Tamanho maximo observado em `OBSFISCAL` | 1 byte |
| Linhas com `IDENTIFICADORRENNER` preenchido | 0 |
| Tamanho maximo observado em `IDENTIFICADORRENNER` | nulo |
| Linhas com `OBSNOTA` preenchido | 3.729 |
| Tamanho maximo observado em `OBSNOTA` | 131 bytes |

Essa leitura mostra uma diferenca comum entre modelagem declarada e uso real: a tabela possui colunas largas, mas os valores atuais parecem pouco preenchidos. Isso reduz o risco imediato de overflow por dado real, mas nao elimina o risco de DDL. O Db2 avalia a definicao da linha e a capacidade de armazenamento fisico; alem disso, dados futuros podem passar a preencher essas colunas.

## Ressalva sobre estatisticas

A estatistica da tabela esta antiga:

```text
STATS_TIME = 07/01/2019 14:51:40
```

Antes de qualquer decisao definitiva, recomendo atualizar estatisticas:

```sql
RUNSTATS ON TABLE DBA.NOTAS_ENTRADA_SAIDA
    WITH DISTRIBUTION AND DETAILED INDEXES ALL;
```

Depois disso, repetir a consulta de avaliacao. O calculo de largura estrutural tende a permanecer igual, mas `CARD`, `NPAGES`, `FPAGES` e `OVERFLOW` podem mudar.

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

Para `DBA.NOTAS_ENTRADA_SAIDA`, eu adotaria as seguintes regras:

1. Nao adicionar `VARCHAR(500)` diretamente na tabela atual em pagina 4K.
2. Para atributos novos opcionais, criar tabela complementar 1:1 por chave da nota.
3. Se a coluna for obrigatoria e muito acessada junto com a nota, avaliar migracao da tabela para tablespace 8K ou 16K.
4. Atualizar estatisticas antes da decisao final, pois o `STATS_TIME` esta antigo.
5. Revisar colunas largas ja existentes, principalmente `OBSFISCAL VARCHAR(2000)`, que hoje tem baixo uso real mas pesa muito na definicao estrutural.

Em resumo: esta tabela e um bom exemplo de risco real. Ela ainda nao apresenta overflow estatistico, mas esta perto demais do limite da pagina 4K. Uma inclusao de coluna larga pode empurrar a definicao da linha para fora da capacidade natural do tablespace atual.

## Referencias

- IBM Db2 12.1, `CREATE TABLE`: limites por tamanho de pagina e contagens de bytes por tipo de dado.
- IBM Db2 12.1, `Extended row size`: comportamento de linhas que excedem o tamanho maximo de registro e armazenamento fora da linha para `VARCHAR`/`VARGRAPHIC`.
