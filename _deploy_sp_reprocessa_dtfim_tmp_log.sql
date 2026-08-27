CONNECT TO NOP48 USER dba USING "a9d9p8.E10"
~

BEGIN
    DECLARE CONTINUE HANDLER FOR SQLSTATE '42710'
        BEGIN END;

    EXECUTE IMMEDIATE 'CREATE SCHEMA TMP';
END
~

BEGIN
    DECLARE CONTINUE HANDLER FOR SQLSTATE '42704'
        BEGIN END;

    EXECUTE IMMEDIATE 'DROP PROCEDURE DBA.SP_REPROCESSA_DTFIM_ESTSIN_TMP()';
END
~

BEGIN
    DECLARE CONTINUE HANDLER FOR SQLSTATE '42704'
        BEGIN END;

    EXECUTE IMMEDIATE 'DROP PROCEDURE DBA.SP_REPROCESSA_DTFIM_CONSAL_TMP()';
END
~

BEGIN
    DECLARE CONTINUE HANDLER FOR SQLSTATE '42704'
        BEGIN END;

    EXECUTE IMMEDIATE 'DROP PROCEDURE DBA.SP_REPROCESSA_DTFIM_MOVCUS_TMP()';
END
~

BEGIN
    DECLARE CONTINUE HANDLER FOR SQLSTATE '42704'
        BEGIN END;

    EXECUTE IMMEDIATE 'DROP PROCEDURE DBA.SP_REPROCESSA_DTFIM_PROCUS_TMP()';
END
~

BEGIN
    DECLARE CONTINUE HANDLER FOR SQLSTATE '42704'
        BEGIN END;

    EXECUTE IMMEDIATE 'DROP TABLE TMP.LOG_REPROCESSA_DTFIM';
END
~
COMMIT
~

BEGIN
    DECLARE CONTINUE HANDLER FOR SQLSTATE '42710'
        BEGIN END;

    EXECUTE IMMEDIATE '
        CREATE TABLE TMP.LOG_REPROCESSA_DTFIM (
            NM_PROCEDURE VARCHAR(128) NOT NULL,
            TIPO_ATUALIZACAO VARCHAR(40) NOT NULL,
            DT_INICIO_PROCESSO TIMESTAMP,
            DT_INICIO_CICLO TIMESTAMP,
            DT_FIM_CICLO TIMESTAMP,
            DURACAO_ULTIMO_CICLO_SEGUNDOS INTEGER,
            CICLOS_PROCESSADOS INTEGER NOT NULL DEFAULT 0,
            ROWS_UPDATED BIGINT NOT NULL DEFAULT 0,
            UPDATED_AT TIMESTAMP NOT NULL DEFAULT CURRENT TIMESTAMP,
            PRIMARY KEY (NM_PROCEDURE, TIPO_ATUALIZACAO)
        )';
END
~
COMMIT
~

BEGIN
    DECLARE CONTINUE HANDLER FOR SQLSTATE '42704'
        BEGIN END;

    EXECUTE IMMEDIATE 'DROP PROCEDURE DBA.SP_REPROCESSA_DTFIM_ESTSIN_TMP(BIGINT)';
END
~

BEGIN
    DECLARE CONTINUE HANDLER FOR SQLSTATE '42704'
        BEGIN END;

    EXECUTE IMMEDIATE 'DROP PROCEDURE DBA.SP_REPROCESSA_DTFIM_CONSAL_TMP(BIGINT)';
END
~

BEGIN
    DECLARE CONTINUE HANDLER FOR SQLSTATE '42704'
        BEGIN END;

    EXECUTE IMMEDIATE 'DROP PROCEDURE DBA.SP_REPROCESSA_DTFIM_MOVCUS_TMP(BIGINT)';
END
~

BEGIN
    DECLARE CONTINUE HANDLER FOR SQLSTATE '42704'
        BEGIN END;

    EXECUTE IMMEDIATE 'DROP PROCEDURE DBA.SP_REPROCESSA_DTFIM_PROCUS_TMP(BIGINT)';
