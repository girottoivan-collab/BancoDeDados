CREATE OR REPLACE FUNCTION DBA.UF_ADMIN_BANDEIRA_TAXA_DATA (
    IN_IDEMPRESA        INTEGER,
    IN_IDADMINISTRADORA INTEGER,
    IN_IDBANDEIRA       INTEGER,
    IN_NUMPARCELA       SMALLINT,
    IN_DTMOVIMENTO      TIMESTAMP
)
RETURNS DECIMAL(12,6)
LANGUAGE SQL
READS SQL DATA
NO EXTERNAL ACTION
BEGIN
    DECLARE V_TAXA DECIMAL(12,6);

    SELECT
        COALESCE(
            (
                SELECT
                    H.PERCTAXA
                FROM
                    DBA.ADMINISTRADORAS_BANDEIRA_TAXA_HISTORICO H
                WHERE
                    H.IDEMPRESA = F.IDEMPRESA AND
                    H.IDADMINISTRADORA = F.IDADMINISTRADORA AND
                    H.IDBANDEIRA = F.IDBANDEIRA AND
                    H.NUMPARCELA < IN_NUMPARCELA AND
                    H.DTFIM > IN_DTMOVIMENTO
                ORDER BY
                    H.NUMPARCELA DESC,
                    H.DTFIM ASC
                FETCH FIRST 1 ROW ONLY
            ),
            F.TAXA_ATUAL
        )
    INTO
        V_TAXA
    FROM
        (
            SELECT
                AB.IDEMPRESA,
                AB.IDADMINISTRADORA,
                AB.IDBANDEIRA,
                SMALLINT(0) AS NUMPARCELA,
                AB.PERTAXAADMINISTRACAO AS TAXA_ATUAL
            FROM
                DBA.ADMINISTRADORAS_BANDEIRA AB
            WHERE
                AB.IDEMPRESA = IN_IDEMPRESA AND
                AB.IDADMINISTRADORA = IN_IDADMINISTRADORA AND
                AB.IDBANDEIRA = IN_IDBANDEIRA

            UNION ALL

            SELECT
                T.IDEMPRESA,
                T.IDADMINISTRADORA,
                T.IDBANDEIRA,
                T.NUMPARCELAS,
                T.TAXA
            FROM
                DBA.ADMINISTRADORAS_BANDEIRA_TAXAS T
            WHERE
                T.IDEMPRESA = IN_IDEMPRESA AND
                T.IDADMINISTRADORA = IN_IDADMINISTRADORA AND
                T.IDBANDEIRA = IN_IDBANDEIRA
        ) AS F
    WHERE
        F.NUMPARCELA < IN_NUMPARCELA
    ORDER BY
        F.NUMPARCELA DESC
    FETCH FIRST 1 ROW ONLY;

    RETURN COALESCE(V_TAXA, 0);
END
GO
