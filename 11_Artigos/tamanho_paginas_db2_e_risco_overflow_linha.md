# Tamanho de paginas no Db2 e risco de overflow de linha

## Visao geral

Em tabelas organizadas por linha no Db2 LUW, os dados sao armazenados em paginas de dados. O tamanho da pagina e definido pelo tablespace em que a tabela esta criada e pode ser 4 KB, 8 KB, 16 KB ou 32 KB.

Essa escolha parece apenas fisica, mas ela afeta diretamente:

- o tamanho maximo declarado de uma linha;
- a quantidade maxima de colunas;
- a quantidade de linhas que cabem por pagina;
- o consumo de bufferpool;
- o custo de leitura e escrita;
- o risco de row overflow quando a linha passa do limite da pagina.

Segundo a documentacao IBM para tabelas organizadas por linha, os limites principais sao:

| Tamanho da pagina | Limite de tamanho da linha | Limite de colunas |
| --- | ---: | ---: |
| 4 KB | 4.005 bytes | 500 |
| 8 KB | 8.101 bytes | 1.012 |
| 16 KB | 16.293 bytes | 1.012 |
| 32 KB | 32.677 bytes | 2.048 |

O ponto critico e simples: uma tabela criada em tablespace de 4 KB nao deveria receber uma modelagem cuja linha maxima declarada se aproxime demais de 4.005 bytes. Quando isso acontece, uma nova coluna aparentemente pequena pode ser suficiente para mudar o comportamento fisico da tabela.

## O que acontece ao adicionar uma coluna

Ao executar um `ALTER TABLE ... ADD COLUMN`, o Db2 precisa avaliar a nova definicao da linha. Em tabelas com muitas colunas e muitos dados ja gravados, o impacto nao deve ser avaliado apenas pela sintaxe do DDL, mas pelo novo tamanho potencial da linha.

Exemplo conceitual:

```sql
ALTER TABLE DBA.CLIENTE_FORNECEDOR
    ADD COLUMN OBSERVACAOINTEGRACAO VARCHAR(500);
```

Se a tabela estiver em uma pagina de 4 KB e a linha atual ja estiver proxima de 4.005 bytes, esse `VARCHAR(500)` pode fazer a definicao maxima da linha ultrapassar o limite fisico do tablespace.

Quando o parametro de banco `extended_row_sz` esta habilitado e a tabela atende aos requisitos, o Db2 pode permitir que a definicao exceda o limite da pagina. Porem, quando uma linha inserida ou atualizada ultrapassa o tamanho maximo do registro da pagina, parte dos dados de colunas `VARCHAR` ou `VARGRAPHIC` pode ser armazenada fora da linha base, como dado fora da pagina principal. A linha base fica com um descritor, e o valor real passa a exigir acesso adicional.

Na pratica, isso cria uma forma de fragmentacao da linha: a consulta encontra a linha principal em uma pagina, mas precisa buscar parte da informacao em outro local. Em tabelas grandes, acessadas muitas vezes por processos transacionais, esse comportamento pode ser caro.

## Impactos praticos

Os impactos mais comuns sao:

- Maior quantidade de I/O logico: uma leitura que antes resolvia a linha em uma pagina pode precisar acessar paginas adicionais.
- Pior aproveitamento de bufferpool: paginas maiores ou dados espalhados aumentam a pressao sobre memoria.
- Aumento de custo em updates: quando uma coluna variavel cresce, a linha pode deixar de caber no espaco original.
- Mais overflow e necessidade de REORG: linhas que sofreram expansao podem ficar fisicamente menos eficientes.
- Piora em consultas amplas: `SELECT *`, relatorios e integracoes que leem muitas colunas tendem a sentir mais.
- Maior sensibilidade a colunas variaveis: `VARCHAR` grande parece barato quando vazio, mas precisa ser considerado pelo tamanho maximo declarado para o risco de DDL.

Esse e um ponto importante de arquitetura: uma coluna nova nao e apenas uma coluna nova. Em uma tabela larga e historica, ela pode mudar o padrao de armazenamento da linha.

## Como calcular o risco antes do ALTER TABLE