END
~
COMMIT
~

CREATE OR REPLACE PROCEDURE DBA.SP_REPROCESSA_DTFIM_ESTSIN_TMP()
LANGUAGE SQL
BEGIN
    DECLARE li_rows_updated       BIGINT DEFAULT 0;
    DECLARE li_rows_ciclo         BIGINT DEFAULT 0;
    DECLARE li_ciclos_processados INTEGER DEFAULT 0;
    DECLARE li_idempresa          INTEGER;
    DECLARE li_idproduto          INTEGER;
    DECLARE li_idsubproduto       INTEGER;
    DECLARE li_idlocalestoque     INTEGER;
    DECLARE li_upd                INTEGER;
    DECLARE lt_inicio_processo    TIMESTAMP;
    DECLARE lt_inicio_ciclo       TIMESTAMP;

    DECLARE v_outer_done          SMALLINT DEFAULT 0;

    DECLARE c1 CURSOR WITH HOLD FOR
        SELECT
            e.idempresa,
            e.idproduto,
            e.idsubproduto,
            e.idlocalestoque
        FROM
            dba.estoque_sintetico e
        GROUP BY
            e.idempresa,
            e.idproduto,
            e.idsubproduto,
            e.idlocalestoque
        ORDER BY
            e.idempresa,
            e.idproduto,
            e.idsubproduto,
            e.idlocalestoque
        WITH RR;

    DECLARE CONTINUE HANDLER FOR NOT FOUND
        SET v_outer_done = 1;

    SET lt_inicio_processo = CURRENT TIMESTAMP;
    SET lt_inicio_ciclo = lt_inicio_processo;

    DELETE FROM TMP.LOG_REPROCESSA_DTFIM
    WHERE NM_PROCEDURE = 'SP_REPROCESSA_DTFIM_ESTSIN_TMP'
      AND TIPO_ATUALIZACAO = 'ESTOQUE_SINTETICO';

    INSERT INTO TMP.LOG_REPROCESSA_DTFIM (
        NM_PROCEDURE,
        TIPO_ATUALIZACAO,
        DT_INICIO_PROCESSO,
        DT_INICIO_CICLO,
        CICLOS_PROCESSADOS,
        ROWS_UPDATED
    )
    VALUES (
        'SP_REPROCESSA_DTFIM_ESTSIN_TMP',
        'ESTOQUE_SINTETICO',
        lt_inicio_processo,
        lt_inicio_ciclo,
        0,
        0
    );

    COMMIT WORK;

    OPEN c1;

    FETCH c1 INTO
        li_idempresa,
        li_idproduto,
        li_idsubproduto,
        li_idlocalestoque;

    WHILE v_outer_done = 0 DO

        BEGIN
            UPDATE
                dba.estoque_sintetico
            SET
                dtfim = COALESCE((
                    SELECT
                        MIN(e2.dtmovimento)
                    FROM
                        dba.estoque_sintetico e2
                    WHERE
                        e2.idempresa        = dba.estoque_sintetico.idempresa
                    AND e2.idproduto        = dba.estoque_sintetico.idproduto
                    AND e2.idsubproduto     = dba.estoque_sintetico.idsubproduto
                    AND e2.idlocalestoque   = dba.estoque_sintetico.idlocalestoque
                    AND e2.dtmovimento      > dba.estoque_sintetico.dtmovimento
                ),DATE(DBA.UF_MAX_DTFIM()))
            WHERE
                idempresa      = li_idempresa
            AND idproduto      = li_idproduto
            AND idsubproduto   = li_idsubproduto
            AND idlocalestoque = li_idlocalestoque;

            GET DIAGNOSTICS li_upd = ROW_COUNT;

            SET li_rows_updated = li_rows_updated + li_upd;
            SET li_rows_ciclo = li_rows_ciclo + li_upd;

            IF li_rows_ciclo >= 10000 THEN
                SET li_ciclos_processados = li_ciclos_processados + 1;

                UPDATE TMP.LOG_REPROCESSA_DTFIM
                SET
                    DT_INICIO_CICLO = lt_inicio_ciclo,
                    DT_FIM_CICLO = CURRENT TIMESTAMP,
                    DURACAO_ULTIMO_CICLO_SEGUNDOS = TIMESTAMPDIFF(2, CHAR(CURRENT TIMESTAMP - lt_inicio_ciclo)),
                    CICLOS_PROCESSADOS = li_ciclos_processados,
                    ROWS_UPDATED = li_rows_updated,
                    UPDATED_AT = CURRENT TIMESTAMP
                WHERE NM_PROCEDURE = 'SP_REPROCESSA_DTFIM_ESTSIN_TMP'
                  AND TIPO_ATUALIZACAO = 'ESTOQUE_SINTETICO';

                COMMIT WORK;

                SET li_rows_ciclo = 0;
                SET lt_inicio_ciclo = CURRENT TIMESTAMP;
            END IF;
        END;

        FETCH c1 INTO
            li_idempresa,
            li_idproduto,
            li_idsubproduto,
            li_idlocalestoque;

    END WHILE;

    IF li_rows_ciclo > 0 THEN
        SET li_ciclos_processados = li_ciclos_processados + 1;
    END IF;

    UPDATE TMP.LOG_REPROCESSA_DTFIM
    SET
        DT_INICIO_CICLO = lt_inicio_ciclo,
        DT_FIM_CICLO = CURRENT TIMESTAMP,
        DURACAO_ULTIMO_CICLO_SEGUNDOS = TIMESTAMPDIFF(2, CHAR(CURRENT TIMESTAMP - lt_inicio_ciclo)),
        CICLOS_PROCESSADOS = li_ciclos_processados,
        ROWS_UPDATED = li_rows_updated,
        UPDATED_AT = CURRENT TIMESTAMP
    WHERE NM_PROCEDURE = 'SP_REPROCESSA_DTFIM_ESTSIN_TMP'
      AND TIPO_ATUALIZACAO = 'ESTOQUE_SINTETICO';

    COMMIT WORK;

    CLOSE c1 WITH RELEASE;

