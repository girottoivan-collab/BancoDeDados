# Diretrizes de indentacao SQL

Use este padrao para formatar consultas SQL neste repositorio.

## Regras gerais

- Use palavras-chave SQL em maiusculas: `SELECT`, `FROM`, `JOIN`, `WHERE`, `CASE`, `WHEN`, `ELSE`, `END`, `GROUP BY`, `ORDER BY`.
- Use 4 espacos por nivel de indentacao.
- Quebre cada coluna do `SELECT` em uma linha propria, mantendo a virgula ao final da linha.
- Mantenha expressoes simples em uma linha quando couberem com boa leitura.
- Quebre expressoes longas, subconsultas, `CASE`, `CAST`, `COALESCE` e chamadas de funcao com muitos parametros em multiplas linhas.
- Coloque `FROM`, `WHERE`, `GROUP BY`, `ORDER BY`, `FETCH` e `FOR READ ONLY` em linhas proprias.
- Coloque cada `JOIN` em linha propria e alinhado ao `FROM` do mesmo bloco.
- Coloque a tabela/alias do `JOIN` na linha seguinte, um nivel abaixo, com o `ON` ao final dessa linha.
- Em `JOIN TABLE (...)` e `JOIN LATERAL (...)`, o `TABLE`/`LATERAL` pode ficar na mesma linha do `JOIN`, mantendo o bloco interno indentado um nivel abaixo.
- Em predicados compostos, mantenha `AND` ou `OR` ao final da linha quando a leitura seguir o padrao do arquivo base.
- Indente subconsultas e blocos `LATERAL` um nivel abaixo do ponto onde aparecem.
- Em `CASE`, use uma linha para cada `WHEN`, `THEN`, `ELSE` e `END` quando houver expressoes compostas.
- Preserve comentarios existentes e nao altere nomes de tabelas, colunas, aliases ou parametros.

## Exemplo

```sql
SELECT
    T.IDPRODUTO,
    T.IDSUBPRODUTO,
    CASE
        WHEN T.FLAGINATIVO = 'T' THEN
            'INATIVO'
        ELSE
            'ATIVO'
    END AS STATUS
FROM
    DBA.PRODUTO_GRADE T
LEFT JOIN
    DBA.PRODUTO P ON
        P.IDPRODUTO = T.IDPRODUTO AND
        P.FLAGINATIVO = 'F'
WHERE
    T.IDEMPRESA = :RA_IDEMPRESA AND
    T.IDSUBPRODUTO IN (:RA_IDSUBPRODUTO)
FOR READ ONLY
```
