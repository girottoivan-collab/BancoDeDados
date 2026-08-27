WITH NOTAS_MOVIMENTO AS (
        SELECT
                EA.IDEMPRESA,
                EA.IDPLANILHA,
                N.IDCLIFOR
        FROM
                DBA.ESTOQUE_ANALITICO EA
                INNER JOIN DBA.OPERACAO_INTERNA OI ON
                        OI.IDOPERACAO = EA.IDOPERACAO
                INNER JOIN DBA.NOTAS N ON
                        N.IDEMPRESA = EA.IDEMPRESA
                        AND N.IDPLANILHA = EA.IDPLANILHA
        WHERE
                EA.IDOPERACAO < 1000
                AND OI.TIPOMOVIMENTO = 'C'
                AND N.FLAGMOVFISCAL = 'T'
                AND N.FLAGNOTACANCEL = 'F'
                AND EA.DTMOVIMENTO BETWEEN :RA_DTINI AND :RA_DTFIM
        GROUP BY
                EA.IDEMPRESA,
                EA.IDPLANILHA,
                N.IDCLIFOR
),
TRIBUTACOES_NOTA AS (
        SELECT
                NM.IDEMPRESA,
                NM.IDPLANILHA,
                NM.IDCLIFOR,
                MAX(CASE WHEN EA.IDSITTRIB IN (40, 140, 240, 340, 440, 540, 640, 740, 840) THEN 1 ELSE 0 END) AS TEM_40,
                MAX(CASE WHEN EA.IDSITTRIB IN (41, 141, 241, 341, 441, 541, 641, 741, 841) THEN 1 ELSE 0 END) AS TEM_41,
                MAX(CASE WHEN EA.IDSITTRIB IN (50, 150, 250, 350, 450, 550, 650, 750, 850) THEN 1 ELSE 0 END) AS TEM_50,
                MAX(CASE WHEN EA.IDSITTRIB IN (90, 190, 290, 390, 490, 590, 690, 790, 890) THEN 1 ELSE 0 END) AS TEM_90
        FROM
                NOTAS_MOVIMENTO NM
                INNER JOIN DBA.ESTOQUE_ANALITICO EA ON
                        EA.IDEMPRESA = NM.IDEMPRESA
                        AND EA.IDPLANILHA = NM.IDPLANILHA
        WHERE
                EA.DTMOVIMENTO BETWEEN :RA_DTINI AND :RA_DTFIM
        GROUP BY
                NM.IDEMPRESA,
                NM.IDPLANILHA,
                NM.IDCLIFOR
),
COMBINACOES AS (
        SELECT
                TN.IDEMPRESA,
                TN.IDPLANILHA,
                TN.IDCLIFOR,
                CASE
                        WHEN TEM_40 = 1 AND TEM_41 = 1 AND TEM_50 = 1 AND TEM_90 = 1 THEN 'ISENTO-40 + NAOTRIBUTADO-41 + SUSPENSO-50 + OUTROS-90'
                        WHEN TEM_40 = 1 AND TEM_41 = 1 AND TEM_50 = 1 THEN 'ISENTO-40 + NAOTRIBUTADO-41 + SUSPENSO-50'
                        WHEN TEM_40 = 1 AND TEM_41 = 1 AND TEM_90 = 1 THEN 'ISENTO-40 + NAOTRIBUTADO-41 + OUTROS-90'
                        WHEN TEM_40 = 1 AND TEM_50 = 1 AND TEM_90 = 1 THEN 'ISENTO-40 + SUSPENSO-50 + OUTROS-90'
                        WHEN TEM_41 = 1 AND TEM_50 = 1 AND TEM_90 = 1 THEN 'NAOTRIBUTADO-41 + SUSPENSO-50 + OUTROS-90'
                        WHEN TEM_40 = 1 AND TEM_41 = 1 THEN 'ISENTO-40 + NAOTRIBUTADO-41'
                        WHEN TEM_40 = 1 AND TEM_50 = 1 THEN 'ISENTO-40 + SUSPENSO-50'
                        WHEN TEM_40 = 1 AND TEM_90 = 1 THEN 'ISENTO-40 + OUTROS-90'
                        WHEN TEM_41 = 1 AND TEM_50 = 1 THEN 'NAOTRIBUTADO-41 + SUSPENSO-50'
                        WHEN TEM_41 = 1 AND TEM_90 = 1 THEN 'NAOTRIBUTADO-41 + OUTROS-90'
                        WHEN TEM_50 = 1 AND TEM_90 = 1 THEN 'SUSPENSO-50 + OUTROS-90'
                END AS TIPO
        FROM
                TRIBUTACOES_NOTA TN
        WHERE
                (TEM_40 + TEM_41 + TEM_50 + TEM_90) >= 2
),
TRIBUTACAO_XML AS (
        SELECT
                EAF.IDEMPRESA,
                EAF.IDPLANILHA,
                CASE
                        WHEN SUM(CASE WHEN EAF.FLAGTRIBUTACAOXML = 'T' THEN 1 ELSE 0 END) = COUNT(*) THEN 'T'
                        ELSE 'F'
                END AS FLAGTRIBUTACAOXML
        FROM
                DBA.ESTOQUE_ANALITICO_FISCAL EAF
                INNER JOIN NOTAS_MOVIMENTO NM ON
                        NM.IDEMPRESA = EAF.IDEMPRESA
                        AND NM.IDPLANILHA = EAF.IDPLANILHA
        GROUP BY
                EAF.IDEMPRESA,
                EAF.IDPLANILHA
),
DADOS_FORNECEDOR AS (
        SELECT
                CF.IDCLIFOR,
                CF.IDATIVIDADE,
                TA.DESCRTIPOATIVIDADE AS ATIVIDADE,
                ATV.FLAGPRODUTORRURAL AS PRODUTOR
        FROM
                DBA.CLIENTE_FORNECEDOR CF
                LEFT JOIN DBA.ATIVIDADE ATV ON
                        ATV.IDATIVIDADE = CF.IDATIVIDADE
                LEFT JOIN DBA.ATIVIDADE_TIPO_ATIVIDADE ATA ON
                        ATA.IDATIVIDADE = CF.IDATIVIDADE
                        AND ATA.FLAGPADRAO = 'T'
                LEFT JOIN DBA.TIPO_ATIVIDADE TA ON
                        TA.IDTIPOATIVIDADE = ATA.IDTIPOATIVIDADE
)
SELECT
        C.IDCLIFOR,
        DF.IDATIVIDADE,
        DF.ATIVIDADE,
        DF.PRODUTOR,
        C.IDPLANILHA,
        C.TIPO,
        1 AS QTDNOTAS,
        CASE WHEN COALESCE(TX.FLAGTRIBUTACAOXML, 'F') = 'T' THEN 1 ELSE 0 END AS XML,
        CASE WHEN COALESCE(TX.FLAGTRIBUTACAOXML, 'F') = 'F' THEN 1 ELSE 0 END AS CAD,
        DECIMAL(
                CASE WHEN COALESCE(TX.FLAGTRIBUTACAOXML, 'F') = 'T' THEN 100 ELSE 0 END,
                15,
                2
        ) AS "% XML",
        DECIMAL(
                CASE WHEN COALESCE(TX.FLAGTRIBUTACAOXML, 'F') = 'F' THEN 100 ELSE 0 END,
                15,
                2
        ) AS "% CAD"
FROM
        COMBINACOES C
        LEFT JOIN DADOS_FORNECEDOR DF ON
                DF.IDCLIFOR = C.IDCLIFOR
        LEFT JOIN TRIBUTACAO_XML TX ON
                TX.IDEMPRESA = C.IDEMPRESA
                AND TX.IDPLANILHA = C.IDPLANILHA
ORDER BY
        C.IDCLIFOR,
        DF.IDATIVIDADE,
        DF.ATIVIDADE,
        DF.PRODUTOR,
        C.IDPLANILHA,
        C.TIPO
