-- CISS-183841 | Consulta somente leitura para identificar a codificacao do status Pendente.
CONNECT TO NOPNEW01 USER dba USING "a9d9p8.E10";

SELECT TPSTATUS, COUNT(*) AS QUANTIDADE
  FROM DBA.CONTABIL_PROCESSAMENTO_CMV
 GROUP BY TPSTATUS
 ORDER BY TPSTATUS;

SELECT tabname, remarks
  FROM syscat.tables
 WHERE tabschema = 'DBA'
   AND tabname = 'CONTABIL_PROCESSAMENTO_CMV';

SELECT colname, remarks
  FROM syscat.columns
 WHERE tabschema = 'DBA'
   AND tabname = 'CONTABIL_PROCESSAMENTO_CMV'
   AND colname = 'TPSTATUS';

CONNECT RESET;
