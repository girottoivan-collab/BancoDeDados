-- CISS-183841 | Inspecao complementar, somente leitura
CONNECT TO NOPNEW01 USER dba USING "a9d9p8.E10";

SELECT i.indschema, i.indname, i.uniquerule, k.colseq, k.colname
  FROM syscat.indexes i
  LEFT JOIN syscat.indexcoluse k
    ON k.indschema = i.indschema
   AND k.indname = i.indname
 WHERE i.tabschema = 'DBA'
   AND i.tabname = 'ESTOQUE_SINTETICO'
 ORDER BY i.indschema, i.indname, k.colseq;

SELECT trigname, text
  FROM syscat.triggers
 WHERE tabschema = 'DBA'
   AND tabname = 'ESTOQUE_SINTETICO'
 ORDER BY trigname;

CONNECT RESET;
