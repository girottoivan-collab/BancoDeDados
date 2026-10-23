-- Uma linha por rotina. A migracao nao reinicializa uma execucao em andamento.
BEGIN
    IF NOT EXISTS (SELECT 1 FROM SYSCAT.TABLES WHERE TABSCHEMA = 'TMP'
        AND TABNAME = 'CARTOES_PROCESSAMENTO_CONTROLE') THEN
        EXECUTE IMMEDIATE '
            CREATE TABLE TMP.CARTOES_PROCESSAMENTO_CONTROLE (
                ROTINA VARCHAR(64) NOT NULL PRIMARY KEY,
                EM_EXECUCAO CHAR(1) NOT NULL DEFAULT ''N'' CHECK (EM_EXECUCAO IN (''S'', ''N'')),
                EXECUCAO_TOKEN CHAR(26),
                APPLICATION_HANDLE BIGINT,
                APPLICATION_ID VARCHAR(128),
                INICIADO_EM TIMESTAMP,
                ATUALIZADO_EM TIMESTAMP,
                FINALIZADO_EM TIMESTAMP,
                ULTIMO_ID BIGINT,
                QTD_AVALIADOS BIGINT NOT NULL DEFAULT 0,
                RESULTADO VARCHAR(20),
                MENSAGEM VARCHAR(2048)
            )';
    END IF;
END
@
MERGE INTO TMP.CARTOES_PROCESSAMENTO_CONTROLE AS C
USING (VALUES CAST('SP_PROCESSAR_CARTOES_MOVIMENTO' AS VARCHAR(64))) AS O(ROTINA)
   ON C.ROTINA = O.ROTINA
WHEN NOT MATCHED THEN INSERT (ROTINA) VALUES (O.ROTINA)
@
COMMENT ON TABLE TMP.CARTOES_PROCESSAMENTO_CONTROLE IS
    'Checkpoint e exclusao mutua da SP de cartoes; atualizado e confirmado por lote, sem bloquear a tabela de processados'
@
COMMENT ON COLUMN TMP.CARTOES_PROCESSAMENTO_CONTROLE.QTD_AVALIADOS IS
    'Linhas avaliadas e confirmadas na ultima execucao; inclui movimentos mantidos pendentes'
@
COMMENT ON COLUMN TMP.CARTOES_PROCESSAMENTO_CONTROLE.ULTIMO_ID IS
    'Ultimo ID avaliado e confirmado; informativo, nao e filtro de retomada dos pendentes'
@
COMMENT ON COLUMN TMP.CARTOES_PROCESSAMENTO_CONTROLE.EM_EXECUCAO IS
    'S=execucao reservada; N=livre. Reserva orfa e recuperada somente quando a sessao proprietaria nao existe mais'
