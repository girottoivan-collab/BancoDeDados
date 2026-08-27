CONNECT TO NOPONTO USER dba USING "a9d9p8.E10"
~

CREATE TABLE DBA.TMP_DTFIM_ESTSIN AS (
    SELECT
        IDempresa,
        IDproduto,
        IDsubproduto,
        IDlocalestoque,
        DTmovimento,
        COALESCE(
            LEAD(DTmovimento) OVER (
                PARTITION BY IDempresa, IDproduto, IDsubproduto, IDlocalestoque
                ORDER BY DTmovimento
            ),
            DATE(DBA.UF_MAX_DTFIM())
        ) AS DTFIM
    FROM DBA.ESTOQUE_SINTETICO
) WITH DATA
~
COMMIT
~

CREATE INDEX DBA.IX_TMP_DTFIM_ESTSIN ON DBA.TMP_DTFIM_ESTSIN (
    IDempresa,
    IDproduto,
    IDsubproduto,
    IDlocalestoque,
    DTmovimento
)
~
COMMIT
~

MERGE INTO DBA.ESTOQUE_SINTETICO T
USING DBA.TMP_DTFIM_ESTSIN S
ON (
    S.IDempresa = T.IDempresa
AND S.IDproduto = T.IDproduto
AND S.IDsubproduto = T.IDsubproduto
AND S.IDlocalestoque = T.IDlocalestoque
AND S.DTmovimento = T.DTmovimento
)
WHEN MATCHED AND (T.DTFIM IS NULL OR T.DTFIM <> S.DTFIM)
THEN UPDATE SET DTFIM = S.DTFIM
~
COMMIT
~

DROP TABLE DBA.TMP_DTFIM_ESTSIN
~
COMMIT
~

CONNECT RESET
~
