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
    DECLARE SQLSTATE CHAR(5) DEFAULT '00000';
    DECLARE SQLCODE INTEGER DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS EXCEPTION 1 V_FATAL_TEXTO = MESSAGE_TEXT;
        SET V_FATAL_ESTADO = SQLSTATE;
        ROLLBACK;
        SET CURRENT LOCK TIMEOUT = V_TIMEOUT;
        IF V_DONO = 1 THEN
            UPDATE TMP.CARTOES_PROCESSAMENTO_CONTROLE
               SET EM_EXECUCAO = 'N', RESULTADO = 'ERRO',
                   ATUALIZADO_EM = CURRENT TIMESTAMP, FINALIZADO_EM = CURRENT TIMESTAMP,
                   MENSAGEM = SUBSTR(V_FATAL_ESTADO || ': ' || V_FATAL_TEXTO, 1, 2048)
             WHERE ROTINA = 'SP_PROCESSAR_CARTOES_MOVIMENTO' AND EXECUCAO_TOKEN = V_TOKEN;
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
        DECLARE EXIT HANDLER FOR SQLSTATE '40001', SQLSTATE '57033'
        BEGIN
            ROLLBACK;
            SET V_DONO = 0;
        END;

        IF NOT EXISTS (SELECT 1 FROM TMP.CARTOES_PROCESSAMENTO_CONTROLE
            WHERE ROTINA = 'SP_PROCESSAR_CARTOES_MOVIMENTO' WITH UR) THEN
            SIGNAL SQLSTATE '75005' SET MESSAGE_TEXT = 'Checkpoint ausente; aplicar migracao 11.';
        END IF;

        UPDATE TMP.CARTOES_PROCESSAMENTO_CONTROLE AS C
           SET EM_EXECUCAO = 'S', EXECUCAO_TOKEN = V_TOKEN,
               APPLICATION_HANDLE = SYSPROC.MON_GET_APPLICATION_HANDLE(),
               APPLICATION_ID = SYSPROC.MON_GET_APPLICATION_ID(),
               INICIADO_EM = CURRENT TIMESTAMP, ATUALIZADO_EM = CURRENT TIMESTAMP,
               FINALIZADO_EM = NULL, ULTIMO_ID = NULL, QTD_AVALIADOS = 0,
               RESULTADO = 'EXECUTANDO', MENSAGEM = NULL
         WHERE ROTINA = 'SP_PROCESSAR_CARTOES_MOVIMENTO'
           AND (EM_EXECUCAO = 'N' OR NOT EXISTS (
               SELECT 1 FROM TABLE(SYSPROC.MON_GET_CONNECTION(NULL, -2)) AS S
                WHERE S.APPLICATION_HANDLE = C.APPLICATION_HANDLE
                  AND S.APPLICATION_ID = C.APPLICATION_ID
           ));
        GET DIAGNOSTICS V_DONO = ROW_COUNT;
    END;
    SET CURRENT LOCK TIMEOUT = V_TIMEOUT;

    IF V_DONO = 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '01000' SET MESSAGE_TEXT = 'Rotina ja em execucao ou checkpoint ocupado; chamada ignorada.';
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
                    SIGNAL SQLSTATE '75001' SET MESSAGE_TEXT = 'DTMOVIMENTO ausente.';
                END IF;
                -- NSU nao participa da busca temporariamente; nao exigir conversao numerica.
                -- IF NOT REGEXP_LIKE(TRIM(MOVIMENTO.NSU), '^[0-9]{1,18}$') THEN
                --     SIGNAL SQLSTATE '75002' SET MESSAGE_TEXT = 'NSU invalido para DECIMAL(18,0).';
                -- END IF;
                IF MOVIMENTO.VALOR_BRUTO IS NULL THEN
                    SIGNAL SQLSTATE '75004' SET MESSAGE_TEXT = 'VALOR_BRUTO ausente; recuperar da planilha original.';
                END IF;

                SELECT COUNT(*), COUNT(CASE
                           WHEN CODTERMINAL = 'Nao identificado'
                             OR CODTERMINAL IS NULL OR TRIM(CODTERMINAL) = '' THEN 1
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
                    SIGNAL SQLSTATE '75003' SET MESSAGE_TEXT = 'NUMERO_MAQUINA vazio ou maior que 40 caracteres.';
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
                   AND (CODTERMINAL = 'Nao identificado' OR CODTERMINAL IS NULL OR TRIM(CODTERMINAL) = '');
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
             WHERE ROTINA = 'SP_PROCESSAR_CARTOES_MOVIMENTO' AND EXECUCAO_TOKEN = V_TOKEN;
            COMMIT;
            SET V_LOTE = 0;
        END IF;
    END FOR PROCESSAMENTO;

    -- 5. Confirmar o ultimo lote e liberar somente a reserva desta execucao.
    UPDATE TMP.CARTOES_PROCESSAMENTO_CONTROLE
       SET EM_EXECUCAO = 'N', RESULTADO = 'CONCLUIDO', ULTIMO_ID = V_ULTIMO,
           QTD_AVALIADOS = QTD_AVALIADOS + V_LOTE,
           ATUALIZADO_EM = CURRENT TIMESTAMP, FINALIZADO_EM = CURRENT TIMESTAMP,
           MENSAGEM = NULL
     WHERE ROTINA = 'SP_PROCESSAR_CARTOES_MOVIMENTO' AND EXECUCAO_TOKEN = V_TOKEN;
    COMMIT;
END
