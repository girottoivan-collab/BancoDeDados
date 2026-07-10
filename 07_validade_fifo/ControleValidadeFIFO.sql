CREATE OR REPLACE PROCEDURE DBA.SP_PROCESSA_VALIDADE_FIFO (
    IN IN_IDPRODUTO     INTEGER,
    IN IN_IDSUBPRODUTO  INTEGER,
    IN IN_IDEMPRESA     INTEGER,
    IN IN_DTVALIDADE    DATE
)
LANGUAGE SQL
BEGIN

    DECLARE V_IDEMPRESA INTEGER;
    DECLARE V_IDPLANILHA INTEGER;
    DECLARE V_IDPRODUTO INTEGER;
    DECLARE V_IDSUBPRODUTO INTEGER;
    DECLARE V_QTDSALDO_VALIDADE DECIMAL(15,3);
    DECLARE V_DTVALIDADE DATE;
    DECLARE V_DTMOV_ORIGEM TIMESTAMP;

    DECLARE V_IDPLANILHA_VENDA INTEGER;
    DECLARE V_NUMSEQUENCIA INTEGER;
    DECLARE V_QTDVENDA_SALDO DECIMAL(15,3);

    DECLARE V_CONSUMIR DECIMAL(15,3);

    DECLARE FIM_VAL INTEGER DEFAULT 0;
    DECLARE FIM_VENDA INTEGER DEFAULT 0;

    ---------------------------------------------------------
    -- Cursor principal
    ---------------------------------------------------------

    DECLARE C_VAL CURSOR FOR
        SELECT
            NV.IDEMPRESA,
            NV.IDPLANILHA,
            NV.IDPRODUTO,
            NV.IDSUBPRODUTO,
            NV.QTDPRODUTO,
            NV.DTVALIDADE,
            N.DTMOVIMENTO
        FROM DBA.NOTAS_VALIDADE NV
        JOIN DBA.NOTAS N
          ON N.IDEMPRESA = NV.IDEMPRESA
         AND N.IDPLANILHA = NV.IDPLANILHA
        WHERE NV.STATUS = 'C'
          AND NV.IDEMPRESA = IN_IDEMPRESA
          AND NV.IDPRODUTO = IN_IDPRODUTO
          AND NV.IDSUBPRODUTO = IN_IDSUBPRODUTO
          AND NV.DTVALIDADE = IN_DTVALIDADE
        ORDER BY N.DTMOVIMENTO, NV.DTVALIDADE;

    DECLARE CONTINUE HANDLER FOR NOT FOUND
        SET FIM_VAL = 1;

    OPEN C_VAL;

    LOOP_VAL:
    LOOP

        FETCH C_VAL INTO
            V_IDEMPRESA,
            V_IDPLANILHA,
            V_IDPRODUTO,
            V_IDSUBPRODUTO,
            V_QTDSALDO_VALIDADE,
            V_DTVALIDADE,
            V_DTMOV_ORIGEM;

        IF FIM_VAL = 1 THEN
            LEAVE LOOP_VAL;
        END IF;

        ---------------------------------------------------------
        -- bloco interno
        ---------------------------------------------------------

        BEGIN

            DECLARE C_VENDA CURSOR FOR
                SELECT
                    EA.IDPLANILHA,
                    EA.NUMSEQUENCIA,
                    EA.QTDPRODUTO - COALESCE(SUM(NVC.QTDCONSUMIDA),0)
                FROM DBA.ESTOQUE_ANALITICO EA
                JOIN DBA.NOTAS N2
                  ON N2.IDEMPRESA = EA.IDEMPRESA
                 AND N2.IDPLANILHA = EA.IDPLANILHA
                LEFT JOIN DBA.NOTAS_VALIDADE_CONSUMO NVC
                  ON NVC.IDEMPRESA = EA.IDEMPRESA
                 AND NVC.IDPLANILHA_VENDA = EA.IDPLANILHA
                 AND NVC.NUMSEQUENCIA_VENDA = EA.NUMSEQUENCIA
                WHERE EA.IDEMPRESA = V_IDEMPRESA
                  AND EA.IDPRODUTO = V_IDPRODUTO
                  AND EA.IDSUBPRODUTO = V_IDSUBPRODUTO
                  AND EA.IDOPERACAO > 1000
                  AND EA.FLAGMOVSALDOPRO = 'T'
                  AND N2.DTMOVIMENTO >= V_DTMOV_ORIGEM
                GROUP BY
                    EA.IDPLANILHA,
                    EA.NUMSEQUENCIA,
                    EA.QTDPRODUTO,
                    N2.DTMOVIMENTO
                HAVING
                    EA.QTDPRODUTO - COALESCE(SUM(NVC.QTDCONSUMIDA),0) > 0
                ORDER BY
                    N2.DTMOVIMENTO,
                    EA.IDPLANILHA,
                    EA.NUMSEQUENCIA;

            DECLARE CONTINUE HANDLER FOR NOT FOUND
                SET FIM_VENDA = 1;

            SET FIM_VENDA = 0;

            OPEN C_VENDA;

            LOOP_VENDA:
            LOOP

                FETCH C_VENDA INTO
                    V_IDPLANILHA_VENDA,
                    V_NUMSEQUENCIA,
                    V_QTDVENDA_SALDO;

                IF FIM_VENDA = 1 THEN
                    LEAVE LOOP_VENDA;
                END IF;

                IF V_QTDSALDO_VALIDADE <= 0 THEN
                    LEAVE LOOP_VENDA;
                END IF;

                SET V_CONSUMIR =
                    CASE
                        WHEN V_QTDVENDA_SALDO <= V_QTDSALDO_VALIDADE THEN V_QTDVENDA_SALDO
                        ELSE V_QTDSALDO_VALIDADE
                    END;

                INSERT INTO DBA.NOTAS_VALIDADE_CONSUMO (
                    IDEMPRESA,
                    IDPLANILHA_ORIGEM,
                    DTVALIDADE,
                    IDPLANILHA_VENDA,
                    NUMSEQUENCIA_VENDA,
                    IDPRODUTO,
                    IDSUBPRODUTO,
                    QTDCONSUMIDA,
                    QTDSALDO,
                    DTMOVIMENTO
                )
                VALUES (
                    V_IDEMPRESA,
                    V_IDPLANILHA,
                    V_DTVALIDADE,
                    V_IDPLANILHA_VENDA,
                    V_NUMSEQUENCIA,
                    V_IDPRODUTO,
                    V_IDSUBPRODUTO,
                    V_CONSUMIR,
                    V_QTDVENDA_SALDO - V_CONSUMIR,
                    CURRENT TIMESTAMP
                );

                SET V_QTDSALDO_VALIDADE = V_QTDSALDO_VALIDADE - V_CONSUMIR;

            END LOOP;

            CLOSE C_VENDA;

        END;

        UPDATE DBA.NOTAS_VALIDADE
        SET
            QTDPRODUTO = V_QTDSALDO_VALIDADE,
            STATUS =
                CASE
                    WHEN V_QTDSALDO_VALIDADE = 0 THEN 'S'
                    ELSE 'C'
                END
        WHERE IDEMPRESA = V_IDEMPRESA
          AND IDPLANILHA = V_IDPLANILHA
          AND IDPRODUTO = V_IDPRODUTO
          AND IDSUBPRODUTO = V_IDSUBPRODUTO
          AND DTVALIDADE = V_DTVALIDADE;

    END LOOP;

    CLOSE C_VAL;

