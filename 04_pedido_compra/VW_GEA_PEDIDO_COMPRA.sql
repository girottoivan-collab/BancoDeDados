CREATE OR REPLACE VIEW DBA.VW_GEA_PEDIDO_COMPRA AS
SELECT
    IDEMPRESA,
    IDPEDIDO,
    IDCLIFOR,
    DTMOVIMENTO,
    PEDIDO_COMPRA.DTALTERACAO,
    DBA.SOMA_DIAS(DTMOVIMENTO, DIASENTREGA) AS DTPREVENTREGA,
    0 AS ACRESCIMO,
    IDPAGAMENTO,
    0 AS DESCFORMA,
    0 AS PERACRESVENDA,
    'F' AS PRECOFIRME,
    CASE
        WHEN FLAGFRETECIF = 'T' THEN
            'C'
        ELSE
            'F'
    END AS CIFFOB,
    OBSGERAL,
    'F' AS ENCOMENDA,
    'F' AS ABASTECIMENTO,
    FLAGCANCELADO,
    (
        SELECT
            SUBSTR(
                XMLSERIALIZE(
                    XMLAGG(
                        XMLTEXT(
                            CONCAT(
                                ';',
                                DBA.DIF_DIAS(
                                    PEDIDO_COMPRA.DTMOVIMENTO,
                                    PEDIDO_COMPRA_VCTO.DTVENCIMENTO
                                )
                            )
                        )
                    ) AS VARCHAR(32000)
                ),
                2
            )
        FROM
            DBA.PEDIDO_COMPRA_VCTO AS PEDIDO_COMPRA_VCTO
        WHERE
            PEDIDO_COMPRA_VCTO.IDEMPRESA = PEDIDO_COMPRA.IDEMPRESA AND
            PEDIDO_COMPRA_VCTO.IDPEDIDO = PEDIDO_COMPRA.IDPEDIDO
    ) AS CONDICAO,
    '' AS TIPOCATEGORIA,
    0 AS TIPOITEMCATEGORIA,
    0 AS IDEMPRESAORIGEM,
    0 AS IDPEDIDOORIGEM,
    IDCLIFOR AS IDCLIFORORIGEM
FROM
    DBA.PEDIDO_COMPRA
LEFT OUTER JOIN
    DBA.FORMA_PAGREC ON
        PEDIDO_COMPRA.IDPAGAMENTO = FORMA_PAGREC.IDRECEBIMENTO