O calculo deve responder a quatro perguntas:

1. Qual e o tamanho da pagina do tablespace da tabela?
2. Qual e o limite de linha para esse tamanho de pagina?
3. Qual e o tamanho maximo declarado da linha atual?
4. Qual sera o tamanho maximo declarado depois da nova coluna?

Regra de decisao:

```text
novo_tamanho_estimado <= limite_da_pagina
    risco baixo de overflow por limite de linha

novo_tamanho_estimado > limite_da_pagina
    risco alto: pode exigir pagina maior, remodelagem ou extended row size
```

Como margem operacional, recomendo nao trabalhar colado no limite. Para tabelas transacionais, uma margem de 10% a 15% e saudavel:

```text
limite_operacional = limite_da_pagina * 0,85
```

Se a linha estimada ficar acima desse limite operacional, a mudanca merece revisao arquitetural mesmo que ainda caiba tecnicamente.

## Validacao real na CLIENTE_FORNECEDOR

Validacao executada no banco `PRIVADO`, Db2 LUW `10.5.5`, usuario `DBA`, usando a tabela `DBA.CLIENTE_FORNECEDOR`.

Resultado do catalogo:

| Metrica | Valor |
| --- | ---: |
| Tablespace | `REG32K` |
| Page size | 32.768 bytes |
| Limite de linha para 32K | 32.677 bytes |
| Quantidade de colunas | 197 |
| Cardinalidade estatistica (`CARD`) | 685 |
| Paginas alocadas (`FPAGES`) | 19 |
| Paginas com dados (`NPAGES`) | 19 |
| Overflow estatistico | 0 |
| Linha base estimada | 7.926 bytes |
| Simulacao: nova coluna `VARCHAR(500)` anulavel | 505 bytes |
| Linha estimada apos inclusao | 8.431 bytes |
| Folga apos inclusao | 24.246 bytes |
| Uso do limite da pagina | 25,80% |

Conclusao para esse exemplo: a inclusao de uma coluna `VARCHAR(500)` anulavel na `DBA.CLIENTE_FORNECEDOR`, considerando o estado atual validado, nao deve causar fragmentacao por estouro do limite da pagina. A tabela esta em tablespace 32K, tem folga ampla e o catalogo indica `OVERFLOW = 0`.

As maiores contribuicoes estimadas da linha base sao:

| Coluna | Tipo | Bytes estimados |
| --- | --- | ---: |
| `REFCOMERCIAL` | `VARCHAR(2400)` | 2.405 |
| `EMAILFINANCEIRO` | `VARCHAR(2000)` | 2.005 |
| `REFBANCARIA` | `VARCHAR(600)` | 605 |
| `REFPESSOAL` | `VARCHAR(600)` | 605 |
| `EMAIL` | `VARCHAR(200)` | 205 |
| `DESCRCONTRATOSERVICO` | `CLOB(1M)` | 169 |
| `REFSEPROC` | `CLOB(1M)` | 169 |

Observe que os `CLOB(1M)` nao foram somados pelo tamanho total de 1 MB na linha base. Eles entram como descritores, conforme a regra de armazenamento Db2 para LOB sem `INLINE LENGTH`.

## Consulta base para avaliar a CLIENTE_FORNECEDOR

Ela estima o tamanho maximo declarado da linha atual, compara com o tamanho da pagina e permite simular uma nova coluna.

> Ajuste os valores da CTE `nova_coluna` conforme a coluna que se pretende adicionar.

