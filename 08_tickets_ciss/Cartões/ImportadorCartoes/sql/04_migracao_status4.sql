-- Provisiona o cadastro sem preencher terminais automaticamente.
BEGIN
    IF NOT EXISTS (
        SELECT 1
          FROM SYSCAT.TABLES
         WHERE TABSCHEMA = 'DBA'
           AND TABNAME = 'BIGSM_CADTERMINAL'
    ) THEN
        EXECUTE IMMEDIATE '
            CREATE TABLE DBA.BIGSM_CADTERMINAL (
                IDEMPRESA INTEGER,
                CODTERMINAL VARCHAR(40)
            )';
    END IF;
END
@
-- Amplia a restricao anterior sem apagar nem reclassificar o historico.
BEGIN
    DECLARE V_CONSTRAINT VARCHAR(128);

    SELECT MIN(CONSTNAME)
      INTO V_CONSTRAINT
      FROM SYSCAT.CHECKS
     WHERE TABSCHEMA = 'TMP'
       AND TABNAME = 'CARTOES_MOVIMENTO_PROCESSADOS'
       AND REPLACE(VARCHAR(TEXT, 32672), ' ', '') = 'STATUSIN(0,1,2,3)';

    IF V_CONSTRAINT IS NOT NULL THEN
        EXECUTE IMMEDIATE
            'ALTER TABLE TMP.CARTOES_MOVIMENTO_PROCESSADOS DROP CONSTRAINT "'
            || REPLACE(V_CONSTRAINT, '"', '""') || '"';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM SYSCAT.CHECKS
         WHERE TABSCHEMA = 'TMP'
           AND TABNAME = 'CARTOES_MOVIMENTO_PROCESSADOS'
           AND CONSTNAME = 'CK_CARTOES_PROC_STATUS'
    ) THEN
        EXECUTE IMMEDIATE '
            ALTER TABLE TMP.CARTOES_MOVIMENTO_PROCESSADOS
                ADD CONSTRAINT CK_CARTOES_PROC_STATUS
                CHECK (STATUS IN (0, 1, 2, 3, 4))';
    END IF;
END
@
COMMENT ON COLUMN TMP.CARTOES_MOVIMENTO_PROCESSADOS.STATUS IS
    '0=Com erro; 1=Processado (terminal atualizado); 2=Processado e não alterado; 3=Processado e não encontrado (mais de 5 dias); 4=Processado terminal diferente (não cadastrado em DBA.BIGSM_CADTERMINAL)'
