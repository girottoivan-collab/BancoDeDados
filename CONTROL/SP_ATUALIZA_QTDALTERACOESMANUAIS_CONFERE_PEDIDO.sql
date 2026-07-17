ALTER TABLE DBA.CONFERE_PEDIDO ADD COLUMN QTDALTERACOESMANUAIS INTEGER
GO

CREATE OR REPLACE PROCEDURE DBA.SP_ATUALIZA_QTDALT_MAN_CONF_PED()
LANGUAGE SQL
MODIFIES SQL DATA
BEGIN

    DECLARE V_QTD_REGISTROS INTEGER DEFAULT 1;

    WHILE V_QTD_REGISTROS > 0 DO
        UPDATE
            DBA.CONFERE_PEDIDO AS CP
        SET
            QTDALTERACOESMANUAIS = 0
        WHERE
            CP.QTDALTERACOESMANUAIS IS NULL AND
            EXISTS (
                SELECT
                    1
                FROM
                    (
                        SELECT
                            CP_LOTE.IDPRODUTO,
                            CP_LOTE.IDSUBPRODUTO,
                            CP_LOTE.IDCLIFOR,
                            CP_LOTE.IDEMPRESA,
                            CP_LOTE.NUMNOTA,
                            CP_LOTE.IDAUTORIZACAO,
                            CP_LOTE.SERIENOTA,
                            CP_LOTE.IDPEDIDO
                        FROM
                            DBA.CONFERE_PEDIDO AS CP_LOTE
                        WHERE
                            CP_LOTE.QTDALTERACOESMANUAIS IS NULL
                        FETCH FIRST 10000 ROWS ONLY
                    ) AS CP_LOTE
                WHERE
                    CP_LOTE.IDPRODUTO = CP.IDPRODUTO AND
                    CP_LOTE.IDSUBPRODUTO = CP.IDSUBPRODUTO AND
                    CP_LOTE.IDCLIFOR = CP.IDCLIFOR AND
                    CP_LOTE.IDEMPRESA = CP.IDEMPRESA AND
                    CP_LOTE.NUMNOTA = CP.NUMNOTA AND
                    CP_LOTE.IDAUTORIZACAO = CP.IDAUTORIZACAO AND
                    CP_LOTE.SERIENOTA = CP.SERIENOTA AND
                    CP_LOTE.IDPEDIDO = CP.IDPEDIDO
            );

        GET DIAGNOSTICS V_QTD_REGISTROS = ROW_COUNT;

        COMMIT;
    END WHILE;

END
GO

CALL DBA.SP_ATUALIZA_QTDALT_MAN_CONF_PED()
GO

ALTER TABLE DBA.CONFERE_PEDIDO ALTER COLUMN QTDALTERACOESMANUAIS SET NOT NULL
GO

CALL SYSPROC.ADMIN_CMD('REORG TABLE DBA.CONFERE_PEDIDO')
GO
