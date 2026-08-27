CONNECT TO NOPONTO USER dba USING "a9d9p8.E10"
~

CREATE TABLE DBA.TMP_DTFIM_MOVCUS AS (
    SELECT
        IDempresa,
        IDproduto,
        IDsubproduto,
        DTmovimento,
        COALESCE(
            LEAD(DTmovimento) OVER (
                PARTITION BY IDempresa, IDproduto, IDsubproduto
                ORDER BY DTmovimento
            ),
            DBA.UF_MAX_DTFIM()
        ) AS DTFIM
    FROM (
        SELECT DISTINCT
            IDempresa,
            IDproduto,
            IDsubproduto,
            DTmovimento
        FROM DBA.MOVIMENTO_CUSTO
    ) D
) WITH DATA
~
COMMIT
~

CREATE INDEX DBA.IX_TMP_DTFIM_MOVCUS ON DBA.TMP_DTFIM_MOVCUS (
    IDempresa,
    IDproduto,
    IDsubproduto,
    DTmovimento
)
~
COMMIT
~

MERGE INTO DBA.MOVIMENTO_CUSTO T
USING DBA.TMP_DTFIM_MOVCUS S
ON (
    S.IDempresa = T.IDempresa
AND S.IDproduto = T.IDproduto
AND S.IDsubproduto = T.IDsubproduto
AND S.DTmovimento = T.DTmovimento
)
WHEN MATCHED AND (T.DTFIM IS NULL OR T.DTFIM <> S.DTFIM)
THEN UPDATE SET DTFIM = S.DTFIM
~
COMMIT
~

DROP TABLE DBA.TMP_DTFIM_MOVCUS
~
COMMIT
~

CONNECT RESET
~
