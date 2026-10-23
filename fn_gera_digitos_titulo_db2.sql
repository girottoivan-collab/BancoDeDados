-- DB2 LUW
-- Gera a sequência de códigos CHAR(2):
--   01 até 99
--   A0 (= 100) até Z9 (= 359)
--
-- Exemplo:
-- SELECT codigo, digito_equivalente
--   FROM TABLE(DBA.FN_GERA_DIGITOS_TITULO(1, 359));
--
-- A CTE RECURSIVE gera blocos de dez posições até chegar ao limite.
-- Parâmetros aceitos: valores de 1 até 359, com início menor ou igual ao fim.

CREATE OR REPLACE FUNCTION DBA.FN_GERA_DIGITOS_TITULO (
    P_INICIO INTEGER,
    P_FIM    INTEGER
)
RETURNS TABLE (
    CODIGO              CHAR(2),
    DIGITO_EQUIVALENTE  INTEGER
)
LANGUAGE SQL
READS SQL DATA
RETURN
    WITH RECURSIVE BLOCOS (INICIO_BLOCO) AS (
        VALUES P_INICIO

        UNION ALL

        SELECT INICIO_BLOCO + 10
          FROM BLOCOS
         WHERE INICIO_BLOCO + 10 <= P_FIM
    ),
    DESLOCAMENTOS (N) AS (
        VALUES (0), (1), (2), (3), (4), (5), (6), (7), (8), (9)
    ),
    SEQUENCIA (N) AS (
        SELECT B.INICIO_BLOCO + D.N
          FROM BLOCOS B
          CROSS JOIN DESLOCAMENTOS D
         WHERE B.INICIO_BLOCO + D.N <= P_FIM
    )
    SELECT CAST(
               CASE
                   WHEN N BETWEEN 1 AND 99 THEN
                       RIGHT('00' || VARCHAR(N), 2)
                   WHEN N BETWEEN 100 AND 359 THEN
                       CHR(ASCII('A') + INT((N - 100) / 10))
                       || RIGHT(DIGITS(MOD(N - 100, 10)), 1)
               END
               AS CHAR(2)
           ) AS CODIGO,
           N AS DIGITO_EQUIVALENTE
      FROM SEQUENCIA
     WHERE N BETWEEN 1 AND 359;
