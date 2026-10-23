-- Importador de Cartoes - objetos de banco versionados - release 1.3.2
-- Conteudo: tabelas, indices, migracoes, comentarios e SP V7 (commit de 100).
-- Implantacao MANUAL pela equipe de banco; o executavel nao executa DDL.
-- Requisitos: schemas TMP/DBA existentes e DBA.CLW_RETORNO_CONTAS_RECEBER implantada.
-- Suspender o agendamento da SP/importacao e usar conexao dedicada sem trabalho pendente.
-- Separador: @. Executar este bloco completo, uma unica vez por implantacao.
-- O bloco e repetivel, preserva dados/cadastro/checkpoint e nao chama a SP.
-- Timeout zero evita ficar em fila por locks durante a implantacao.
-- Falhas desfazem a implantacao e restauram o timeout anterior.
-- #SET TERMINATOR @
BEGIN
    DECLARE V_TIMEOUT INTEGER;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET CURRENT LOCK TIMEOUT = V_TIMEOUT;
        RESIGNAL;
    END;

    SET V_TIMEOUT = CURRENT LOCK TIMEOUT;
    SET CURRENT LOCK TIMEOUT = 0;
    IF NOT EXISTS (SELECT 1 FROM SYSCAT.SCHEMATA WHERE SCHEMANAME = 'TMP') THEN
        SIGNAL SQLSTATE '75010' SET MESSAGE_TEXT = 'Schema TMP ausente; preparar o ambiente antes da implantacao.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM SYSCAT.TABLES WHERE TABSCHEMA = 'DBA' AND TABNAME = 'CLW_RETORNO_CONTAS_RECEBER') THEN
        SIGNAL SQLSTATE '75011' SET MESSAGE_TEXT = 'Tabela DBA.CLW_RETORNO_CONTAS_RECEBER ausente.';
    END IF;
    IF EXISTS (
        SELECT 1 FROM TABLE(SYSPROC.MON_GET_ACTIVITY(NULL, -2)) AS A
         WHERE APPLICATION_HANDLE <> SYSPROC.MON_GET_APPLICATION_HANDLE()
           AND UPPER(STMT_TEXT) LIKE '%SP_PROCESSAR_CARTOES_MOVIMENTO%'
    ) THEN
        SIGNAL SQLSTATE '75012' SET MESSAGE_TEXT = 'SP de cartoes em atividade; aguardar termino antes da implantacao.';
    END IF;
    IF EXISTS (SELECT 1 FROM SYSCAT.TABLES WHERE TABSCHEMA = 'TMP' AND TABNAME = 'CARTOES_PROCESSAMENTO_CONTROLE') THEN
    EXECUTE IMMEDIATE '
        BEGIN
            IF EXISTS (
                SELECT 1 FROM TMP.CARTOES_PROCESSAMENTO_CONTROLE AS C
                WHERE C.ROTINA = ''SP_PROCESSAR_CARTOES_MOVIMENTO'' AND C.EM_EXECUCAO = ''S''
                  AND EXISTS (SELECT 1 FROM TABLE(SYSPROC.MON_GET_CONNECTION(NULL, -2)) AS S
                      WHERE S.APPLICATION_HANDLE = C.APPLICATION_HANDLE AND S.APPLICATION_ID = C.APPLICATION_ID)
                WITH UR
            ) THEN
                SIGNAL SQLSTATE ''75012'' SET MESSAGE_TEXT = ''Checkpoint com sessao ativa; nao implantar durante processamento.'';
            END IF;
        END';
    END IF;

    -- Tabelas e indices; nenhum dado existente e removido.
    IF NOT EXISTS (SELECT 1 FROM SYSCAT.TABLES WHERE TABSCHEMA = 'TMP' AND TABNAME = 'CARTOES_IMPORTACAO') THEN
    EXECUTE IMMEDIATE '
        CREATE TABLE TMP.CARTOES_IMPORTACAO (
         ARQUIVO_HASH CHAR(64) NOT NULL PRIMARY KEY,
         ARQUIVO_NOME VARCHAR(1024) NOT NULL,
         QUANTIDADE INTEGER NOT NULL,
         IMPORTADO_EM TIMESTAMP NOT NULL DEFAULT CURRENT TIMESTAMP
        )';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM SYSCAT.TABLES WHERE TABSCHEMA = 'TMP' AND TABNAME = 'CARTOES_MOVIMENTO') THEN
    EXECUTE IMMEDIATE '
        CREATE TABLE TMP.CARTOES_MOVIMENTO (
         ID BIGINT NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
         ESTABELECIMENTO VARCHAR(40) NOT NULL,
         CNPJ VARCHAR(14) NOT NULL,
         AUTORIZACAO VARCHAR(64) NOT NULL,
         NSU VARCHAR(64) NOT NULL,
         NUMERO_MAQUINA VARCHAR(64) NOT NULL,
         DTMOVIMENTO DATE,
         VALOR_BRUTO DECIMAL(15,2),
         ARQUIVO_HASH CHAR(64) NOT NULL,
         ABA VARCHAR(128) NOT NULL,
         LINHA INTEGER NOT NULL,
         IMPORTADO_EM TIMESTAMP NOT NULL DEFAULT CURRENT TIMESTAMP,
         CONSTRAINT FK_CARTOES_ARQUIVO FOREIGN KEY (ARQUIVO_HASH) REFERENCES TMP.CARTOES_IMPORTACAO (ARQUIVO_HASH),
         CONSTRAINT UK_CARTOES_ORIGEM UNIQUE (ARQUIVO_HASH, ABA, LINHA)
        )';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM SYSCAT.INDEXES WHERE INDSCHEMA = 'TMP' AND INDNAME = 'IX_CARTOES_NSU') THEN
    EXECUTE IMMEDIATE '
        CREATE INDEX TMP.IX_CARTOES_NSU ON TMP.CARTOES_MOVIMENTO (CNPJ, NSU)';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM SYSCAT.TABLES WHERE TABSCHEMA = 'TMP' AND TABNAME = 'CARTOES_MOVIMENTO_PROCESSADOS') THEN
    EXECUTE IMMEDIATE '
        CREATE TABLE TMP.CARTOES_MOVIMENTO_PROCESSADOS (
            ID BIGINT NOT NULL PRIMARY KEY,
            ESTABELECIMENTO VARCHAR(40) NOT NULL,
            CNPJ VARCHAR(14) NOT NULL,
            AUTORIZACAO VARCHAR(64) NOT NULL,
            NSU VARCHAR(64) NOT NULL,
            NUMERO_MAQUINA VARCHAR(64) NOT NULL,
            DTMOVIMENTO DATE,
            VALOR_BRUTO DECIMAL(15,2),
            ARQUIVO_HASH CHAR(64) NOT NULL,
            ABA VARCHAR(128) NOT NULL,
            LINHA INTEGER NOT NULL,
            IMPORTADO_EM TIMESTAMP NOT NULL,
            STATUS SMALLINT NOT NULL CHECK (STATUS IN (0,1,2,3,4)),
            QTD_ENCONTRADOS INTEGER NOT NULL DEFAULT 0,
            QTD_ALTERADOS INTEGER NOT NULL DEFAULT 0,
            SQLSTATE_ERRO CHAR(5),
            SQLCODE_ERRO INTEGER,
            MENSAGEM_ERRO VARCHAR(2048),
            PROCESSADO_EM TIMESTAMP NOT NULL DEFAULT CURRENT TIMESTAMP,
            CONSTRAINT FK_CARTOES_PROC_ARQUIVO FOREIGN KEY (ARQUIVO_HASH) REFERENCES TMP.CARTOES_IMPORTACAO (ARQUIVO_HASH),
            CONSTRAINT UK_CARTOES_PROC_ORIGEM UNIQUE (ARQUIVO_HASH, ABA, LINHA)
        )';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM SYSCAT.INDEXES WHERE INDSCHEMA = 'TMP' AND INDNAME = 'IX_CARTOES_PROC_STATUS') THEN
    EXECUTE IMMEDIATE '
        CREATE INDEX TMP.IX_CARTOES_PROC_STATUS ON TMP.CARTOES_MOVIMENTO_PROCESSADOS (STATUS, PROCESSADO_EM)';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM SYSCAT.COLUMNS WHERE TABSCHEMA = 'TMP'
        AND TABNAME = 'CARTOES_MOVIMENTO' AND COLNAME = 'DTMOVIMENTO') THEN
        EXECUTE IMMEDIATE 'ALTER TABLE TMP.CARTOES_MOVIMENTO ADD COLUMN DTMOVIMENTO DATE';
    END IF;

    -- Migracao incorporada: 04_migracao_status4.sql
    EXECUTE IMMEDIATE '
        -- Provisiona o cadastro sem preencher terminais automaticamente.
        BEGIN
            IF NOT EXISTS (
                SELECT 1
                  FROM SYSCAT.TABLES
                 WHERE TABSCHEMA = ''DBA''
                   AND TABNAME = ''BIGSM_CADTERMINAL''
            ) THEN
                EXECUTE IMMEDIATE ''
                    CREATE TABLE DBA.BIGSM_CADTERMINAL (
                        IDEMPRESA INTEGER,
                        CODTERMINAL VARCHAR(40)
                    )'';
            END IF;
        END';
    EXECUTE IMMEDIATE '
        -- Amplia a restricao anterior sem apagar nem reclassificar o historico.
        BEGIN
            DECLARE V_CONSTRAINT VARCHAR(128);

            SELECT MIN(CONSTNAME)
              INTO V_CONSTRAINT
              FROM SYSCAT.CHECKS
             WHERE TABSCHEMA = ''TMP''
               AND TABNAME = ''CARTOES_MOVIMENTO_PROCESSADOS''
               AND REPLACE(VARCHAR(TEXT, 32672), '' '', '''') = ''STATUSIN(0,1,2,3)'';

            IF V_CONSTRAINT IS NOT NULL THEN
                EXECUTE IMMEDIATE
                    ''ALTER TABLE TMP.CARTOES_MOVIMENTO_PROCESSADOS DROP CONSTRAINT "''
                    || REPLACE(V_CONSTRAINT, ''"'', ''""'') || ''"'';
            END IF;

            IF NOT EXISTS (
                SELECT 1
                  FROM SYSCAT.CHECKS
                 WHERE TABSCHEMA = ''TMP''
                   AND TABNAME = ''CARTOES_MOVIMENTO_PROCESSADOS''
                   AND CONSTNAME = ''CK_CARTOES_PROC_STATUS''
            ) THEN
                EXECUTE IMMEDIATE ''
                    ALTER TABLE TMP.CARTOES_MOVIMENTO_PROCESSADOS
                        ADD CONSTRAINT CK_CARTOES_PROC_STATUS
                        CHECK (STATUS IN (0, 1, 2, 3, 4))'';
            END IF;
        END';
    EXECUTE IMMEDIATE '
        COMMENT ON COLUMN TMP.CARTOES_MOVIMENTO_PROCESSADOS.STATUS IS
            ''0=Com erro; 1=Processado (terminal atualizado); 2=Processado e não alterado; 3=Processado e não encontrado (mais de 5 dias); 4=Processado terminal diferente (não cadastrado em DBA.BIGSM_CADTERMINAL)''';

    -- Migracao incorporada: 09_migracao_valor_bruto.sql
    EXECUTE IMMEDIATE '
        -- Mantem NULL no historico ate recuperar o valor da planilha original.
        -- Nao usar zero como valor padrao: isso poderia gerar correspondencias indevidas.
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM SYSCAT.COLUMNS WHERE TABSCHEMA = ''TMP''
                AND TABNAME = ''CARTOES_MOVIMENTO'' AND COLNAME = ''VALOR_BRUTO'') THEN
                EXECUTE IMMEDIATE ''ALTER TABLE TMP.CARTOES_MOVIMENTO ADD COLUMN VALOR_BRUTO DECIMAL(15,2)'';
            END IF;
            IF NOT EXISTS (SELECT 1 FROM SYSCAT.COLUMNS WHERE TABSCHEMA = ''TMP''
                AND TABNAME = ''CARTOES_MOVIMENTO_PROCESSADOS'' AND COLNAME = ''VALOR_BRUTO'') THEN
                EXECUTE IMMEDIATE ''ALTER TABLE TMP.CARTOES_MOVIMENTO_PROCESSADOS ADD COLUMN VALOR_BRUTO DECIMAL(15,2)'';
            END IF;
        END';
    EXECUTE IMMEDIATE '
        COMMENT ON COLUMN TMP.CARTOES_MOVIMENTO.VALOR_BRUTO IS
            ''Valor bruto da venda na planilha; comparado com CLW_RETORNO_CONTAS_RECEBER.VALBRUTOESPERADO''';
    EXECUTE IMMEDIATE '
        COMMENT ON COLUMN TMP.CARTOES_MOVIMENTO_PROCESSADOS.VALOR_BRUTO IS
            ''Valor bruto da venda preservado da importacao; NULL para historico ainda nao recuperado''';

    -- Migracao incorporada: 11_migracao_checkpoint.sql
    EXECUTE IMMEDIATE '
        -- Uma linha por rotina. A migracao nao reinicializa uma execucao em andamento.
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM SYSCAT.TABLES WHERE TABSCHEMA = ''TMP''
                AND TABNAME = ''CARTOES_PROCESSAMENTO_CONTROLE'') THEN
                EXECUTE IMMEDIATE ''
                    CREATE TABLE TMP.CARTOES_PROCESSAMENTO_CONTROLE (
                        ROTINA VARCHAR(64) NOT NULL PRIMARY KEY,
                        EM_EXECUCAO CHAR(1) NOT NULL DEFAULT ''''N'''' CHECK (EM_EXECUCAO IN (''''S'''', ''''N'''')),
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
                    )'';
            END IF;
        END';
    EXECUTE IMMEDIATE '
        MERGE INTO TMP.CARTOES_PROCESSAMENTO_CONTROLE AS C
        USING (VALUES CAST(''SP_PROCESSAR_CARTOES_MOVIMENTO'' AS VARCHAR(64))) AS O(ROTINA)
           ON C.ROTINA = O.ROTINA
        WHEN NOT MATCHED THEN INSERT (ROTINA) VALUES (O.ROTINA)';
    EXECUTE IMMEDIATE '
        COMMENT ON TABLE TMP.CARTOES_PROCESSAMENTO_CONTROLE IS
            ''Checkpoint e exclusao mutua da SP de cartoes; atualizado e confirmado por lote, sem bloquear a tabela de processados''';
    EXECUTE IMMEDIATE '
        COMMENT ON COLUMN TMP.CARTOES_PROCESSAMENTO_CONTROLE.QTD_AVALIADOS IS
            ''Linhas avaliadas e confirmadas na ultima execucao; inclui movimentos mantidos pendentes''';
    EXECUTE IMMEDIATE '
        COMMENT ON COLUMN TMP.CARTOES_PROCESSAMENTO_CONTROLE.ULTIMO_ID IS
            ''Ultimo ID avaliado e confirmado; informativo, nao e filtro de retomada dos pendentes''';
    EXECUTE IMMEDIATE '
        COMMENT ON COLUMN TMP.CARTOES_PROCESSAMENTO_CONTROLE.EM_EXECUCAO IS
            ''S=execucao reservada; N=livre. Reserva orfa e recuperada somente quando a sessao proprietaria nao existe mais''';
    EXECUTE IMMEDIATE '
        COMMENT ON COLUMN TMP.CARTOES_MOVIMENTO.DTMOVIMENTO IS ''Data da venda na planilha; NULL somente para legado sem data recuperada''';

    -- Definicao atual da SP; nao ha CALL de processamento neste arquivo.
    EXECUTE IMMEDIATE '
        -- V7: checkpoint exclusivo por sessao; chamadas simultaneas saem sem aguardar.
        -- Requer as migracoes 04, 09 e 11. Todas as versoes anteriores permanecem preservadas.
        -- Executar em conexao dedicada; a procedure confirma cada 100 linhas avaliadas.
        CREATE OR REPLACE PROCEDURE TMP.SP_PROCESSAR_CARTOES_MOVIMENTO ()
            LANGUAGE SQL
            MODIFIES SQL DATA
            COMMIT ON RETURN NO
        ROTINA: BEGIN
            DECLARE V_TIMEOUT INTEGER;
            DECLARE V_DONO INTEGER DEFAULT 0;
            DECLARE V_TOKEN CHAR(26);
            DECLARE V_ULTIMO BIGINT;
            DECLARE V_FATAL_TEXTO VARCHAR(32672);
            DECLARE V_FATAL_ESTADO CHAR(5);
            DECLARE V_LIMITE BIGINT;
            DECLARE V_LOTE INTEGER DEFAULT 0;
            DECLARE V_STATUS SMALLINT;
            DECLARE V_ENCONTRADOS INTEGER;
            DECLARE V_A_ATUALIZAR INTEGER;
            DECLARE V_ALTERADOS INTEGER;
            DECLARE V_ERRO_ESTADO CHAR(5);
            DECLARE V_ERRO_CODIGO INTEGER;
            DECLARE V_ERRO_TEXTO VARCHAR(32672);
            DECLARE SQLSTATE CHAR(5) DEFAULT ''00000'';
            DECLARE SQLCODE INTEGER DEFAULT 0;
            DECLARE EXIT HANDLER FOR SQLEXCEPTION
            BEGIN
                GET DIAGNOSTICS EXCEPTION 1 V_FATAL_TEXTO = MESSAGE_TEXT;
                SET V_FATAL_ESTADO = SQLSTATE;
                ROLLBACK;
                SET CURRENT LOCK TIMEOUT = V_TIMEOUT;
                IF V_DONO = 1 THEN
                    UPDATE TMP.CARTOES_PROCESSAMENTO_CONTROLE
                       SET EM_EXECUCAO = ''N'', RESULTADO = ''ERRO'',
                           ATUALIZADO_EM = CURRENT TIMESTAMP, FINALIZADO_EM = CURRENT TIMESTAMP,
                           MENSAGEM = SUBSTR(V_FATAL_ESTADO || '': '' || V_FATAL_TEXTO, 1, 2048)
                     WHERE ROTINA = ''SP_PROCESSAR_CARTOES_MOVIMENTO'' AND EXECUCAO_TOKEN = V_TOKEN;
                    COMMIT;
                END IF;
                RESIGNAL;
            END;

            -- 1. Reservar a rotina atomicamente. O timeout zero vale somente para esta etapa.
            SET V_TIMEOUT = CURRENT LOCK TIMEOUT;
            SET V_TOKEN = HEX(GENERATE_UNIQUE());
            SET CURRENT LOCK TIMEOUT = 0;
            BEGIN
                -- Uma disputa pela linha do controle nao deve colocar outra chamada na fila.
                DECLARE EXIT HANDLER FOR SQLSTATE ''40001'', SQLSTATE ''57033''
                BEGIN
                    ROLLBACK;
                    SET V_DONO = 0;
                END;

                IF NOT EXISTS (SELECT 1 FROM TMP.CARTOES_PROCESSAMENTO_CONTROLE
                    WHERE ROTINA = ''SP_PROCESSAR_CARTOES_MOVIMENTO'' WITH UR) THEN
                    SIGNAL SQLSTATE ''75005'' SET MESSAGE_TEXT = ''Checkpoint ausente; aplicar migracao 11.'';
                END IF;

                UPDATE TMP.CARTOES_PROCESSAMENTO_CONTROLE AS C
                   SET EM_EXECUCAO = ''S'', EXECUCAO_TOKEN = V_TOKEN,
                       APPLICATION_HANDLE = SYSPROC.MON_GET_APPLICATION_HANDLE(),
                       APPLICATION_ID = SYSPROC.MON_GET_APPLICATION_ID(),
                       INICIADO_EM = CURRENT TIMESTAMP, ATUALIZADO_EM = CURRENT TIMESTAMP,
                       FINALIZADO_EM = NULL, ULTIMO_ID = NULL, QTD_AVALIADOS = 0,
                       RESULTADO = ''EXECUTANDO'', MENSAGEM = NULL
                 WHERE ROTINA = ''SP_PROCESSAR_CARTOES_MOVIMENTO''
                   AND (EM_EXECUCAO = ''N'' OR NOT EXISTS (
                       SELECT 1 FROM TABLE(SYSPROC.MON_GET_CONNECTION(NULL, -2)) AS S
                        WHERE S.APPLICATION_HANDLE = C.APPLICATION_HANDLE
                          AND S.APPLICATION_ID = C.APPLICATION_ID
                   ));
                GET DIAGNOSTICS V_DONO = ROW_COUNT;
            END;
            SET CURRENT LOCK TIMEOUT = V_TIMEOUT;

            IF V_DONO = 0 THEN
                ROLLBACK;
                SIGNAL SQLSTATE ''01000'' SET MESSAGE_TEXT = ''Rotina ja em execucao ou checkpoint ocupado; chamada ignorada.'';
                LEAVE ROTINA;
            END IF;
            -- A reserva e persistente e sobrevive aos commits dos lotes, sem manter um lock aberto.
            COMMIT;

            SELECT COALESCE(MAX(ID), 0) INTO V_LIMITE FROM TMP.CARTOES_MOVIMENTO;

            -- O FOR controla a varredura automaticamente. WITH HOLD permite COMMIT no laco.
            -- INSENSITIVE fixa a lista de linhas mesmo removendo movimentos ja processados.
            PROCESSAMENTO: FOR MOVIMENTO AS C_MOVIMENTO INSENSITIVE CURSOR WITH HOLD FOR
                SELECT ID, ESTABELECIMENTO, CNPJ, AUTORIZACAO, NSU, NUMERO_MAQUINA, DTMOVIMENTO, VALOR_BRUTO
                  FROM TMP.CARTOES_MOVIMENTO
                 WHERE ID <= V_LIMITE
                 ORDER BY ID
                 FOR READ ONLY
            DO
                -- Ignora linhas eventualmente removidas externamente depois da selecao.
                IF NOT EXISTS (SELECT 1 FROM TMP.CARTOES_MOVIMENTO WHERE ID = MOVIMENTO.ID) THEN
                    ITERATE PROCESSAMENTO;
                END IF;
                SET V_ULTIMO = MOVIMENTO.ID;
                SET (V_STATUS, V_ENCONTRADOS, V_ALTERADOS) = (-1, 0, 0);

                -- A clausula RETAIN CURSORS pertence ao SAVEPOINT; nao declara um cursor.
                SAVEPOINT SP_CARTAO ON ROLLBACK RETAIN CURSORS;
                BEGIN
                    DECLARE EXIT HANDLER FOR SQLEXCEPTION
                    BEGIN
                        GET DIAGNOSTICS EXCEPTION 1 V_ERRO_TEXTO = MESSAGE_TEXT;
                        SET (V_ERRO_ESTADO, V_ERRO_CODIGO) = (SQLSTATE, SQLCODE);
                        ROLLBACK TO SAVEPOINT SP_CARTAO;
                        INSERT INTO TMP.CARTOES_MOVIMENTO_PROCESSADOS (
                            ID, ESTABELECIMENTO, CNPJ, AUTORIZACAO, NSU, NUMERO_MAQUINA,
                            DTMOVIMENTO, VALOR_BRUTO, ARQUIVO_HASH, ABA, LINHA, IMPORTADO_EM, STATUS,
                            QTD_ENCONTRADOS, QTD_ALTERADOS, SQLSTATE_ERRO, SQLCODE_ERRO, MENSAGEM_ERRO
                        )
                        SELECT ID, ESTABELECIMENTO, CNPJ, AUTORIZACAO, NSU, NUMERO_MAQUINA,
                               DTMOVIMENTO, VALOR_BRUTO, ARQUIVO_HASH, ABA, LINHA, IMPORTADO_EM, 0,
                               V_ENCONTRADOS, 0, V_ERRO_ESTADO, V_ERRO_CODIGO,
                               SUBSTR(RTRIM(V_ERRO_TEXTO), 1, 2048)
                          FROM TMP.CARTOES_MOVIMENTO WHERE ID = MOVIMENTO.ID;
                        DELETE FROM TMP.CARTOES_MOVIMENTO WHERE ID = MOVIMENTO.ID;
                    END;

                    -- 2. Validar e classificar. Saidas antecipadas evitam IFs aninhados.
                    VALIDACAO: BEGIN
                        IF NOT EXISTS (SELECT 1 FROM DBA.BIGSM_CADTERMINAL WHERE CODTERMINAL = MOVIMENTO.NUMERO_MAQUINA) THEN
                            SET V_STATUS = 4;
                            LEAVE VALIDACAO;
                        END IF;
                        IF MOVIMENTO.DTMOVIMENTO IS NULL THEN
                            SIGNAL SQLSTATE ''75001'' SET MESSAGE_TEXT = ''DTMOVIMENTO ausente.'';
                        END IF;
                        -- NSU nao participa da busca temporariamente; nao exigir conversao numerica.
                        -- IF NOT REGEXP_LIKE(TRIM(MOVIMENTO.NSU), ''^[0-9]{1,18}$'') THEN
                        --     SIGNAL SQLSTATE ''75002'' SET MESSAGE_TEXT = ''NSU invalido para DECIMAL(18,0).'';
                        -- END IF;
                        IF MOVIMENTO.VALOR_BRUTO IS NULL THEN
                            SIGNAL SQLSTATE ''75004'' SET MESSAGE_TEXT = ''VALOR_BRUTO ausente; recuperar da planilha original.'';
                        END IF;

                        SELECT COUNT(*), COUNT(CASE
                                   WHEN CODTERMINAL = ''Nao identificado''
                                     OR CODTERMINAL IS NULL OR TRIM(CODTERMINAL) = '''' THEN 1
                               END)
                          INTO V_ENCONTRADOS, V_A_ATUALIZAR
                          FROM DBA.CLW_RETORNO_CONTAS_RECEBER
                         WHERE IDAUTORIZACAO = MOVIMENTO.AUTORIZACAO
                           AND CNPJ = MOVIMENTO.CNPJ
                           AND VALBRUTOESPERADO = MOVIMENTO.VALOR_BRUTO
                           -- Comparacoes temporariamente desativadas por divergencias na origem:
                           -- AND IDNSUHOST = DECIMAL(MOVIMENTO.NSU, 18, 0)
                           -- AND CODESTABELECIMENTO = MOVIMENTO.ESTABELECIMENTO
                          WITH RS;

                        SET V_STATUS = CASE
                            WHEN V_ENCONTRADOS > 0 THEN 2
                            WHEN MOVIMENTO.DTMOVIMENTO < CURRENT DATE - 5 DAYS THEN 3
                            ELSE -1
                        END;
                        IF V_A_ATUALIZAR = 0 THEN LEAVE VALIDACAO; END IF;
                        IF LENGTH(TRIM(MOVIMENTO.NUMERO_MAQUINA)) = 0 OR LENGTH(MOVIMENTO.NUMERO_MAQUINA) > 40 THEN
                            SIGNAL SQLSTATE ''75003'' SET MESSAGE_TEXT = ''NUMERO_MAQUINA vazio ou maior que 40 caracteres.'';
                        END IF;

                        -- 3. Atualizar somente o literal exato, nulo ou vazio.
                        UPDATE DBA.CLW_RETORNO_CONTAS_RECEBER
                           SET CODTERMINAL = MOVIMENTO.NUMERO_MAQUINA
                         WHERE IDAUTORIZACAO = MOVIMENTO.AUTORIZACAO
                           AND CNPJ = MOVIMENTO.CNPJ
                           AND VALBRUTOESPERADO = MOVIMENTO.VALOR_BRUTO
                           -- Comparacoes temporariamente desativadas por divergencias na origem:
                           -- AND IDNSUHOST = DECIMAL(MOVIMENTO.NSU, 18, 0)
                           -- AND CODESTABELECIMENTO = MOVIMENTO.ESTABELECIMENTO
                           AND (CODTERMINAL = ''Nao identificado'' OR CODTERMINAL IS NULL OR TRIM(CODTERMINAL) = '''');
                        GET DIAGNOSTICS V_ALTERADOS = ROW_COUNT;
                        IF V_ALTERADOS > 0 THEN SET V_STATUS = 1; END IF;
                    END VALIDACAO;

                    -- 4. Arquivar e remover da origem. Status -1 aguarda outra chamada.
                    IF V_STATUS >= 0 THEN
                        INSERT INTO TMP.CARTOES_MOVIMENTO_PROCESSADOS (
                            ID, ESTABELECIMENTO, CNPJ, AUTORIZACAO, NSU, NUMERO_MAQUINA,
                            DTMOVIMENTO, VALOR_BRUTO, ARQUIVO_HASH, ABA, LINHA, IMPORTADO_EM, STATUS,
                            QTD_ENCONTRADOS, QTD_ALTERADOS
                        )
                        SELECT ID, ESTABELECIMENTO, CNPJ, AUTORIZACAO, NSU, NUMERO_MAQUINA,
                               DTMOVIMENTO, VALOR_BRUTO, ARQUIVO_HASH, ABA, LINHA, IMPORTADO_EM,
                               V_STATUS, V_ENCONTRADOS, V_ALTERADOS
                          FROM TMP.CARTOES_MOVIMENTO WHERE ID = MOVIMENTO.ID;
                        DELETE FROM TMP.CARTOES_MOVIMENTO WHERE ID = MOVIMENTO.ID;
                    END IF;
                END;
                RELEASE SAVEPOINT SP_CARTAO;

                SET V_LOTE = V_LOTE + 1;
                IF V_LOTE = 100 THEN
                    UPDATE TMP.CARTOES_PROCESSAMENTO_CONTROLE
                       SET ULTIMO_ID = V_ULTIMO, QTD_AVALIADOS = QTD_AVALIADOS + V_LOTE,
                           ATUALIZADO_EM = CURRENT TIMESTAMP
                     WHERE ROTINA = ''SP_PROCESSAR_CARTOES_MOVIMENTO'' AND EXECUCAO_TOKEN = V_TOKEN;
                    COMMIT;
                    SET V_LOTE = 0;
                END IF;
            END FOR PROCESSAMENTO;

            -- 5. Confirmar o ultimo lote e liberar somente a reserva desta execucao.
            UPDATE TMP.CARTOES_PROCESSAMENTO_CONTROLE
               SET EM_EXECUCAO = ''N'', RESULTADO = ''CONCLUIDO'', ULTIMO_ID = V_ULTIMO,
                   QTD_AVALIADOS = QTD_AVALIADOS + V_LOTE,
                   ATUALIZADO_EM = CURRENT TIMESTAMP, FINALIZADO_EM = CURRENT TIMESTAMP,
                   MENSAGEM = NULL
             WHERE ROTINA = ''SP_PROCESSAR_CARTOES_MOVIMENTO'' AND EXECUCAO_TOKEN = V_TOKEN;
            COMMIT;
        END';
    COMMIT;
    SET CURRENT LOCK TIMEOUT = V_TIMEOUT;
END
@
