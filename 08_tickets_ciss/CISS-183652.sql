-- CISS-183652
-- Inclui, em lotes de ate 1.000 registros, as baixas correspondentes ao
-- desconto concedido no cabecalho de titulos de contas a pagar originados
-- por NFe que ainda nao possuem registro em CONTAS_PAGAR_BAIXAS.
--
-- A tabela do schema TMP e persistente de proposito: ela identifica com
-- precisao as baixas geradas por esta procedure e viabiliza o rollback.

CREATE TABLE TMP.CONTAS_PAGAR_BAIXAS_CISS183652 (
    IDEMPRESA                  INTEGER NOT NULL,
    IDCLIFOR                   INTEGER NOT NULL,
    DIGITOTITULO               VARCHAR(3) NOT NULL,
    SERIENOTA                  VARCHAR(3) NOT NULL,
    IDTITULO                   INTEGER NOT NULL,
    IDPLANILHA                 INTEGER NOT NULL,
    ORIGEMMOVIMENTO            VARCHAR(6) NOT NULL,
    IDEMPRESABAIXA             INTEGER,
    DTPAGAMENTO                DATE,
    VALPAGAMENTOTITULO         DECIMAL(14, 2) NOT NULL DEFAULT 0,
    VALDESCCONCEDIDOTITULO     DECIMAL(14, 2) NOT NULL DEFAULT 0,
    DTEXECUCAO                 TIMESTAMP NOT NULL,
    NUMLOTE                    INTEGER NOT NULL,
    FLAGREVERTIDA              CHAR(1) NOT NULL DEFAULT 'F',
    DTREVERSAO                 TIMESTAMP,
    DTALTERACAO                TIMESTAMP NOT NULL DEFAULT CURRENT TIMESTAMP
)
GO
ALTER TABLE TMP.CONTAS_PAGAR_BAIXAS_CISS183652
    ADD CONSTRAINT PK_CPB_CISS183652 PRIMARY KEY (
        IDEMPRESA,
        IDCLIFOR,
        DIGITOTITULO,
        SERIENOTA,
        IDTITULO,
        IDPLANILHA
    )
GO
ALTER TABLE TMP.CONTAS_PAGAR_BAIXAS_CISS183652
    ADD CONSTRAINT CKT_CPB_CISS183652_REVERTIDA
        CHECK (FLAGREVERTIDA IN ('T', 'F'))
GO
CREATE INDEX TMP.IE_CPB_CISS183652_EXECUCAO
    ON TMP.CONTAS_PAGAR_BAIXAS_CISS183652 (
        DTEXECUCAO,
        NUMLOTE
    )
GO
COMMENT ON TABLE TMP.CONTAS_PAGAR_BAIXAS_CISS183652 IS
    'Registra as baixas inseridas pela procedure da demanda CISS-183652 para permitir rollback seguro.'
GO

