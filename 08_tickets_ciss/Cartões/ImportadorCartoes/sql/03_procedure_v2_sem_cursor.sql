-- Versao 2: fluxo sequencial, sem declaracao ou abertura de cursor.
-- A versao inicial permanece em 02_procedure.sql.
-- Executar em conexao dedicada: ha COMMIT a cada 1000 linhas avaliadas.
CREATE OR REPLACE PROCEDURE TMP.SP_PROCESSAR_CARTOES_MOVIMENTO ()
    LANGUAGE SQL
    MODIFIES SQL DATA
    COMMIT ON RETURN NO
BEGIN
    DECLARE V_LIMITE BIGINT DEFAULT 0;
    DECLARE V_ULTIMO BIGINT DEFAULT 0;
    DECLARE V_ID BIGINT;
    DECLARE V_LOTE INTEGER DEFAULT 0;

    DECLARE V_ESTABELECIMENTO VARCHAR(40);
    DECLARE V_CNPJ VARCHAR(14);
    DECLARE V_AUTORIZACAO VARCHAR(64);
    DECLARE V_NSU VARCHAR(64);
    DECLARE V_NSU_NUMERO DECIMAL(18, 0);
    DECLARE V_MAQUINA VARCHAR(64);
    DECLARE V_DATA DATE;

    DECLARE V_STATUS SMALLINT;
    DECLARE V_ENCONTRADOS INTEGER;
    DECLARE V_SEM_TERMINAL INTEGER;
    DECLARE V_ALTERADOS INTEGER;
    DECLARE V_SQLSTATE CHAR(5);
    DECLARE V_SQLCODE INTEGER;
    DECLARE V_MENSAGEM VARCHAR(32672);
    DECLARE SQLSTATE CHAR(5) DEFAULT '00000';
    DECLARE SQLCODE INTEGER DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- Limita a chamada aos registros existentes no inicio.
    SELECT COALESCE(MAX(ID), 0)
      INTO V_LIMITE
      FROM TMP.CARTOES_MOVIMENTO;

    PROCESSAMENTO: WHILE V_ULTIMO < V_LIMITE DO
        IF V_LOTE = 0 THEN
            LOCK TABLE TMP.CARTOES_MOVIMENTO_PROCESSADOS IN EXCLUSIVE MODE;
        END IF;

        -- Avanca por ID, inclusive quando a linha permanece pendente.
        SELECT MIN(ID)
          INTO V_ID
          FROM TMP.CARTOES_MOVIMENTO
         WHERE ID > V_ULTIMO
           AND ID <= V_LIMITE;

        IF V_ID IS NULL THEN
            LEAVE PROCESSAMENTO;
        END IF;

        SET V_ULTIMO = V_ID;
        SET V_STATUS = -1;
        SET V_ENCONTRADOS = 0;
        SET V_ALTERADOS = 0;

        -- RETAIN CURSORS e uma clausula do SAVEPOINT no DB2;
        -- esta procedure nao declara, abre ou percorre cursores.
        SAVEPOINT SP_CARTAO ON ROLLBACK RETAIN CURSORS;

        BEGIN
            DECLARE EXIT HANDLER FOR SQLEXCEPTION
            BEGIN
                GET DIAGNOSTICS EXCEPTION 1 V_MENSAGEM = MESSAGE_TEXT;
                SET (V_SQLSTATE, V_SQLCODE) = (SQLSTATE, SQLCODE);
                ROLLBACK TO SAVEPOINT SP_CARTAO;

                -- Qualquer alteracao desta linha foi desfeita antes do status 0.
                INSERT INTO TMP.CARTOES_MOVIMENTO_PROCESSADOS (
                    ID, ESTABELECIMENTO, CNPJ, AUTORIZACAO, NSU,
                    NUMERO_MAQUINA, DTMOVIMENTO, ARQUIVO_HASH, ABA, LINHA,
                    IMPORTADO_EM, STATUS, QTD_ENCONTRADOS, QTD_ALTERADOS,
                    SQLSTATE_ERRO, SQLCODE_ERRO, MENSAGEM_ERRO
                )
                SELECT ID, ESTABELECIMENTO, CNPJ, AUTORIZACAO, NSU,
                       NUMERO_MAQUINA, DTMOVIMENTO, ARQUIVO_HASH, ABA, LINHA,
                       IMPORTADO_EM, 0, V_ENCONTRADOS, 0,
                       V_SQLSTATE, V_SQLCODE, SUBSTR(RTRIM(V_MENSAGEM), 1, 2048)
                  FROM TMP.CARTOES_MOVIMENTO
                 WHERE ID = V_ID;

                DELETE FROM TMP.CARTOES_MOVIMENTO
                 WHERE ID = V_ID;
            END;

            SELECT ESTABELECIMENTO, CNPJ, AUTORIZACAO, NSU,
                   NUMERO_MAQUINA, DTMOVIMENTO
              INTO V_ESTABELECIMENTO, V_CNPJ, V_AUTORIZACAO, V_NSU,
                   V_MAQUINA, V_DATA
              FROM TMP.CARTOES_MOVIMENTO
             WHERE ID = V_ID
              WITH RS;

            IF V_DATA IS NULL THEN
                SIGNAL SQLSTATE '75001'
                    SET MESSAGE_TEXT = 'DTMOVIMENTO ausente. Recuperar data da planilha original.';
            END IF;

            IF NOT REGEXP_LIKE(TRIM(V_NSU), '^[0-9]{1,18}$') THEN
                SIGNAL SQLSTATE '75002'
                    SET MESSAGE_TEXT = 'NSU invalido para IDNSUHOST DECIMAL(18,0).';
            END IF;

            SET V_NSU_NUMERO = DECIMAL(TRIM(V_NSU), 18, 0);

            SELECT COUNT(*),
                   COALESCE(SUM(CASE
                       WHEN CODTERMINAL = 'Nao identificado'
                         OR CODTERMINAL IS NULL
                         OR TRIM(CODTERMINAL) = '' THEN 1
                       ELSE 0
                   END), 0)
              INTO V_ENCONTRADOS, V_SEM_TERMINAL
              FROM DBA.CLW_RETORNO_CONTAS_RECEBER
             WHERE IDAUTORIZACAO = V_AUTORIZACAO
               AND IDNSUHOST = V_NSU_NUMERO
               AND CODESTABELECIMENTO = V_ESTABELECIMENTO
               AND CNPJ = V_CNPJ
              WITH RS;

            IF V_ENCONTRADOS > 0 THEN
                SET V_STATUS = 2;

                IF V_SEM_TERMINAL > 0 THEN
                    IF LENGTH(TRIM(V_MAQUINA)) = 0 OR LENGTH(V_MAQUINA) > 40 THEN
                        SIGNAL SQLSTATE '75003'
                            SET MESSAGE_TEXT = 'NUMERO_MAQUINA vazio ou maior que CODTERMINAL (40 caracteres).';
                    END IF;

                    UPDATE DBA.CLW_RETORNO_CONTAS_RECEBER
                       SET CODTERMINAL = V_MAQUINA
                     WHERE IDAUTORIZACAO = V_AUTORIZACAO
                       AND IDNSUHOST = V_NSU_NUMERO
                       AND CODESTABELECIMENTO = V_ESTABELECIMENTO
                       AND CNPJ = V_CNPJ
                       AND (
                           CODTERMINAL = 'Nao identificado'
                           OR CODTERMINAL IS NULL
                           OR TRIM(CODTERMINAL) = ''
                       );

                    GET DIAGNOSTICS V_ALTERADOS = ROW_COUNT;

                    IF V_ALTERADOS > 0 THEN
                        SET V_STATUS = 1;
                    END IF;
                END IF;

            ELSEIF V_DATA < CURRENT DATE - 5 DAYS THEN
                SET V_STATUS = 3;
            END IF;

            -- Status -1 permanece na origem para uma proxima chamada.
            IF V_STATUS >= 0 THEN
                INSERT INTO TMP.CARTOES_MOVIMENTO_PROCESSADOS (
                    ID, ESTABELECIMENTO, CNPJ, AUTORIZACAO, NSU,
                    NUMERO_MAQUINA, DTMOVIMENTO, ARQUIVO_HASH, ABA, LINHA,
                    IMPORTADO_EM, STATUS, QTD_ENCONTRADOS, QTD_ALTERADOS
                )
                SELECT ID, ESTABELECIMENTO, CNPJ, AUTORIZACAO, NSU,
                       NUMERO_MAQUINA, DTMOVIMENTO, ARQUIVO_HASH, ABA, LINHA,
                       IMPORTADO_EM, V_STATUS, V_ENCONTRADOS, V_ALTERADOS
                  FROM TMP.CARTOES_MOVIMENTO
                 WHERE ID = V_ID;

                DELETE FROM TMP.CARTOES_MOVIMENTO
                 WHERE ID = V_ID;
            END IF;
        END;

        RELEASE SAVEPOINT SP_CARTAO;
        SET V_LOTE = V_LOTE + 1;

        IF V_LOTE = 1000 THEN
            COMMIT;
            SET V_LOTE = 0;
        END IF;
    END WHILE PROCESSAMENTO;

    -- Confirma o ultimo lote parcial e libera eventual lock sem linhas.
    COMMIT;
END
