-- CISS-183841 | Validacao pos-deploy (somente leitura)
CONNECT TO NOPNEW01 USER dba USING "a9d9p8.E10";

SELECT colname, typename, length, scale, nulls
  FROM syscat.columns
 WHERE tabschema = 'DBA'
   AND tabname = 'ESTOQUE_SINTETICO'
   AND colname = 'DTALTERACAO';

SELECT trigname, trigevent, trigtime, granularity, valid
  FROM syscat.triggers
 WHERE tabschema = 'DBA'
   AND tabname = 'ESTOQUE_SINTETICO'
   AND trigname IN ('TR_ESTSIN_DTALTERACAO_BI', 'TR_ESTSIN_DTALTERACAO_BU', 'TR_ESTSIN_CMV_AD')
 ORDER BY trigname;

SELECT indschema, indname, uniquerule, colcount
  FROM syscat.indexes
 WHERE indschema = 'DBA'
   AND indname = 'IX_ESTSIN_DTALT_EMP_DT';

-- Esperado imediatamente apos o deploy: 0 linhas, pois o historico permanece NULL.
SELECT COUNT(*) AS REGISTROS_HISTORICOS_MARCADOS
  FROM DBA.ESTOQUE_SINTETICO
 WHERE DTALTERACAO IS NOT NULL;

CONNECT RESET;