END
--
CREATE OR REPLACE PROCEDURE DBA.SP_PROCESSA_VALIDADE_FIFO ()
LANGUAGE SQL
BEGIN
    FOR LOOPQUERY AS LQUERY CURSOR WITH HOLD FOR
    SELECT DISTINCT
        NV.IDEMPRESA,
        NV.IDPRODUTO,
        NV.IDSUBPRODUTO,
        NV.DTVALIDADE
    FROM
        DBA.NOTAS_VALIDADE NV
    JOIN
        DBA.NOTAS N ON
            N.IDEMPRESA = NV.IDEMPRESA AND
            N.IDPLANILHA = NV.IDPLANILHA
    WHERE
        NV.STATUS = 'C'/* AND
        NV.IDEMPRESA <> 1*/
    ORDER BY
        NV.IDEMPRESA,
        NV.IDPRODUTO,
        NV.IDSUBPRODUTO,
        NV.DTVALIDADE
    DO
        CALL DBA.SP_PROCESSA_VALIDADE_FIFO(
            LOOPQUERY.IDPRODUTO,
            LOOPQUERY.IDSUBPRODUTO,
            LOOPQUERY.IDEMPRESA,
            LOOPQUERY.DTVALIDADE
        );

        COMMIT;
    END FOR;
END
