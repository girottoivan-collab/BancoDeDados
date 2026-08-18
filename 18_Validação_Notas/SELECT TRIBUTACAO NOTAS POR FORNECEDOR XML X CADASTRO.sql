WITH NOTAS_MOVIMENTO AS (
        SELECT
                YEAR(EA.DTMOVIMENTO) AS ANO,
                MONTH(EA.DTMOVIMENTO) AS MES_NUM,
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
                AND EA.DTMOVIMENTO BETWEEN :RA_DTINI AND :RA_DTFIM
        GROUP BY
                YEAR(EA.DTMOVIMENTO),
                MONTH(EA.DTMOVIMENTO),
                EA.IDEMPRESA,
                EA.IDPLANILHA,
                N.IDCLIFOR
),
ITENS_TRIBUTACAO AS (
        SELECT
                NM.ANO,
                NM.MES_NUM,
                NM.IDEMPRESA,
                NM.IDPLANILHA,
                NM.IDCLIFOR,
                CASE
                        WHEN EA.IDSITTRIB IN (40, 140, 240, 340, 440, 540, 640, 740, 840) THEN 'ISENTO-40'
                        WHEN EA.IDSITTRIB IN (0, 100, 200, 300, 400, 500, 600, 700, 800) THEN 'TRIBUTADO-00'
                        WHEN EA.IDSITTRIB IN (20, 120, 220, 320, 420, 520, 620, 720, 820) THEN 'REDUCAO-20'
                        WHEN EA.IDSITTRIB IN (50, 150, 250, 350, 450, 550, 650, 750, 850) THEN 'SUSPENSO-50'
                        WHEN EA.IDSITTRIB IN (51, 151, 251, 351, 451, 551, 651, 751, 851) THEN 'SUSPENSO-51'
                        WHEN EA.IDSITTRIB IN (41, 141, 241, 341, 441, 541, 641, 741, 841) THEN 'NAOTRIBUTADO-41'
                        WHEN EA.IDSITTRIB IN (90, 190, 290, 390, 490, 590, 690, 790, 890) THEN 'OUTROS-90'
                        WHEN EA.IDSITTRIB IN (60, 160, 260, 360, 460, 560, 660, 760, 860) THEN 'SUBST-60'
                        WHEN EA.IDSITTRIB IN (61, 161, 261, 361, 461, 561, 661, 761, 861) THEN 'SUBST-61'
                END AS TIPO
        FROM
                NOTAS_MOVIMENTO NM
                INNER JOIN DBA.ESTOQUE_ANALITICO EA ON
                        EA.IDEMPRESA = NM.IDEMPRESA
                        AND EA.IDPLANILHA = NM.IDPLANILHA
        WHERE
                EA.DTMOVIMENTO BETWEEN :RA_DTINI AND :RA_DTFIM
),
TIPO_NOTA AS (
        SELECT
                ANO,
                MES_NUM,
                IDEMPRESA,
                IDPLANILHA,
                IDCLIFOR,
                MAX(TIPO) AS TIPO
        FROM
                ITENS_TRIBUTACAO
        GROUP BY
                ANO,
                MES_NUM,
                IDEMPRESA,
                IDPLANILHA,
                IDCLIFOR
        HAVING
                COUNT(DISTINCT COALESCE(TIPO, 'OUTRO')) = 1
                AND MAX(TIPO) IS NOT NULL
),
TRIBUTACAO_XML AS (
        SELECT
                NM.ANO,
                NM.MES_NUM,
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
                NM.ANO,
                NM.MES_NUM,
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
),
NOTAS_TOTAL AS (
        SELECT
                YEAR(N.DTMOVIMENTO) AS ANO,
                MONTH(N.DTMOVIMENTO) AS MES_NUM,
                N.IDEMPRESA,
                N.IDPLANILHA,
                N.IDCLIFOR
        FROM
                DBA.NOTAS N
                INNER JOIN DBA.NOTAS_ENTRADA_SAIDA NES ON
                        NES.IDEMPRESA = N.IDEMPRESA
                        AND NES.IDPLANILHA = N.IDPLANILHA
                INNER JOIN DBA.OPERACAO_INTERNA OI ON
                        OI.IDOPERACAO = NES.IDOPERACAO
        WHERE
                NES.IDOPERACAO < 1000
                AND OI.TIPOMOVIMENTO = 'C'
                AND N.FLAGMOVFISCAL = 'T'
                AND N.DTMOVIMENTO BETWEEN DBA.DTINI(:RA_DTINI) AND DBA.DTFIM(:RA_DTFIM)
        GROUP BY
                YEAR(N.DTMOVIMENTO),
                MONTH(N.DTMOVIMENTO),
                N.IDEMPRESA,
                N.IDPLANILHA,
                N.IDCLIFOR
),
TOTAIS_FORNECEDOR AS (
        SELECT
                ANO,
                MES_NUM,
                IDCLIFOR,
                COUNT(*) AS QTDTOTAL
        FROM
                NOTAS_TOTAL
        GROUP BY
                ANO,
                MES_NUM,
                IDCLIFOR
),
APURACAO AS (
        SELECT
                TN.ANO,
                TN.MES_NUM,
                TN.IDCLIFOR,
                DF.IDATIVIDADE,
                DF.ATIVIDADE,
                DF.PRODUTOR,
                TN.TIPO,
                COUNT(*) AS QTDNOTASTIPO,
                SUM(CASE WHEN COALESCE(TX.FLAGTRIBUTACAOXML, 'F') = 'T' THEN 1 ELSE 0 END) AS XML,
                SUM(CASE WHEN COALESCE(TX.FLAGTRIBUTACAOXML, 'F') = 'F' THEN 1 ELSE 0 END) AS CADASTRO
        FROM
                TIPO_NOTA TN
                LEFT JOIN TRIBUTACAO_XML TX ON
                        TX.ANO = TN.ANO
                        AND TX.MES_NUM = TN.MES_NUM
                        AND TX.IDEMPRESA = TN.IDEMPRESA
                        AND TX.IDPLANILHA = TN.IDPLANILHA
                LEFT JOIN DADOS_FORNECEDOR DF ON
                        DF.IDCLIFOR = TN.IDCLIFOR
        GROUP BY
                TN.ANO,
                TN.MES_NUM,
                TN.IDCLIFOR,
                DF.IDATIVIDADE,
                DF.ATIVIDADE,
                DF.PRODUTOR,
                TN.TIPO
)
SELECT
        RIGHT('00' || RTRIM(CHAR(A.MES_NUM)), 2) || '/' || RTRIM(CHAR(A.ANO)) AS MES,
        A.IDCLIFOR,
        A.IDATIVIDADE,
        A.ATIVIDADE,
        A.PRODUTOR,
        A.TIPO,
        A.QTDNOTASTIPO,
        A.XML,
        A.CADASTRO,
        SUM(A.QTDNOTASTIPO) OVER (PARTITION BY A.ANO, A.MES_NUM, A.IDCLIFOR) AS QTDNOTAS,
        (CAST(A.QTDNOTASTIPO AS DECIMAL(15,6)) /
                NULLIF(CAST(SUM(A.QTDNOTASTIPO) OVER (PARTITION BY A.ANO, A.MES_NUM, A.IDCLIFOR) AS DECIMAL(15,6)), 0)) * 100 AS PERREPRESENTATIPO,
        COALESCE(TF.QTDTOTAL, 0) AS QTDTOTAL,
        (CAST(A.QTDNOTASTIPO AS DECIMAL(15,6)) /
                NULLIF(CAST(TF.QTDTOTAL AS DECIMAL(15,6)), 0)) * 100 AS PERREPRESENTATOTAL
FROM
        APURACAO A
        LEFT JOIN TOTAIS_FORNECEDOR TF ON
                TF.ANO = A.ANO
                AND TF.MES_NUM = A.MES_NUM
                AND TF.IDCLIFOR = A.IDCLIFOR
ORDER BY
        A.ANO,
        A.MES_NUM,
        A.IDCLIFOR,
        A.IDATIVIDADE,
        A.ATIVIDADE,
        A.PRODUTOR,
        A.TIPO