```sql
WITH nova_coluna AS (
    SELECT
        'VARCHAR' AS typename,
        500       AS length,
        0         AS scale,
        'Y'       AS nulls
    FROM SYSIBM.SYSDUMMY1
),
limite_pagina AS (
    SELECT 4096 AS pagesize, 4005 AS limite_linha FROM SYSIBM.SYSDUMMY1
    UNION ALL SELECT 8192, 8101 FROM SYSIBM.SYSDUMMY1
    UNION ALL SELECT 16384, 16293 FROM SYSIBM.SYSDUMMY1
    UNION ALL SELECT 32768, 32677 FROM SYSIBM.SYSDUMMY1
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
            WHEN c.typename IN ('GRAPHIC') THEN
                (c.length * 2) + CASE WHEN c.nulls = 'Y' THEN 1 ELSE 0 END
            WHEN c.typename IN ('VARGRAPHIC') THEN
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
        END AS bytes_estimados
    FROM syscat.columns c
    WHERE c.tabschema = 'DBA'
      AND c.tabname = 'CLIENTE_FORNECEDOR'
),
nova_coluna_calc AS (
    SELECT
        CASE
            WHEN typename = 'SMALLINT' THEN CASE WHEN nulls = 'Y' THEN 3 ELSE 2 END
            WHEN typename IN ('INTEGER', 'INT') THEN CASE WHEN nulls = 'Y' THEN 5 ELSE 4 END
            WHEN typename = 'BIGINT' THEN CASE WHEN nulls = 'Y' THEN 9 ELSE 8 END
            WHEN typename = 'REAL' THEN CASE WHEN nulls = 'Y' THEN 5 ELSE 4 END
            WHEN typename IN ('DOUBLE', 'DOUBLE PRECISION') THEN CASE WHEN nulls = 'Y' THEN 9 ELSE 8 END
            WHEN typename IN ('DECIMAL', 'NUMERIC') THEN
                INT(length / 2) + CASE WHEN nulls = 'Y' THEN 2 ELSE 1 END
            WHEN typename = 'DATE' THEN CASE WHEN nulls = 'Y' THEN 5 ELSE 4 END
            WHEN typename = 'TIME' THEN CASE WHEN nulls = 'Y' THEN 4 ELSE 3 END
            WHEN typename = 'TIMESTAMP' THEN
                INT((scale + 1) / 2) + CASE WHEN nulls = 'Y' THEN 8 ELSE 7 END
            WHEN typename IN ('CHARACTER', 'CHAR') THEN
                length + CASE WHEN nulls = 'Y' THEN 1 ELSE 0 END
            WHEN typename IN ('VARCHAR', 'CHARACTER VARYING') THEN
                length + CASE WHEN nulls = 'Y' THEN 5 ELSE 4 END
            WHEN typename = 'LONG VARCHAR' THEN
                CASE WHEN nulls = 'Y' THEN 25 ELSE 24 END
            WHEN typename IN ('GRAPHIC') THEN
                (length * 2) + CASE WHEN nulls = 'Y' THEN 1 ELSE 0 END
            WHEN typename IN ('VARGRAPHIC') THEN
                (length * 2) + CASE WHEN nulls = 'Y' THEN 5 ELSE 4 END
            WHEN typename IN ('CLOB', 'BLOB', 'DBCLOB') THEN
                CASE
                    WHEN length <= 1024 THEN CASE WHEN nulls = 'Y' THEN 73 ELSE 72 END
                    WHEN length <= 8192 THEN CASE WHEN nulls = 'Y' THEN 97 ELSE 96 END
                    WHEN length <= 65536 THEN CASE WHEN nulls = 'Y' THEN 121 ELSE 120 END
                    WHEN length <= 524000 THEN CASE WHEN nulls = 'Y' THEN 145 ELSE 144 END
                    WHEN length <= 4190000 THEN CASE WHEN nulls = 'Y' THEN 169 ELSE 168 END
                    ELSE CASE WHEN nulls = 'Y' THEN 201 ELSE 200 END
                END
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
        t.overflow
    FROM syscat.tables t
    JOIN syscat.tablespaces ts
      ON ts.tbspace = t.tbspace
    WHERE t.tabschema = 'DBA'
      AND t.tabname = 'CLIENTE_FORNECEDOR'
)
SELECT
    tabela.tabschema,
    tabela.tabname,
    tabela.tbspace,
    tabela.pagesize,
    limite_pagina.limite_linha,
    COUNT(*) AS qtd_colunas_atuais,
    SUM(colunas.bytes_estimados) AS bytes_linha_atual_estimado,
    MAX(nova_coluna_calc.bytes_nova_coluna) AS bytes_nova_coluna,
    SUM(colunas.bytes_estimados) + MAX(nova_coluna_calc.bytes_nova_coluna) AS bytes_linha_pos_alter,
    limite_pagina.limite_linha
        - (SUM(colunas.bytes_estimados) + MAX(nova_coluna_calc.bytes_nova_coluna)) AS folga_pos_alter,
    DECIMAL(
        (SUM(colunas.bytes_estimados) + MAX(nova_coluna_calc.bytes_nova_coluna)) * 100.0
        / limite_pagina.limite_linha,
        9,
        2
    ) AS percentual_limite_usado,
    tabela.card,
    tabela.npages,
    tabela.fpages,
    tabela.overflow,
    CASE
        WHEN SUM(colunas.bytes_estimados) + MAX(nova_coluna_calc.bytes_nova_coluna) > limite_pagina.limite_linha
            THEN 'RISCO ALTO: excede limite da pagina'
        WHEN SUM(colunas.bytes_estimados) + MAX(nova_coluna_calc.bytes_nova_coluna) > limite_pagina.limite_linha * 0.85
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
    tabela.overflow;
```