END
~
COMMIT
~

CREATE OR REPLACE PROCEDURE DBA.SP_REPROCESSA_DTFIM_CONSAL_TMP()
LANGUAGE SQL
BEGIN
    DECLARE li_rows_updated       BIGINT DEFAULT 0;
    DECLARE li_rows_ciclo         BIGINT DEFAULT 0;
    DECLARE li_ciclos_processados INTEGER DEFAULT 0;
    DECLARE li_idempresa          INTEGER;
    DECLARE li_idctacontabil      INTEGER;
    DECLARE li_upd                INTEGER;
    DECLARE lt_inicio_processo    TIMESTAMP;
    DECLARE lt_inicio_ciclo       TIMESTAMP;

    DECLARE v_outer_done          SMALLINT DEFAULT 0;

    DECLARE c1 CURSOR WITH HOLD FOR
        SELECT
            e.idempresa,
            e.idctacontabil
        FROM
            dba.contabil_saldo e
        GROUP BY
            e.idempresa,
            e.idctacontabil
        ORDER BY
            e.idempresa,
            e.idctacontabil
        WITH RR;

    DECLARE CONTINUE HANDLER FOR NOT FOUND
        SET v_outer_done = 1;

    SET lt_inicio_processo = CURRENT TIMESTAMP;
    SET lt_inicio_ciclo = lt_inicio_processo;

    DELETE FROM TMP.LOG_REPROCESSA_DTFIM
    WHERE NM_PROCEDURE = 'SP_REPROCESSA_DTFIM_CONSAL_TMP'
      AND TIPO_ATUALIZACAO = 'CONTABIL_SALDO';

    INSERT INTO TMP.LOG_REPROCESSA_DTFIM (
        NM_PROCEDURE,
        TIPO_ATUALIZACAO,
        DT_INICIO_PROCESSO,
        DT_INICIO_CICLO,
        CICLOS_PROCESSADOS,
        ROWS_UPDATED
    )
    VALUES (
        'SP_REPROCESSA_DTFIM_CONSAL_TMP',
        'CONTABIL_SALDO',
        lt_inicio_processo,
        lt_inicio_ciclo,
        0,
        0
    );

    COMMIT WORK;

    OPEN c1;

    FETCH c1 INTO
        li_idempresa,
        li_idctacontabil;

    WHILE v_outer_done = 0 DO

        BEGIN
            UPDATE
                dba.contabil_saldo
            SET
                dtfim = COALESCE((
                    SELECT
                        MIN(c2.dtmovimento)
                    FROM
                        dba.contabil_saldo c2
                    WHERE
                        c2.idempresa    = dba.contabil_saldo.idempresa
                    AND c2.idctacontabil= dba.contabil_saldo.idctacontabil
                    AND c2.dtmovimento  > dba.contabil_saldo.dtmovimento
                ),DATE(DBA.UF_MAX_DTFIM()))
            WHERE
                idempresa       = li_idempresa
            AND idctacontabil   = li_idctacontabil;

            GET DIAGNOSTICS li_upd = ROW_COUNT;

            SET li_rows_updated = li_rows_updated + li_upd;
            SET li_rows_ciclo = li_rows_ciclo + li_upd;

            IF li_rows_ciclo >= 10000 THEN
                SET li_ciclos_processados = li_ciclos_processados + 1;

                UPDATE TMP.LOG_REPROCESSA_DTFIM
                SET
                    DT_INICIO_CICLO = lt_inicio_ciclo,
                    DT_FIM_CICLO = CURRENT TIMESTAMP,
                    DURACAO_ULTIMO_CICLO_SEGUNDOS = TIMESTAMPDIFF(2, CHAR(CURRENT TIMESTAMP - lt_inicio_ciclo)),
                    CICLOS_PROCESSADOS = li_ciclos_processados,
                    ROWS_UPDATED = li_rows_updated,
                    UPDATED_AT = CURRENT TIMESTAMP
                WHERE NM_PROCEDURE = 'SP_REPROCESSA_DTFIM_CONSAL_TMP'
                  AND TIPO_ATUALIZACAO = 'CONTABIL_SALDO';

                COMMIT WORK;

                SET li_rows_ciclo = 0;
                SET lt_inicio_ciclo = CURRENT TIMESTAMP;
            END IF;
        END;

        FETCH c1 INTO
            li_idempresa,
            li_idctacontabil;

    END WHILE;

    IF li_rows_ciclo > 0 THEN
        SET li_ciclos_processados = li_ciclos_processados + 1;
    END IF;

    UPDATE TMP.LOG_REPROCESSA_DTFIM
    SET
        DT_INICIO_CICLO = lt_inicio_ciclo,
        DT_FIM_CICLO = CURRENT TIMESTAMP,
        DURACAO_ULTIMO_CICLO_SEGUNDOS = TIMESTAMPDIFF(2, CHAR(CURRENT TIMESTAMP - lt_inicio_ciclo)),
        CICLOS_PROCESSADOS = li_ciclos_processados,
        ROWS_UPDATED = li_rows_updated,
        UPDATED_AT = CURRENT TIMESTAMP
    WHERE NM_PROCEDURE = 'SP_REPROCESSA_DTFIM_CONSAL_TMP'
      AND TIPO_ATUALIZACAO = 'CONTABIL_SALDO';

    COMMIT WORK;

    CLOSE c1 WITH RELEASE;

