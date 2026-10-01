-- CISS-183841 | Inspecao somente leitura - DB2 alias tecnico NOPNEW01
CONNECT TO NOPNEW01 USER dba USING "a9d9p8.E10";

SELECT colno, colname, typename, length, scale, nulls
  FROM syscat.columns
 WHERE tabschema = 'DBA'
   AND tabname = 'ESTOQUE_SINTETICO'
 ORDER BY colno;

SELECT i.indname, i.uniquerule, i.colcount, i.remarks
  FROM syscat.indexes i
 WHERE i.tabschema = 'DBA'
   AND i.tabname = 'ESTOQUE_SINTETICO'
 ORDER BY i.indname;

SELECT k.indname, k.colseq, k.colname, k.colorder
  FROM syscat.indexcoluse k
 WHERE k.indschema = 'DBA'
   AND EXISTS (
       SELECT 1
         FROM syscat.indexes i
        WHERE i.indschema = k.indschema
          AND i.indname = k.indname
          AND i.tabschema = 'DBA'
          AND i.tabname = 'ESTOQUE_SINTETICO'
   )
 ORDER BY k.indname, k.colseq;

SELECT trigname, trigevent, granularity, trigtime, valid
  FROM syscat.triggers
 WHERE tabschema = 'DBA'
   AND tabname = 'ESTOQUE_SINTETICO'
 ORDER BY trigname;

SELECT colno, colname, typename, length, scale, nulls
  FROM syscat.columns
 WHERE tabschema = 'DBA'
   AND tabname = 'CONTABIL_PROCESSAMENTO_CMV'
 ORDER BY colno;

SELECT i.indname, i.uniquerule, k.colseq, k.colname
  FROM syscat.indexes i
  JOIN syscat.indexcoluse k
    ON k.indschema = i.indschema
   AND k.indname = i.indname
 WHERE i.tabschema = 'DBA'
   AND i.tabname = 'CONTABIL_PROCESSAMENTO_CMV'
 ORDER BY i.indname, k.colseq;

VALUES CURRENT TIMESTAMP;
CONNECT RESET;