## Consulta complementar: colunas que mais pesam

Antes de aprovar uma nova coluna, tambem vale olhar quais colunas ja consomem mais bytes declarados. Isso ajuda a decidir se a tabela ainda comporta evolucao ou se ja virou candidata a remodelagem.

```sql
SELECT
    c.colno,
    c.colname,
    c.typename,
    c.length,
    c.scale,
    c.nulls,
    CASE
        WHEN c.typename = 'SMALLINT' THEN CASE WHEN c.nulls = 'Y' THEN 3 ELSE 2 END
        WHEN c.typename IN ('INTEGER', 'INT') THEN CASE WHEN c.nulls = 'Y' THEN 5 ELSE 4 END
        WHEN c.typename = 'BIGINT' THEN CASE WHEN c.nulls = 'Y' THEN 9 ELSE 8 END
        WHEN c.typename IN ('CHARACTER', 'CHAR') THEN c.length + CASE WHEN c.nulls = 'Y' THEN 1 ELSE 0 END
        WHEN c.typename IN ('VARCHAR', 'CHARACTER VARYING') THEN c.length + CASE WHEN c.nulls = 'Y' THEN 5 ELSE 4 END
        WHEN c.typename = 'LONG VARCHAR' THEN CASE WHEN c.nulls = 'Y' THEN 25 ELSE 24 END
        WHEN c.typename IN ('DECIMAL', 'NUMERIC') THEN INT(c.length / 2) + CASE WHEN c.nulls = 'Y' THEN 2 ELSE 1 END
        WHEN c.typename = 'DATE' THEN CASE WHEN c.nulls = 'Y' THEN 5 ELSE 4 END
        WHEN c.typename = 'TIME' THEN CASE WHEN c.nulls = 'Y' THEN 4 ELSE 3 END
        WHEN c.typename = 'TIMESTAMP' THEN INT((c.scale + 1) / 2) + CASE WHEN c.nulls = 'Y' THEN 8 ELSE 7 END
        WHEN c.typename IN ('CLOB', 'BLOB', 'DBCLOB') THEN
            CASE
                WHEN c.length <= 1024 THEN CASE WHEN c.nulls = 'Y' THEN 73 ELSE 72 END
                WHEN c.length <= 8192 THEN CASE WHEN c.nulls = 'Y' THEN 97 ELSE 96 END
                WHEN c.length <= 65536 THEN CASE WHEN c.nulls = 'Y' THEN 121 ELSE 120 END
                WHEN c.length <= 524000 THEN CASE WHEN c.nulls = 'Y' THEN 145 ELSE 144 END
                WHEN c.length <= 4190000 THEN CASE WHEN c.nulls = 'Y' THEN 169 ELSE 168 END
                ELSE CASE WHEN c.nulls = 'Y' THEN 201 ELSE 200 END
            END
        ELSE c.length
    END AS bytes_estimados
FROM syscat.columns c
WHERE c.tabschema = 'DBA'
  AND c.tabname = 'CLIENTE_FORNECEDOR'
ORDER BY bytes_estimados DESC, c.colno;
```