END
~
COMMIT
~

CREATE OR REPLACE PROCEDURE DBA.SP_REPROCESSA_DTFIM_MOVCUS_TMP()
LANGUAGE SQL
BEGIN
    DECLARE li_rows_updated       BIGINT DEFAULT 0;
    DECLARE li_rows_ciclo         BIGINT DEFAULT 0;
    DECLARE li_ciclos_processados INTEGER DEFAULT 0;
    DECLARE li_idempresa          INTEGER;
    DECLARE li_idproduto          INTEGER;
    DECLARE li_idsubproduto       INTEGER;
    DECLARE li_upd                INTEGER;
    DECLARE lt_inicio_processo    TIMESTAMP;
    DECLARE lt_inicio_ciclo       TIMESTAMP;

    DECLARE v_outer_done          SMALLINT DEFAULT 0;

    DECLARE c1 CURSOR WITH HOLD FOR
        SELECT
            e.idempresa,
            e.idproduto,
            e.idsubproduto
        FROM
            dba.movimento_custo e
        GROUP BY
            e.idempresa,
            e.idproduto,
            e.idsubproduto
        ORDER BY
            e.idempresa,
            e.idproduto,
            e.idsubproduto
        WITH RR;

    DECLARE CONTINUE HANDLER FOR NOT FOUND
        SET v_outer_done = 1;

    SET lt_inicio_processo = CURRENT TIMESTAMP;
    SET lt_inicio_ciclo = lt_inicio_processo;

    DELETE FROM TMP.LOG_REPROCESSA_DTFIM
    WHERE NM_PROCEDURE = 'SP_REPROCESSA_DTFIM_MOVCUS_TMP'
      AND TIPO_ATUALIZACAO = 'MOVIMENTO_CUSTO';

    INSERT INTO TMP.LOG_REPROCESSA_DTFIM (
        NM_PROCEDURE,
        TIPO_ATUALIZACAO,
        DT_INICIO_PROCESSO,
        DT_INICIO_CICLO,
        CICLOS_PROCESSADOS,
        ROWS_UPDATED
    )
    VALUES (
        'SP_REPROCESSA_DTFIM_MOVCUS_TMP',
        'MOVIMENTO_CUSTO',
        lt_inicio_processo,
        lt_inicio_ciclo,
        0,
        0
    );

    COMMIT WORK;

    OPEN c1;

    FETCH c1 INTO
        li_idempresa,
        li_idproduto,
        li_idsubproduto;

    WHILE v_outer_done = 0 DO

        BEGIN
            UPDATE
                dba.movimento_custo
            SET
                DTFIM = COALESCE((
                    SELECT
                        MIN(DTMOVIMENTO)
                    FROM
                        dba.movimento_custo M2
                    WHERE
                        M2.IDEMPRESA    = dba.movimento_custo.IDEMPRESA
                    AND M2.IDPRODUTO    = dba.movimento_custo.IDPRODUTO
                    AND M2.IDSUBPRODUTO = dba.movimento_custo.IDSUBPRODUTO
                    AND M2.DTMOVIMENTO  > dba.movimento_custo.DTMOVIMENTO
                ),DBA.UF_MAX_DTFIM())
            WHERE
                idempresa   = li_idempresa
            AND idproduto   = li_idproduto
            AND idsubproduto= li_idsubproduto;

            GET DIAGNOSTICS li_upd = ROW_COUNT;

            SET li_rows_updated = li_rows_updated + li_upd;
            SET li_rows_ciclo = li_rows_ciclo + li_upd;

            IF li_rows_ciclo >= 10000 THEN
                SET li_ciclos_processados = li_ciclos_processados + 1;

                UPDATE TMP.LOG_REPROCESSA_DTFIM
                SET
                    DT_INICIO_CICLO = lt_inicio_ciclo,
                    DT_FIM_CICLO = CURRENT TIMESTAMP,
                    DURACAO_ULTIMO_CICLO_SEGUNDOS = TIMESTAMPDIFF(2, CHAR(CURRENT TIMESTAMP - lt_inicio_ciclo)),
                    CICLOS_PROCESSADOS = li_ciclos_processados,
                    ROWS_UPDATED = li_rows_updated,
                    UPDATED_AT = CURRENT TIMESTAMP
                WHERE NM_PROCEDURE = 'SP_REPROCESSA_DTFIM_MOVCUS_TMP'
                  AND TIPO_ATUALIZACAO = 'MOVIMENTO_CUSTO';

                COMMIT WORK;

                SET li_rows_ciclo = 0;
                SET lt_inicio_ciclo = CURRENT TIMESTAMP;
            END IF;
        END;

        FETCH c1 INTO
            li_idempresa,
            li_idproduto,
            li_idsubproduto;

    END WHILE;

    IF li_rows_ciclo > 0 THEN
        SET li_ciclos_processados = li_ciclos_processados + 1;
    END IF;

    UPDATE TMP.LOG_REPROCESSA_DTFIM
    SET
        DT_INICIO_CICLO = lt_inicio_ciclo,
        DT_FIM_CICLO = CURRENT TIMESTAMP,
        DURACAO_ULTIMO_CICLO_SEGUNDOS = TIMESTAMPDIFF(2, CHAR(CURRENT TIMESTAMP - lt_inicio_ciclo)),
        CICLOS_PROCESSADOS = li_ciclos_processados,
        ROWS_UPDATED = li_rows_updated,
        UPDATED_AT = CURRENT TIMESTAMP
    WHERE NM_PROCEDURE = 'SP_REPROCESSA_DTFIM_MOVCUS_TMP'
      AND TIPO_ATUALIZACAO = 'MOVIMENTO_CUSTO';

    COMMIT WORK;

    CLOSE c1 WITH RELEASE;

