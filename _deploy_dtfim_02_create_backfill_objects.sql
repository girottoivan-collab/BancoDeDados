CONNECT TO NOPONTO USER dba USING "a9d9p8.E10"
~

CREATE OR REPLACE FUNCTION DBA.UF_MAX_DTFIM()
RETURNS TIMESTAMP
LANGUAGE SQL
RETURN
    SELECT TIMESTAMP('2199-01-01 00:00:00.000000')
    FROM SYSIBM.SYSDUMMY1
~
COMMIT
~

CREATE OR REPLACE PROCEDURE DBA.SP_REPROCESSA_DTFIM_ESTSIN()
LANGUAGE SQL
BEGIN
    DECLARE li_rows_updated BIGINT DEFAULT 0;
    DECLARE li_rows_since_commit BIGINT DEFAULT 0;
    DECLARE li_idempresa INTEGER;
    DECLARE li_idproduto INTEGER;
    DECLARE li_idsubproduto INTEGER;
    DECLARE li_idlocalestoque INTEGER;
    DECLARE li_upd INTEGER;
    DECLARE v_done SMALLINT DEFAULT 0;

    DECLARE c1 CURSOR WITH HOLD FOR
        SELECT idempresa, idproduto, idsubproduto, idlocalestoque
        FROM dba.estoque_sintetico
        GROUP BY idempresa, idproduto, idsubproduto, idlocalestoque
        ORDER BY idempresa, idproduto, idsubproduto, idlocalestoque
        WITH RR;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

    OPEN c1;
    FETCH c1 INTO li_idempresa, li_idproduto, li_idsubproduto, li_idlocalestoque;

    WHILE v_done = 0 DO
        UPDATE dba.estoque_sintetico t
           SET dtfim = COALESCE((
                SELECT MIN(t2.dtmovimento)
                FROM dba.estoque_sintetico t2
                WHERE t2.idempresa = t.idempresa
                  AND t2.idproduto = t.idproduto
                  AND t2.idsubproduto = t.idsubproduto
                  AND t2.idlocalestoque = t.idlocalestoque
                  AND t2.dtmovimento > t.dtmovimento
           ), DATE(DBA.UF_MAX_DTFIM()))
         WHERE t.idempresa = li_idempresa
           AND t.idproduto = li_idproduto
           AND t.idsubproduto = li_idsubproduto
           AND t.idlocalestoque = li_idlocalestoque;

        GET DIAGNOSTICS li_upd = ROW_COUNT;
        SET li_rows_updated = li_rows_updated + li_upd;
        SET li_rows_since_commit = li_rows_since_commit + li_upd;

        IF li_rows_since_commit >= 10000 THEN
            COMMIT WORK;
            SET li_rows_since_commit = 0;
        END IF;

        FETCH c1 INTO li_idempresa, li_idproduto, li_idsubproduto, li_idlocalestoque;
    END WHILE;

    COMMIT WORK;
    CLOSE c1 WITH RELEASE;
END
~
COMMIT
~

CREATE OR REPLACE PROCEDURE DBA.SP_REPROCESSA_DTFIM_CONSAL()
LANGUAGE SQL
BEGIN
    DECLARE li_rows_updated BIGINT DEFAULT 0;
    DECLARE li_rows_since_commit BIGINT DEFAULT 0;
    DECLARE li_idempresa INTEGER;
    DECLARE li_idctacontabil INTEGER;
    DECLARE li_upd INTEGER;
    DECLARE v_done SMALLINT DEFAULT 0;

    DECLARE c1 CURSOR WITH HOLD FOR
        SELECT idempresa, idctacontabil
        FROM dba.contabil_saldo
        GROUP BY idempresa, idctacontabil
        ORDER BY idempresa, idctacontabil
        WITH RR;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

    OPEN c1;
    FETCH c1 INTO li_idempresa, li_idctacontabil;

    WHILE v_done = 0 DO
        UPDATE dba.contabil_saldo t
           SET dtfim = COALESCE((
                SELECT MIN(t2.dtmovimento)
                FROM dba.contabil_saldo t2
                WHERE t2.idempresa = t.idempresa
                  AND t2.idctacontabil = t.idctacontabil
                  AND t2.dtmovimento > t.dtmovimento
           ), DATE(DBA.UF_MAX_DTFIM()))
         WHERE t.idempresa = li_idempresa
           AND t.idctacontabil = li_idctacontabil;

        GET DIAGNOSTICS li_upd = ROW_COUNT;
        SET li_rows_updated = li_rows_updated + li_upd;
        SET li_rows_since_commit = li_rows_since_commit + li_upd;

        IF li_rows_since_commit >= 10000 THEN
            COMMIT WORK;
            SET li_rows_since_commit = 0;
        END IF;

        FETCH c1 INTO li_idempresa, li_idctacontabil;
    END WHILE;

    COMMIT WORK;
    CLOSE c1 WITH RELEASE;