## Como interpretar o resultado

| Resultado | Decisao recomendada |
| --- | --- |
| Ate 70% do limite da pagina | Normalmente aceitavel. Validar apenas volume, indices e uso funcional. |
| Entre 70% e 85% | Atencao. A tabela ainda cabe, mas a folga para evolucao esta diminuindo. |
| Entre 85% e 100% | Revisao arquitetural recomendada. Evitar novas colunas largas. |
| Acima de 100% | Alto risco de overflow/extended row. Considerar outro desenho. |

Tambem observe `OVERFLOW`, `NPAGES`, `FPAGES` e `CARD` em `SYSCAT.TABLES`. Se a tabela ja possui overflow relevante, adicionar mais uma coluna tende a piorar um problema ja existente.

## Alternativas arquiteturais

Quando a inclusao da coluna ficar em zona de risco, existem algumas opcoes:

- Criar a coluna em tabela satelite 1:1, usando a chave da tabela principal.
- Mover atributos raramente acessados para uma tabela complementar.
- Usar LOB quando a informacao for grande, esparsa e pouco filtrada.
- Migrar a tabela para tablespace com pagina maior, apos medir impacto no bufferpool.
- Rever `VARCHAR` superdimensionados que foram criados "por garantia".
- Avaliar `VALUE COMPRESSION` e compressao de linha, considerando que compressao ajuda armazenamento real, mas nao deve ser usada como unica justificativa para uma modelagem larga.
- Executar `REORG` apos mudancas que gerem linhas fora do padrao original, principalmente em tabelas com historico grande de updates.

## Exemplo de decisao

Suponha que a `CLIENTE_FORNECEDOR` esteja em pagina de 4 KB:

```text
Limite de linha:              4.005 bytes
Linha atual estimada:         3.720 bytes
Nova coluna VARCHAR(500):       505 bytes
Linha apos ALTER:             4.225 bytes
Folga:                         -220 bytes
```

Neste caso, eu nao aprovaria a coluna diretamente na tabela principal. As opcoes mais seguras seriam criar tabela complementar ou mover a tabela para tablespace de 8 KB, mas a segunda alternativa exige analise de bufferpool, volume, indices, janelas de manutencao e padrao de acesso.

Agora suponha:

```text
Limite de linha:              8.101 bytes
Linha atual estimada:         3.720 bytes
Nova coluna VARCHAR(500):       505 bytes
Linha apos ALTER:             4.225 bytes
Uso do limite:                52,15%
```

Neste caso, a decisao tende a ser segura do ponto de vista de limite de pagina, desde que a coluna seja funcionalmente coerente com a entidade e nao piore indices, consultas ou replicacoes.

## Recomendacao final

Para uma tabela como `DBA.CLIENTE_FORNECEDOR`, que tende a ser central, larga e muito referenciada, minha recomendacao como criterio de governanca e:

1. Toda inclusao de coluna deve passar por calculo de tamanho de linha.
2. Se a tabela estiver acima de 85% do limite da pagina, a inclusao deve exigir justificativa arquitetural.
3. Colunas grandes, opcionais ou de baixa frequencia de leitura devem ir para tabela complementar.
4. Se o banco permitir extended row size, isso deve ser tratado como recurso de compatibilidade, nao como autorizacao para continuar alargando tabela critica.
5. A decisao final deve combinar catalogo (`SYSCAT.COLUMNS`, `SYSCAT.TABLES`, `SYSCAT.TABLESPACES`) com estatisticas reais de acesso e volume.

Em resumo: o tamanho da pagina e uma fronteira fisica que precisa participar da modelagem. Quando uma tabela historica esta perto dessa fronteira, cada nova coluna pode transformar uma alteracao simples em custo permanente de I/O.

## Referencias

- IBM Db2 12.1, `CREATE TABLE`: limites por tamanho de pagina, contagens de bytes por tipo de dado e formula de limite de colunas.
- IBM Db2 12.1, `Extended row size`: comportamento de linhas que excedem o tamanho maximo de registro e armazenamento fora da linha para `VARCHAR`/`VARGRAPHIC`.