END
~
COMMIT
~

CREATE OR REPLACE PROCEDURE DBA.SP_REPROCESSA_DTFIM_PROCUS_TMP()
LANGUAGE SQL
BEGIN
    DECLARE li_rows_updated       BIGINT DEFAULT 0;
    DECLARE li_rows_ciclo         BIGINT DEFAULT 0;
    DECLARE li_ciclos_processados INTEGER DEFAULT 0;
    DECLARE li_idempresa          INTEGER;
    DECLARE li_idproduto          INTEGER;
    DECLARE li_idsubproduto       INTEGER;
    DECLARE li_upd                INTEGER;
    DECLARE lt_inicio_processo    TIMESTAMP;
    DECLARE lt_inicio_ciclo       TIMESTAMP;

    DECLARE v_outer_done          SMALLINT DEFAULT 0;

    DECLARE c1 CURSOR WITH HOLD FOR
        SELECT
            e.idempresa,
            e.idproduto,
            e.idsubproduto
        FROM
            dba.produto_custo e
        GROUP BY
            e.idempresa,
            e.idproduto,
            e.idsubproduto
        ORDER BY
            e.idempresa,
            e.idproduto,
            e.idsubproduto
        WITH RR;

    DECLARE CONTINUE HANDLER FOR NOT FOUND
        SET v_outer_done = 1;

    SET lt_inicio_processo = CURRENT TIMESTAMP;
    SET lt_inicio_ciclo = lt_inicio_processo;

    DELETE FROM TMP.LOG_REPROCESSA_DTFIM
    WHERE NM_PROCEDURE = 'SP_REPROCESSA_DTFIM_PROCUS_TMP'
      AND TIPO_ATUALIZACAO = 'PRODUTO_CUSTO';

    INSERT INTO TMP.LOG_REPROCESSA_DTFIM (
        NM_PROCEDURE,
        TIPO_ATUALIZACAO,
        DT_INICIO_PROCESSO,
        DT_INICIO_CICLO,
        CICLOS_PROCESSADOS,
        ROWS_UPDATED
    )
    VALUES (
        'SP_REPROCESSA_DTFIM_PROCUS_TMP',
        'PRODUTO_CUSTO',
        lt_inicio_processo,
        lt_inicio_ciclo,
        0,
        0
    );

    COMMIT WORK;

    OPEN c1;

    FETCH c1 INTO
        li_idempresa,
        li_idproduto,
        li_idsubproduto;

    WHILE v_outer_done = 0 DO

        BEGIN
            UPDATE
                dba.produto_custo
            SET
                DTFIM = COALESCE((
                    SELECT
                        MIN(DTMOVIMENTO)
                    FROM
                        dba.produto_custo M2
                    WHERE
                        M2.IDEMPRESA    = dba.produto_custo.IDEMPRESA
                    AND M2.IDPRODUTO    = dba.produto_custo.IDPRODUTO
                    AND M2.IDSUBPRODUTO = dba.produto_custo.IDSUBPRODUTO
                    AND M2.DTMOVIMENTO  > dba.produto_custo.DTMOVIMENTO
                ),DBA.UF_MAX_DTFIM())
            WHERE
                idempresa   = li_idempresa
            AND idproduto   = li_idproduto
            AND idsubproduto= li_idsubproduto;

            GET DIAGNOSTICS li_upd = ROW_COUNT;

            SET li_rows_updated = li_rows_updated + li_upd;
            SET li_rows_ciclo = li_rows_ciclo + li_upd;

            IF li_rows_ciclo >= 10000 THEN
                SET li_ciclos_processados = li_ciclos_processados + 1;

                UPDATE TMP.LOG_REPROCESSA_DTFIM
                SET
                    DT_INICIO_CICLO = lt_inicio_ciclo,
                    DT_FIM_CICLO = CURRENT TIMESTAMP,
                    DURACAO_ULTIMO_CICLO_SEGUNDOS = TIMESTAMPDIFF(2, CHAR(CURRENT TIMESTAMP - lt_inicio_ciclo)),
                    CICLOS_PROCESSADOS = li_ciclos_processados,
                    ROWS_UPDATED = li_rows_updated,
                    UPDATED_AT = CURRENT TIMESTAMP
                WHERE NM_PROCEDURE = 'SP_REPROCESSA_DTFIM_PROCUS_TMP'
                  AND TIPO_ATUALIZACAO = 'PRODUTO_CUSTO';

                COMMIT WORK;

                SET li_rows_ciclo = 0;
                SET lt_inicio_ciclo = CURRENT TIMESTAMP;
            END IF;
        END;

        FETCH c1 INTO
            li_idempresa,
            li_idproduto,
            li_idsubproduto;

    END WHILE;

    IF li_rows_ciclo > 0 THEN
        SET li_ciclos_processados = li_ciclos_processados + 1;
    END IF;

    UPDATE TMP.LOG_REPROCESSA_DTFIM
    SET
        DT_INICIO_CICLO = lt_inicio_ciclo,
        DT_FIM_CICLO = CURRENT TIMESTAMP,
        DURACAO_ULTIMO_CICLO_SEGUNDOS = TIMESTAMPDIFF(2, CHAR(CURRENT TIMESTAMP - lt_inicio_ciclo)),
        CICLOS_PROCESSADOS = li_ciclos_processados,
        ROWS_UPDATED = li_rows_updated,
        UPDATED_AT = CURRENT TIMESTAMP
    WHERE NM_PROCEDURE = 'SP_REPROCESSA_DTFIM_PROCUS_TMP'
      AND TIPO_ATUALIZACAO = 'PRODUTO_CUSTO';

    COMMIT WORK;

    CLOSE c1 WITH RELEASE;

END
~
COMMIT
~

SELECT
    ROUTINESCHEMA,
    ROUTINENAME,
    VALID
FROM
    SYSCAT.ROUTINES
WHERE
    ROUTINESCHEMA = 'DBA'
AND ROUTINENAME IN (
    'SP_REPROCESSA_DTFIM_ESTSIN_TMP',
    'SP_REPROCESSA_DTFIM_CONSAL_TMP',
    'SP_REPROCESSA_DTFIM_MOVCUS_TMP',
    'SP_REPROCESSA_DTFIM_PROCUS_TMP'
)
ORDER BY
    ROUTINENAME
~

CONNECT RESET
~
