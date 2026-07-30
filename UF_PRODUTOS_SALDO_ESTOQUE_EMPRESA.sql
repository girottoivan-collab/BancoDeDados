CREATE OR REPLACE FUNCTION INTEGRIM.UF_PRODUTOS_SALDO_ESTOQUE_EMPRESA (
    IN_IDEMPRESA            INTEGER,
    IN_IDLOCALESTOQUE       INTEGER,
    IN_IDPRODUTO            INTEGER,
    IN_IDSUBPRODUTO         INTEGER
)  RETURNS TABLE (
    IDEMPRESA               INTEGER,
    IDPRODUTO               INTEGER,
    IDSUBPRODUTO            INTEGER,
    IDLOCALESTOQUE          INTEGER,
    DESCRLOCALESTOQUE       VARCHAR(40),
    FLAGLOTE                CHAR(1),
    DESCRLOTE               VARCHAR(30),
    FLAGESTNEGATIVO         CHAR(1),
    QTDSALDOATUAL           DECIMAL(15,3),
    QTDSALDORESERVA         DECIMAL(15,3),
    QTDSALDODISPONIVEL      DECIMAL(15,3),
    DTALTERACAO             TIMESTAMP
)
LANGUAGE SQL
RETURN
    SELECT
        TMP.IDEMPRESA,
        TMP.IDPRODUTO,
        TMP.IDSUBPRODUTO,
        TMP.IDLOCALESTOQUE,
        ECL.DESCRLOCAL AS DESCRLOCALESTOQUE,
        TMP.FLAGLOTE,
        TMP.IDLOTE AS DESCRLOTE,
        TMP.FLAGESTNEGATIVO,
        TMP.QTDATUALESTOQUE AS QTDSALDOATUAL,
        TMP.QTDSALDORESERVA,
        (TMP.QTDATUALESTOQUE - TMP.QTDSALDORESERVA) AS QTDSALDODISPONIVEL,
        TMP.DTALTERACAO
    FROM
        (
        SELECT
            COALESCE((
                CASE WHEN PG.FLAGLOTE = 'T' THEN
                    ESL.QTDATUALESTOQUE
                ELSE
                    ESA.QTDATUALESTOQUE
                END),0) AS QTDATUALESTOQUE,
            COALESCE((
                CASE WHEN CG.FLAGATIVARESERVA = 'T' OR CG.FLAGINATIVARESERVAVENDAFUTURA = 'T' OR CG.FLAGATIVARESERVAPRENOTA = 'T' OR CG.FLAGATIVARESERVAORCAMENTO = 'T' THEN
                    (SELECT
                        SUM(EAT.QTDPRODUTO)
                    FROM
                        DBA.ESTOQUE_ANALITICO_TMP EAT
                    LEFT OUTER JOIN DBA.ORCAMENTO O ON (
                       EAT.NUMPEDIDO = O.IDORCAMENTO AND
                        EAT.IDEMPRESA = O.IDEMPRESA
                        )
                    WHERE
                        EAT.IDPRODUTO = PG.IDPRODUTO AND (
                            (EAT.IDSUBPRODUTO = PG.IDSUBPRODUTO AND PROD.TIPOBAIXAMESTRE = 'I') OR (PROD.TIPOBAIXAMESTRE <> 'I')
                        ) AND (
                            (COALESCE(PG.FLAGLOTE,'F') <> 'T' AND EAT.IDEMPRESABAIXAEST = ESA.IDEMPRESA AND EAT.IDLOCALESTOQUE = ESA.IDLOCALESTOQUE) OR
                            (COALESCE(PG.FLAGLOTE,'F') = 'T'  AND EAT.IDEMPRESABAIXAEST = ESL.IDEMPRESA AND EAT.IDLOCALESTOQUE = ESL.IDLOCALESTOQUE AND EAT.IDLOTE = ESL.IDLOTE)
                        )
                        AND
                        (
                         EAT.TIPODOCUMENTO NOT IN('X','O','N','P','U','C','M')
                         OR (
                            EAT.TIPODOCUMENTO IN('X','O') AND
                            (
                                (
                                    COALESCE(O.DTVALIDADE,date('1900-01-01')) >= TODAY() OR O.FLAGPRENOTAPAGA = 'T'
                                ) OR (
                                    CG.FLAGATIVARESERVA = 'T' AND
                                    CG.FLAGATIVARESERVAORCAMENTO = 'T' AND
                                    EAT.TIPODOCUMENTO = 'O' AND
                                    COALESCE(EAT.TIPOENTREGA,'') NOT IN ('A','E')  AND
                                    EAT.NUMPEDIDO IS NULL
                                )
                            )
                        )
                        OR (
                            CG.FLAGATIVARESERVA = 'T' AND
                            CG.FLAGATIVARESERVAPRENOTA = 'T' AND
                            EAT.TIPODOCUMENTO = 'X' AND
                            COALESCE(EAT.TIPOENTREGA,'') NOT IN ('A','E')  AND
                            EAT.NUMPEDIDO IS NULL
                        )
                        OR (
                            CG.FLAGATIVARESERVA = 'T' AND
                            EAT.TIPODOCUMENTO IN ('N','P','U','C')
                        )
                        OR (
                            CG.FLAGINATIVARESERVAVENDAFUTURA = 'T' AND
                            EAT.TIPODOCUMENTO = 'M'
                        )
                    )
                )
                ELSE
                    CAST(0 AS DECIMAL(15,3))
                END),0) AS QTDSALDORESERVA,
            CASE WHEN PG.FLAGLOTE = 'T' THEN
                ESL.IDLOCALESTOQUE
            ELSE
                ESA.IDLOCALESTOQUE
            END AS IDLOCALESTOQUE,
            CASE WHEN PG.FLAGLOTE = 'T' THEN
                ESL.IDEMPRESA
            ELSE
                ESA.IDEMPRESA
            END AS IDEMPRESA,
            PG.IDPRODUTO,
            PG.IDSUBPRODUTO,
            PG.FLAGESTNEGATIVO,
            COALESCE(PG.FLAGLOTE,'F') AS FLAGLOTE,
            ESL.IDLOTE,
            CASE WHEN PG.FLAGLOTE = 'T' THEN
                COALESCE(ESA.DTALTERACAO, TIMESTAMP(ESL.DTMOVIMENTO))
            ELSE
                COALESCE(ESA.DTALTERACAO, TIMESTAMP(ESA.DTMOVIMENTO))
            END AS DTALTERACAO
        FROM
            DBA.CONFIG_GERAL CG,
            DBA.PRODUTO_GRADE PG
        INNER JOIN
            DBA.PRODUTO PROD ON (
                PG.IDPRODUTO = PROD.IDPRODUTO
            )
        LEFT OUTER JOIN
            (SELECT
                E.IDPRODUTO,
                E.IDSUBPRODUTO,
                E.IDLOCALESTOQUE,
                E.IDEMPRESA,
                E.QTDATUALESTOQUE,
                E.DTMOVIMENTO,
                E.DTALTERACAO
            FROM
                DBA.ESTOQUE_SALDO_ATUAL E
            WHERE
                (IN_IDEMPRESA = 0 OR E.IDEMPRESA = IN_IDEMPRESA) AND
                (IN_IDLOCALESTOQUE = 0 OR E.IDLOCALESTOQUE = IN_IDLOCALESTOQUE) AND
                (IN_IDPRODUTO = 0 OR E.IDPRODUTO = IN_IDPRODUTO) AND
                (IN_IDSUBPRODUTO = 0 OR E.IDSUBPRODUTO = IN_IDSUBPRODUTO)
                AND (
                    SELECT
                        COUNT(0)
                    FROM
                        DBA.PRODUTO_GRADE P
                    WHERE
                        P.IDSUBPRODUTO = E.IDSUBPRODUTO AND
                        P.FLAGLOTE = 'T'
                ) = 0
            ) ESA ON (
                PG.IDPRODUTO = ESA.IDPRODUTO AND
                PG.IDSUBPRODUTO = ESA.IDSUBPRODUTO
                )
        LEFT OUTER JOIN
            (SELECT
                ESLO.IDLOTE,
                ESLO.IDEMPRESA,
                ESLO.IDPRODUTO,
                ESLO.IDSUBPRODUTO,
                ESLO.IDLOCALESTOQUE,
                ESLO.DTMOVIMENTO,
                ESLO.QTDATUALESTOQUE
            FROM
                DBA.ESTOQUE_SINTETICO_LOTE ESLO
            WHERE
                (IN_IDEMPRESA = 0 OR ESLO.IDEMPRESA = IN_IDEMPRESA) AND
                (IN_IDLOCALESTOQUE = 0 OR ESLO.IDLOCALESTOQUE = IN_IDLOCALESTOQUE) AND
                (IN_IDPRODUTO = 0 OR ESLO.IDPRODUTO = IN_IDPRODUTO) AND
                (IN_IDSUBPRODUTO = 0 OR ESLO.IDSUBPRODUTO = IN_IDSUBPRODUTO)
                AND (
                    SELECT
                        COUNT(0)
                    FROM
                        DBA.PRODUTO_GRADE P
                    WHERE
                        P.IDSUBPRODUTO = ESLO.IDSUBPRODUTO AND
                        P.FLAGLOTE = 'T'
                ) > 0
                AND ESLO.DTMOVIMENTO = (
                    SELECT
                       MAX(TMP.DTMOVIMENTO)
                    FROM
                        DBA.ESTOQUE_SINTETICO_LOTE AS TMP
                    WHERE
                        TMP.IDPRODUTO = ESLO.IDPRODUTO AND
                        TMP.IDSUBPRODUTO = ESLO.IDSUBPRODUTO AND
                        TMP.IDEMPRESA = ESLO.IDEMPRESA AND
                        TMP.IDLOTE = ESLO.IDLOTE AND
                        TMP.IDLOCALESTOQUE = ESLO.IDLOCALESTOQUE
                )
            ) ESL ON (
                PG.IDPRODUTO = ESL.IDPRODUTO AND
                PG.IDSUBPRODUTO = ESL.IDSUBPRODUTO
            )
        WHERE
            (IN_IDPRODUTO    = 0 OR PG.IDPRODUTO    = IN_IDPRODUTO   ) AND
            (IN_IDSUBPRODUTO = 0 OR PG.IDSUBPRODUTO = IN_IDSUBPRODUTO)
        ) AS TMP
        LEFT JOIN DBA.ESTOQUE_CADASTRO_LOCAL AS ECL ON(
            ECL.IDLOCALESTOQUE = TMP.IDLOCALESTOQUE
        )
    WHERE
        (IN_IDEMPRESA = 0 OR TMP.IDEMPRESA = IN_IDEMPRESA);
