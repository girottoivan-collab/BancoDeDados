-- Oracle
-- Gera a sequência de códigos CHAR(2):
--   01 até 99
--   A0 (= 100) até Z9 (= 359)
--
-- Exemplo:
-- SELECT column_value AS codigo
--   FROM TABLE(DBA.FN_GERA_DIGITOS_TITULO(1, 359));
--
-- A função é recursiva: para cada valor ela emite o código atual
-- e invoca a si própria para o próximo valor.

CREATE OR REPLACE FUNCTION DBA.FN_GERA_DIGITOS_TITULO (
    P_INICIO IN PLS_INTEGER DEFAULT 1,
    P_FIM    IN PLS_INTEGER DEFAULT 359
) RETURN SYS.ODCIVARCHAR2LIST PIPELINED
AUTHID DEFINER
IS
    V_CODIGO VARCHAR2(2);
    V_OFFSET PLS_INTEGER;
BEGIN
    IF P_INICIO < 1 OR P_FIM > 359 OR P_INICIO > P_FIM THEN
        RAISE_APPLICATION_ERROR(
            -20001,
            'Intervalo inválido. Informe valores entre 1 e 359, com início menor ou igual ao fim.'
        );
    END IF;

    IF P_INICIO <= 99 THEN
        V_CODIGO := TO_CHAR(P_INICIO, 'FM00');
    ELSE
        V_OFFSET := P_INICIO - 100;
        V_CODIGO := CHR(ASCII('A') + TRUNC(V_OFFSET / 10))
                    || TO_CHAR(MOD(V_OFFSET, 10));
    END IF;

    PIPE ROW (V_CODIGO);

    IF P_INICIO < P_FIM THEN
        FOR R IN (
            SELECT COLUMN_VALUE AS CODIGO
              FROM TABLE(DBA.FN_GERA_DIGITOS_TITULO(P_INICIO + 1, P_FIM))
        ) LOOP
            PIPE ROW (R.CODIGO);
        END LOOP;
    END IF;

    RETURN;
END FN_GERA_DIGITOS_TITULO;
/
-- OBSOLETO: este arquivo foi gerado antes da confirmação do SGBD.
-- Para DB2, utilize fn_gera_digitos_titulo_db2.sql.