END
~
COMMIT
~

CREATE OR REPLACE PROCEDURE DBA.SP_REPROCESSA_DTFIM_MOVCUS()
LANGUAGE SQL
BEGIN
    DECLARE li_rows_updated BIGINT DEFAULT 0;
    DECLARE li_rows_since_commit BIGINT DEFAULT 0;
    DECLARE li_idempresa INTEGER;
    DECLARE li_idproduto INTEGER;
    DECLARE li_idsubproduto INTEGER;
    DECLARE li_upd INTEGER;
    DECLARE v_done SMALLINT DEFAULT 0;

    DECLARE c1 CURSOR WITH HOLD FOR
        SELECT idempresa, idproduto, idsubproduto
        FROM dba.movimento_custo
        GROUP BY idempresa, idproduto, idsubproduto
        ORDER BY idempresa, idproduto, idsubproduto
        WITH RR;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

    OPEN c1;
    FETCH c1 INTO li_idempresa, li_idproduto, li_idsubproduto;

    WHILE v_done = 0 DO
        UPDATE dba.movimento_custo t
           SET dtfim = COALESCE((
                SELECT MIN(t2.dtmovimento)
                FROM dba.movimento_custo t2
                WHERE t2.idempresa = t.idempresa
                  AND t2.idproduto = t.idproduto
                  AND t2.idsubproduto = t.idsubproduto
                  AND t2.dtmovimento > t.dtmovimento
           ), DBA.UF_MAX_DTFIM())
         WHERE t.idempresa = li_idempresa
           AND t.idproduto = li_idproduto
           AND t.idsubproduto = li_idsubproduto;

        GET DIAGNOSTICS li_upd = ROW_COUNT;
        SET li_rows_updated = li_rows_updated + li_upd;
        SET li_rows_since_commit = li_rows_since_commit + li_upd;

        IF li_rows_since_commit >= 10000 THEN
            COMMIT WORK;
            SET li_rows_since_commit = 0;
        END IF;

        FETCH c1 INTO li_idempresa, li_idproduto, li_idsubproduto;
    END WHILE;

    COMMIT WORK;
    CLOSE c1 WITH RELEASE;
END
~
COMMIT
~

CREATE OR REPLACE PROCEDURE DBA.SP_REPROCESSA_DTFIM_PROCUS()
LANGUAGE SQL
BEGIN
    DECLARE li_rows_updated BIGINT DEFAULT 0;
    DECLARE li_rows_since_commit BIGINT DEFAULT 0;
    DECLARE li_idempresa INTEGER;
    DECLARE li_idproduto INTEGER;
    DECLARE li_idsubproduto INTEGER;
    DECLARE li_upd INTEGER;
    DECLARE v_done SMALLINT DEFAULT 0;

    DECLARE c1 CURSOR WITH HOLD FOR
        SELECT idempresa, idproduto, idsubproduto
        FROM dba.produto_custo
        GROUP BY idempresa, idproduto, idsubproduto
        ORDER BY idempresa, idproduto, idsubproduto
        WITH RR;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

    OPEN c1;
    FETCH c1 INTO li_idempresa, li_idproduto, li_idsubproduto;

    WHILE v_done = 0 DO
        UPDATE dba.produto_custo t
           SET dtfim = COALESCE((
                SELECT MIN(t2.dtmovimento)
                FROM dba.produto_custo t2
                WHERE t2.idempresa = t.idempresa
                  AND t2.idproduto = t.idproduto
                  AND t2.idsubproduto = t.idsubproduto
                  AND t2.dtmovimento > t.dtmovimento
           ), DBA.UF_MAX_DTFIM())
         WHERE t.idempresa = li_idempresa
           AND t.idproduto = li_idproduto
           AND t.idsubproduto = li_idsubproduto;

        GET DIAGNOSTICS li_upd = ROW_COUNT;
        SET li_rows_updated = li_rows_updated + li_upd;
        SET li_rows_since_commit = li_rows_since_commit + li_upd;

        IF li_rows_since_commit >= 10000 THEN
            COMMIT WORK;
            SET li_rows_since_commit = 0;
        END IF;

        FETCH c1 INTO li_idempresa, li_idproduto, li_idsubproduto;
    END WHILE;

    COMMIT WORK;
    CLOSE c1 WITH RELEASE;
END
~
COMMIT
~

CONNECT RESET
~
