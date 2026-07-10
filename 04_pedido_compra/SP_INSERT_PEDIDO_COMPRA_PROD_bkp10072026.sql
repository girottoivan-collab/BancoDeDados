CREATE OR REPLACE PROCEDURE DBA.SP_INSERT_PEDIDO_COMPRA_PROD (
    AI_IDSUBPRODUTO             INTEGER,
    AI_IDCLIFOR                 INTEGER,
    AI_IDPEDIDO                 INTEGER,
    AI_IDEMPRESA                INTEGER,
    ADE_PERDESCONTO1            DECIMAL(10, 6),
    ADE_PERDESCONTO2            DECIMAL(10, 6),
    ADE_PERDESCONTO3            DECIMAL(10, 6),
    ADE_PERDESCONTO4            DECIMAL(10, 6),
    ADE_PERIPI                  DECIMAL(10, 6),
    ADE_PERMARGEMLUCRO          DECIMAL(10, 6),
    ADE_QTDSOLICITADA           DECIMAL(12, 3),
    ADE_VALUNITARIO             DECIMAL(15, 6),
    ADE_PERICM                  DECIMAL(10, 6),
    ADE_VALTOTBRUTO             DECIMAL(15, 6),
    ADE_PERBONIFICACAO          DECIMAL(10, 6),
    ADE_VALTOTLIQUIDO           DECIMAL(15, 6),
    ADE_VALICMSUBST             DECIMAL(15, 6),
    ADE_PERFRETE                DECIMAL(10, 6),
    ADE_PERADICIONAL            DECIMAL(10, 6),
    ADE_PERIPIFRETE             DECIMAL(10, 6),
    ADE_VALDESCONTOICMS         DECIMAL(15, 6),
    ADE_PERIPIADICIONAL         DECIMAL(10, 6),
    ADE_VALIPI                  DECIMAL(15, 6),
    AC_FLAGSITUACAOATUAL        CHAR(1),
    ADE_PERACESSORIOS           DECIMAL(10, 6),
    ADE_PERIPIACESSORIOS        DECIMAL(10, 6),
    ADE_VALDESCONTOPISCOFINS    DECIMAL(15, 6),
    ADE_PERINFLACAO             DECIMAL(15, 6),
    ADE_PESOBRUTO               DECIMAL(12, 3),
    ADE_QTDTRANSFERIDA          DECIMAL(12, 3),
    AC_FLAGSALDOZERADO          CHAR(1),
    AD_DTENTREGA                DATE,
    AS_OBSPRODUTO               VARCHAR(400),
    ADE_QTDSUGERIDATRANSF       DECIMAL(12, 3),
    ADE_QTDSUGESTAOCOMPRA       DECIMAL(15, 3),
    AC_FLAGCALCULAST            CHAR(1),
    AC_OPERACAO                 CHAR(1),
    AI_IDLOCALRESERVA           INTEGER
)
BEGIN
    DECLARE AC_TIPOSITTRIB CHAR(1);
    DECLARE AI_IDCENARIOFISCAL BIGINT;
    DECLARE LI_IDPRODUTO INTEGER;
    DECLARE AI_IDSUGESTAO INTEGER;
    DECLARE AD_DTENTREGA DATE;
    DECLARE LI_IDLOCALRESERVA INTEGER DEFAULT NULL;

    SET AI_IDSUGESTAO = NULL;
    SET AC_TIPOSITTRIB = NULL;
    SET AI_IDCENARIOFISCAL = NULL;

    SET LI_IDPRODUTO = (
        SELECT
            IDPRODUTO
        FROM
            DBA.PRODUTO_GRADE
        WHERE
            IDSUBPRODUTO = AI_IDSUBPRODUTO
    );

    SET AD_DTENTREGA = NULL;

    IF AI_IDLOCALRESERVA <> 0 THEN

        SET LI_IDLOCALRESERVA = AI_IDLOCALRESERVA;

    END IF;

    IF AC_OPERACAO = 'D' THEN

        DELETE
        FROM
            DBA.PEDIDO_COMPRA_EMPRESA_TRANSFERENCIA
        WHERE
            IDEMPRESAGERADO = AI_IDEMPRESA AND
            IDPEDIDOGERADO = AI_IDPEDIDO AND
            IDCLIFORGERADO = AI_IDCLIFOR AND
            IDPRODUTO = LI_IDPRODUTO AND
            IDSUBPRODUTO = AI_IDSUBPRODUTO;

        DELETE
        FROM
            DBA.PEDIDO_COMPRA_PROD
        WHERE
            IDEMPRESA = AI_IDEMPRESA AND
            IDPEDIDO = AI_IDPEDIDO AND
            IDCLIFOR = AI_IDCLIFOR AND
            IDPRODUTO = LI_IDPRODUTO AND
            IDSUBPRODUTO = AI_IDSUBPRODUTO;

    ELSE

        IF NOT EXISTS (
            SELECT
                1
            FROM
                DBA.PEDIDO_COMPRA_PROD
            WHERE
                IDEMPRESA = AI_IDEMPRESA AND
                IDCLIFOR = AI_IDCLIFOR AND
                IDPEDIDO = AI_IDPEDIDO AND
                IDPRODUTO = LI_IDPRODUTO AND
                IDSUBPRODUTO = AI_IDSUBPRODUTO
        ) THEN

            INSERT INTO DBA.PEDIDO_COMPRA_PROD (
                IDPRODUTO,
                IDSUBPRODUTO,
                IDCLIFOR,
                IDPEDIDO,
                IDEMPRESA,
                IDSUGESTAO,
                PERDESCONTO1,
                PERDESCONTO2,
                PERDESCONTO3,
                PERDESCONTO4,
                PERIPI,
                PERMARGEMLUCRO,
                QTDSOLICITADA,
                QTDATENDIDA,
                VALUNITARIO,
                PERICM,
                VALTOTBRUTO,
                PERBONIFICACAO,
                VALTOTLIQUIDO,
                VALICMSUBST,
                PERFRETE,
                PERADICIONAL,
                PERIPIFRETE,
                VALDESCONTOICMS,
                TIPOSITTRIB,
                PERIPIADICIONAL,
                VALIPI,
                FLAGSITUACAOATUAL,
                PERACESSORIOS,
                PERIPIACESSORIOS,
                VALDESCONTOPISCOFINS,
                PERINFLACAO,
                PESOBRUTO,
                QTDTRANSFERIDA,
                FLAGSALDOZERADO,
                DTENTREGA,
                OBSPRODUTO,
                QTDSUGERIDATRANSF,
                FLAGATENDIDO,
                QTDSUGESTAOCOMPRA,
                FLAGCALCULAST,
                IDCENARIOFISCAL,
                IDLOCALESTOQUERESERVA
            ) VALUES (
                LI_IDPRODUTO,
                AI_IDSUBPRODUTO,
                AI_IDCLIFOR,
                AI_IDPEDIDO,
                AI_IDEMPRESA,
                AI_IDSUGESTAO,
                ADE_PERDESCONTO1,
                ADE_PERDESCONTO2,
                ADE_PERDESCONTO3,
                ADE_PERDESCONTO4,
                ADE_PERIPI,
                ADE_PERMARGEMLUCRO,
                ADE_QTDSOLICITADA,
                0,
                ADE_VALUNITARIO,
                ADE_PERICM,
                ADE_VALTOTBRUTO,
                ADE_PERBONIFICACAO,
                ADE_VALTOTLIQUIDO,
                ADE_VALICMSUBST,
                ADE_PERFRETE,
                ADE_PERADICIONAL,
                ADE_PERIPIFRETE,
                ADE_VALDESCONTOICMS,
                AC_TIPOSITTRIB,
                ADE_PERIPIADICIONAL,
                ADE_VALIPI,
                AC_FLAGSITUACAOATUAL,
                ADE_PERACESSORIOS,
                ADE_PERIPIACESSORIOS,
                ADE_VALDESCONTOPISCOFINS,
                ADE_PERINFLACAO,
                ADE_PESOBRUTO,
                ADE_QTDTRANSFERIDA,
                AC_FLAGSALDOZERADO,
                AD_DTENTREGA,
                AS_OBSPRODUTO,
                ADE_QTDSUGERIDATRANSF,
                'F',
                ADE_QTDSUGESTAOCOMPRA,
                AC_FLAGCALCULAST,
                AI_IDCENARIOFISCAL,
                LI_IDLOCALRESERVA
            );

        ELSE

            UPDATE
                DBA.PEDIDO_COMPRA_PROD
            SET
                IDSUGESTAO = AI_IDSUGESTAO,
                PERDESCONTO1 = ADE_PERDESCONTO1,
                PERDESCONTO2 = ADE_PERDESCONTO2,
                PERDESCONTO3 = ADE_PERDESCONTO3,
                PERDESCONTO4 = ADE_PERDESCONTO4,
                PERIPI = ADE_PERIPI,
                PERMARGEMLUCRO = ADE_PERMARGEMLUCRO,
                QTDSOLICITADA = ADE_QTDSOLICITADA,
                VALUNITARIO = ADE_VALUNITARIO,
                PERICM = ADE_PERICM,
                VALTOTBRUTO = ADE_VALTOTBRUTO,
                PERBONIFICACAO = ADE_PERBONIFICACAO,
                VALTOTLIQUIDO = ADE_VALTOTLIQUIDO,
                VALICMSUBST = ADE_VALICMSUBST,
                PERFRETE = ADE_PERFRETE,
                PERADICIONAL = ADE_PERADICIONAL,
                PERIPIFRETE = ADE_PERIPIFRETE,
                VALDESCONTOICMS = ADE_VALDESCONTOICMS,
                TIPOSITTRIB = AC_TIPOSITTRIB,
                PERIPIADICIONAL = ADE_PERIPIADICIONAL,
                VALIPI = ADE_VALIPI,
                FLAGSITUACAOATUAL = AC_FLAGSITUACAOATUAL,
                PERACESSORIOS = ADE_PERACESSORIOS,
                PERIPIACESSORIOS = ADE_PERIPIACESSORIOS,
                VALDESCONTOPISCOFINS = ADE_VALDESCONTOPISCOFINS,
                PERINFLACAO = ADE_PERINFLACAO,
                PESOBRUTO = ADE_PESOBRUTO,
                QTDTRANSFERIDA = ADE_QTDTRANSFERIDA,
                FLAGSALDOZERADO = AC_FLAGSALDOZERADO,
                DTENTREGA = AD_DTENTREGA,
                OBSPRODUTO = AS_OBSPRODUTO,
                QTDSUGERIDATRANSF = ADE_QTDSUGERIDATRANSF,
                QTDSUGESTAOCOMPRA = ADE_QTDSUGESTAOCOMPRA,
                FLAGCALCULAST = AC_FLAGCALCULAST,
                IDCENARIOFISCAL = AI_IDCENARIOFISCAL,
                IDLOCALESTOQUERESERVA = LI_IDLOCALRESERVA
            WHERE
                IDEMPRESA = AI_IDEMPRESA AND
                IDCLIFOR = AI_IDCLIFOR AND
                IDPEDIDO = AI_IDPEDIDO AND
                IDPRODUTO = LI_IDPRODUTO AND
                IDSUBPRODUTO = AI_IDSUBPRODUTO;

        END IF;

    END IF;

END