CREATE OR REPLACE PROCEDURE DBA.SP_CISS_183652_INSERE_BAIXAS()
LANGUAGE SQL
MODIFIES SQL DATA
BEGIN
    DECLARE V_QTD_INSERIDA INTEGER DEFAULT 1;
    DECLARE V_QTD_BAIXA INTEGER DEFAULT 0;
    DECLARE V_NUMLOTE INTEGER DEFAULT 0;
    DECLARE V_DTEXECUCAO TIMESTAMP;

    SET V_DTEXECUCAO = CURRENT TIMESTAMP;

    WHILE V_QTD_INSERIDA > 0 DO
        SET V_NUMLOTE = V_NUMLOTE + 1;

        INSERT INTO TMP.CONTAS_PAGAR_BAIXAS_CISS183652 (
            IDEMPRESA,
            IDCLIFOR,
            DIGITOTITULO,
            SERIENOTA,
            IDTITULO,
            IDPLANILHA,
            ORIGEMMOVIMENTO,
            IDEMPRESABAIXA,
            DTPAGAMENTO,
            VALPAGAMENTOTITULO,
            VALDESCCONCEDIDOTITULO,
            DTEXECUCAO,
            NUMLOTE
        )
        SELECT
            CP.IDEMPRESA,
            CP.IDCLIFOR,
            CP.DIGITOTITULO,
            CP.SERIENOTA,
            CP.IDTITULO,
            CP.IDPLANILHA,
            CP.ORIGEMMOVIMENTO,
            CP.IDEMPRESA,
            CP.DTMOVIMENTO,
            0,
            CP.SUMVALDESCCONCEDIDOTITULO,
            V_DTEXECUCAO,
            V_NUMLOTE
        FROM
            DBA.CONTAS_PAGAR AS CP
        WHERE
            CP.SUMVALDESCCONCEDIDOTITULO > 0 AND
            CP.ORIGEMMOVIMENTO = 'NFE' AND
            CP.FLAGBAIXADA = 'F' AND
            NOT EXISTS (
                SELECT
                    1
                FROM
                    DBA.CONTAS_PAGAR_BAIXAS AS BX
                WHERE
                    BX.IDEMPRESA = CP.IDEMPRESA AND
                    BX.IDCLIFOR = CP.IDCLIFOR AND
                    BX.IDTITULO = CP.IDTITULO AND
                    BX.DIGITOTITULO = CP.DIGITOTITULO AND
                    BX.SERIENOTA = CP.SERIENOTA
            ) AND
            NOT EXISTS (
                SELECT
                    1
                FROM
                    TMP.CONTAS_PAGAR_BAIXAS_CISS183652 AS TMPBX
                WHERE
                    TMPBX.IDEMPRESA = CP.IDEMPRESA AND
                    TMPBX.IDCLIFOR = CP.IDCLIFOR AND
                    TMPBX.IDTITULO = CP.IDTITULO AND
                    TMPBX.DIGITOTITULO = CP.DIGITOTITULO AND
                    TMPBX.SERIENOTA = CP.SERIENOTA AND
                    TMPBX.IDPLANILHA = CP.IDPLANILHA
            )
        ORDER BY
            CP.IDEMPRESA,
            CP.IDCLIFOR,
            CP.IDTITULO,
            CP.DIGITOTITULO,
            CP.SERIENOTA
        FETCH FIRST 1000 ROWS ONLY;

        GET DIAGNOSTICS V_QTD_INSERIDA = ROW_COUNT;

        IF V_QTD_INSERIDA > 0 THEN
            INSERT INTO DBA.CONTAS_PAGAR_BAIXAS (
                IDEMPRESA,
                IDCLIFOR,
                DIGITOTITULO,
                SERIENOTA,
                IDTITULO,
                IDPLANILHA,
                ORIGEMMOVIMENTO,
                IDEMPRESABAIXA,
                DTPAGAMENTO,
                VALPAGAMENTOTITULO,
                VALDESCCONCEDIDOTITULO
            )
            SELECT
                TMPBX.IDEMPRESA,
                TMPBX.IDCLIFOR,
                TMPBX.DIGITOTITULO,
                TMPBX.SERIENOTA,
                TMPBX.IDTITULO,
                TMPBX.IDPLANILHA,
                TMPBX.ORIGEMMOVIMENTO,
                TMPBX.IDEMPRESABAIXA,
                TMPBX.DTPAGAMENTO,
                TMPBX.VALPAGAMENTOTITULO,
                TMPBX.VALDESCCONCEDIDOTITULO
            FROM
                TMP.CONTAS_PAGAR_BAIXAS_CISS183652 AS TMPBX
            WHERE
                TMPBX.DTEXECUCAO = V_DTEXECUCAO AND
                TMPBX.NUMLOTE = V_NUMLOTE AND
                TMPBX.FLAGREVERTIDA = 'F';

            GET DIAGNOSTICS V_QTD_BAIXA = ROW_COUNT;

            IF V_QTD_BAIXA <> V_QTD_INSERIDA THEN
                SIGNAL SQLSTATE '75001'
                    SET MESSAGE_TEXT = 'CISS-183652: quantidade inserida na baixa difere da tabela TMP.';
            END IF;

            COMMIT;
        END IF;
    END WHILE;
END
GO

CALL DBA.SP_CISS_183652_INSERE_BAIXAS()
GO
