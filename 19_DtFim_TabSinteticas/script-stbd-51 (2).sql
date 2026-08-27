/*

create table powerdba.log(
    created_at timestamp not null default current_timestamp,
    memo varchar(2000) not null
)

create procedure powerdba.log(p_memo varchar(2000))
begin atomic
    insert into powerdba.log(memo) values(p_memo);
end

DROP TRIGGER DBA.TR_DTFIM_ESTSIN_AD
~
DROP TRIGGER DBA.TR_DTFIM_ESTSIN_AI
~
DROP TRIGGER DBA.TR_DTFIM_ESTSIN_AU
~
DROP PROCEDURE DBA.SP_REPROCESSA_DTFIM_ESTSIN
~
DROP PROCEDURE DBA.SP_PROCESSA_DTFIM_ESTSIN
~
DROP FUNCTION DBA.UF_MAX_DTFIM
~
COMMIT
~

update dba.estoque_sintetico set dtfim = null~ commit

select count(1) from dba.estoque_sintetico where dtfim is null

**/

--
-- Elimina triggers se existirem
--
DROP TRIGGER DBA.TR_DTFIM_ESTSIN_AD
~
DROP TRIGGER DBA.TR_DTFIM_ESTSIN_AI
~
DROP TRIGGER DBA.TR_DTFIM_ESTSIN_AU
~
DROP TRIGGER DBA.TR_DTFIM_CONSAL_AD
~
DROP TRIGGER DBA.TR_DTFIM_CONSAL_AI
~
DROP TRIGGER DBA.TR_DTFIM_CONSAL_AU
~
DROP TRIGGER DBA.TR_DTFIM_MOVCUS_AD
~
DROP TRIGGER DBA.TR_DTFIM_MOVCUS_AI
~
DROP TRIGGER DBA.TR_DTFIM_MOVCUS_AU
~
DROP TRIGGER DBA.TR_DTFIM_PROCUS_AD
~
DROP TRIGGER DBA.TR_DTFIM_PROCUS_AI
~
DROP TRIGGER DBA.TR_DTFIM_PROCUS_AU
~



--
-- Adiciona colunas DTFIM
--
ALTER TABLE DBA.ESTOQUE_SINTETICO   ADD DTFIM DATE NULL
~
ALTER TABLE DBA.CONTABIL_SALDO      ADD DTFIM DATE NULL
~
ALTER TABLE DBA.PRODUTO_CUSTO       ADD DTFIM TIMESTAMP NULL
~
ALTER TABLE DBA.MOVIMENTO_CUSTO     ADD DTFIM TIMESTAMP NULL
~
COMMIT
~

--
-- Elimina indices se existirem
--
DROP INDEX DBA.IE_ESTSIN_DTFIM
~
COMMIT
~
DROP INDEX DBA.IE_CONSAL_DTFIM
~
COMMIT
~
-- PRODUTO_CUSTO nao pode ter indice unico
DROP INDEX DBA.IE_PROCUS_DTFIM
~
COMMIT
~
-- MOVIMENTO_CUSTO nao pode ter indice unico
DROP INDEX DBA.IE_MOVCUS_DTFIM
~
COMMIT
~

--
-- Funcao que retorna a data maxima usada nas colunas DTFIM
--
CREATE OR REPLACE FUNCTION DBA.UF_MAX_DTFIM()
RETURNS TIMESTAMP
LANGUAGE SQL
RETURN
    SELECT '2199-01-01 00.00.00.000000' AS d
    FROM SYSIBM.SYSDUMMY1
~
COMMIT
~


--
-- Procedure que reprocessa DTFIM para ESTOQUE_SINTETICO
--
CREATE OR REPLACE PROCEDURE DBA.SP_REPROCESSA_DTFIM_ESTSIN(
    OUT rows_updated BIGINT
)
LANGUAGE SQL
BEGIN
    DECLARE li_rows_updated     INTEGER DEFAULT 0;
    DECLARE li_idempresa        INTEGER;
    DECLARE li_idproduto        INTEGER;
    DECLARE li_idsubproduto     INTEGER;
    DECLARE li_idlocalestoque   INTEGER;
    DECLARE li_upd              INTEGER;

    DECLARE v_outer_done        SMALLINT DEFAULT 0;

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
            AND idlocalestoque = li_idlocalestoque
            ;
            
            GET DIAGNOSTICS li_upd = ROW_COUNT;

            SET li_rows_updated = li_rows_updated + li_upd;

            IF MOD(li_rows_updated, 10000) = 0 THEN
                COMMIT WORK;
            END IF;
        END;

        FETCH c1 INTO
            li_idempresa,
            li_idproduto,
            li_idsubproduto,
            li_idlocalestoque;

    END WHILE;

    COMMIT WORK;
    
    CLOSE c1 WITH RELEASE;
    
    SET rows_updated = li_rows_updated;
END
~
COMMIT
~


--
-- Procedure que reprocessa DTFIM para CONTABIL_SALDO
--
CREATE OR REPLACE PROCEDURE DBA.SP_REPROCESSA_DTFIM_CONSAL(
    OUT rows_updated BIGINT
)
LANGUAGE SQL
BEGIN
    DECLARE li_rows_updated     INTEGER DEFAULT 0;

    DECLARE li_idempresa        INTEGER;
    DECLARE li_idctacontabil    INTEGER;
    DECLARE li_upd              INTEGER;

    DECLARE v_outer_done        SMALLINT DEFAULT 0;

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
            AND idctacontabil   = li_idctacontabil
            ;
                
            GET DIAGNOSTICS li_upd = ROW_COUNT;

            SET li_rows_updated = li_rows_updated + li_upd;

            IF MOD(li_rows_updated, 10000) = 0 THEN
                COMMIT WORK;
            END IF;
        END;

        FETCH c1 INTO
            li_idempresa,
            li_idctacontabil;

    END WHILE;

    COMMIT WORK;

    CLOSE c1 WITH RELEASE;
    
    SET rows_updated = li_rows_updated;
END
~
COMMIT
~



--
-- Procedure que reprocessa DTFIM para MOVIMENTO_CUSTO
--
CREATE OR REPLACE PROCEDURE DBA.SP_REPROCESSA_DTFIM_MOVCUS(
    OUT rows_updated BIGINT
)
LANGUAGE SQL
BEGIN
    DECLARE li_rows_updated     INTEGER DEFAULT 0;

    DECLARE li_idempresa        INTEGER;
    DECLARE li_idproduto        INTEGER;
    DECLARE li_idsubproduto     INTEGER;
    DECLARE li_upd              INTEGER;

    DECLARE v_outer_done        SMALLINT DEFAULT 0;

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
            
            IF MOD(li_rows_updated, 10000) = 0 THEN
                COMMIT WORK;
            END IF;
        END;

        FETCH c1 INTO
            li_idempresa,
            li_idproduto,
            li_idsubproduto;

    END WHILE;

    COMMIT WORK;

    CLOSE c1 WITH RELEASE;
    
    SET rows_updated = li_rows_updated;
END
~
COMMIT
~



-- select * from syscat.indexes where tabname='PRODUTO_CUSTO'
-- SELECT COUNT(1) FROM DBA.PRODUTO_CUSTO

--
-- Procedure que reprocessa DTFIM para PRODUTO_CUSTO
--
CREATE OR REPLACE PROCEDURE DBA.SP_REPROCESSA_DTFIM_PROCUS(
    OUT rows_updated BIGINT
)
LANGUAGE SQL
BEGIN
    DECLARE li_rows_updated     INTEGER DEFAULT 0;

    DECLARE li_idempresa        INTEGER;
    DECLARE li_idproduto        INTEGER;
    DECLARE li_idsubproduto     INTEGER;
    DECLARE li_upd              INTEGER;

    DECLARE v_outer_done        SMALLINT DEFAULT 0;

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
            
            IF MOD(li_rows_updated, 10000) = 0 THEN
                COMMIT WORK;
            END IF;
        END;

        FETCH c1 INTO
            li_idempresa,
            li_idproduto,
            li_idsubproduto;

    END WHILE;

    COMMIT WORK;

    CLOSE c1 WITH RELEASE;
    
    SET rows_updated = li_rows_updated;
END
~
COMMIT
~


--
-- Processa todos os registros definindo o valor de DTFIM
--
CALL DBA.SP_REPROCESSA_DTFIM_ESTSIN()
~
COMMIT
~
CALL DBA.SP_REPROCESSA_DTFIM_CONSAL()
~
COMMIT
~
CALL DBA.SP_REPROCESSA_DTFIM_MOVCUS()
~
COMMIT
~
-- O processamento sobre Movimento Custo já vai preencher os dados
-- da tabela Produto Custo, mas mesmo assim é bom chamar para
-- alterar apenas os que estiverem diferentes, se houver. 
CALL DBA.SP_REPROCESSA_DTFIM_PROCUS()
~
COMMIT
~

--
-- Cria indices
--
CREATE UNIQUE INDEX DBA.IE_ESTSIN_DTFIM ON DBA.ESTOQUE_SINTETICO (
    DTFIM,
    DTMOVIMENTO,
    IDSUBPRODUTO,
    IDEMPRESA,
    IDLOCALESTOQUE,
    IDPRODUTO
)
~
COMMIT
~
CREATE UNIQUE INDEX DBA.IE_CONSAL_DTFIM ON DBA.CONTABIL_SALDO (
    DTFIM,
    DTMOVIMENTO,
    IDCTACONTABIL,
    IDEMPRESA
)
~
COMMIT
~
-- PRODUTO_CUSTO nao pode ter indice unico
CREATE INDEX DBA.IE_PROCUS_DTFIM ON DBA.PRODUTO_CUSTO (
    DTFIM,
    DTMOVIMENTO,
    IDSUBPRODUTO,
    IDEMPRESA,
    IDPRODUTO
)
~
COMMIT
~
-- MOVIMENTO_CUSTO nao pode ter indice unico
CREATE INDEX DBA.IE_MOVCUS_DTFIM ON DBA.MOVIMENTO_CUSTO (
    DTFIM,
    DTMOVIMENTO,
    IDSUBPRODUTO,
    IDEMPRESA,
    IDPRODUTO
)
~
COMMIT
~

-- 
-- Procedure para atualizar em trigger - ESTOQUE_SINTETICO
--
CREATE OR REPLACE PROCEDURE DBA.SP_PROCESSA_DTFIM_ESTSIN(
    p_idempresa         INTEGER,
    p_idproduto         INTEGER,
    p_idsubproduto      INTEGER,
    p_idlocalestoque    INTEGER,
    p_dtmovimento       DATE
)
BEGIN ATOMIC
    DECLARE ld_prev             DATE;
    DECLARE ld_next             DATE;
    DECLARE ld_dtfim            DATE;
    
--    CALL powerdba.log(
--        'p_dtmovimento = ' || VARCHAR_FORMAT(
--            p_dtmovimento,
--            'YYYY-MM-DD'
--        )
--    );
    
    -- DTMOVIMENTO do registro ANTERIOR ao alterado
    SET ld_prev = COALESCE((
        SELECT
            max(e2.dtmovimento)
        FROM
            dba.estoque_sintetico e2
        WHERE
            e2.idempresa        = p_idempresa
        AND e2.idproduto        = p_idproduto
        AND e2.idsubproduto     = p_idsubproduto
        AND e2.idlocalestoque   = p_idlocalestoque
        AND e2.dtmovimento      < p_dtmovimento
    ),'1900-01-01');
    
    -- DTMOVIMENTO do registro POSTERIOR ao alterado
    SET ld_next = COALESCE((
        SELECT
            min(e2.dtmovimento)
        FROM
            dba.estoque_sintetico e2
        WHERE
            e2.idempresa        = p_idempresa
        AND e2.idproduto        = p_idproduto
        AND e2.idsubproduto     = p_idsubproduto
        AND e2.idlocalestoque   = p_idlocalestoque
        AND e2.dtmovimento      > p_dtmovimento
    ),DATE(DBA.UF_MAX_DTFIM()));
    
--    CALL powerdba.log(
--        'ld_prev = ' || VARCHAR_FORMAT(
--            ld_prev,
--            'YYYY-MM-DD'
--        )
--    );
--    
--    CALL powerdba.log(
--        'ld_next = ' || VARCHAR_FORMAT(
--            ld_next,
--            'YYYY-MM-DD'
--        )
--    );
    
    --
    -- Cursor pega o range do registro anterior
    -- e do posterior para atualizar
    --
    FOR vdtfim AS cdtfim CURSOR WITH HOLD FOR
        SELECT
            idempresa       AS li_idempresa,
            idproduto       AS li_idproduto,
            idsubproduto    AS li_idsubproduto,
            idlocalestoque  AS li_idlocalestoque,
            dtmovimento     AS ld_dtmovimento
        FROM
            dba.estoque_sintetico e
        WHERE
            idempresa       = p_idempresa
        AND idproduto       = p_idproduto
        AND idsubproduto    = p_idsubproduto
        AND idlocalestoque  = p_idlocalestoque
        
        /* registro ANTES */
        AND dtmovimento    >= ld_prev
        
        /* registro DEPOIS */
        AND dtmovimento    <= ld_next
        
        ORDER BY
            e.dtmovimento DESC /* order do maior para o menor */
        WITH RR
    DO
        IF ld_dtfim IS NULL THEN
            -- na entrada do loop, apenas na primeira iteracao
            -- ld_dtfim sera NULL
            -- note que os argumentos sao do loop
            SET ld_dtfim = COALESCE((
                SELECT
                    min(e2.dtmovimento)
                FROM
                    dba.estoque_sintetico e2
                WHERE
                    e2.idempresa        = li_idempresa
                AND e2.idproduto        = li_idproduto
                AND e2.idsubproduto     = li_idsubproduto
                AND e2.idlocalestoque   = li_idlocalestoque
                AND e2.dtmovimento      > ld_dtmovimento
            ),DATE(DBA.UF_MAX_DTFIM()));
        END IF;
    
--        CALL powerdba.log(
--            '    - ld_dtmovimento = ' || COALESCE(VARCHAR_FORMAT(
--                ld_dtmovimento,
--                'YYYY-MM-DD'
--            ),'null')
--        );
--            
--        CALL powerdba.log(
--            '    - ld_dtfim = ' || COALESCE(VARCHAR_FORMAT(
--                ld_dtfim,
--                'YYYY-MM-DD'
--            ),'null')
--        );
        
        -- o update so eh feito se o dtfim for diferente
        -- isso economiza log transacional se o valor nao
        -- foi alterado
        UPDATE
            dba.estoque_sintetico
        SET
            dtfim = ld_dtfim
        WHERE
            idempresa       = li_idempresa
        AND idproduto       = li_idproduto
        AND idsubproduto    = li_idsubproduto
        AND idlocalestoque  = li_idlocalestoque
        AND dtmovimento     = ld_dtmovimento
        AND (dtfim <> ld_dtfim OR dtfim IS NULL);
        
        -- Agora, DTFIM passa a ser DTMOVIMENTO para o proximo
        -- registro
        SET ld_dtfim = ld_dtmovimento;
    END FOR;
END
~
COMMIT
~


-- 
-- Procedure para atualizar em trigger - CONTABIL_SALDO
--
CREATE OR REPLACE PROCEDURE DBA.SP_PROCESSA_DTFIM_CONSAL(
    p_idempresa         INTEGER,
    p_idctacontabil     INTEGER,
    p_dtmovimento       DATE
)
BEGIN ATOMIC
    DECLARE ld_prev             DATE;
    DECLARE ld_next             DATE;
    DECLARE ld_dtfim            DATE;
    
    -- DTMOVIMENTO do registro ANTERIOR ao alterado
    SET ld_prev = COALESCE((
        SELECT
            max(e2.dtmovimento)
        FROM
            dba.contabil_saldo e2
        WHERE
            e2.idempresa        = p_idempresa
        AND e2.idctacontabil    = p_idctacontabil
        AND e2.dtmovimento      < p_dtmovimento
    ),'1900-01-01');
    
    -- DTMOVIMENTO do registro POSTERIOR ao alterado
    SET ld_next = COALESCE((
        SELECT
            min(e2.dtmovimento)
        FROM
            dba.contabil_saldo e2
        WHERE
            e2.idempresa        = p_idempresa
        AND e2.idctacontabil    = p_idctacontabil
        AND e2.dtmovimento      < p_dtmovimento
    ),DATE(DBA.UF_MAX_DTFIM()));
    
    --
    -- Cursor pega o range do registro anterior
    -- e do posterior para atualizar
    --
    FOR vdtfim AS cdtfim CURSOR FOR
        SELECT
            idempresa       AS li_idempresa,
            idctacontabil   AS li_idctacontabil,
            dtmovimento     AS ld_dtmovimento
        FROM
            dba.contabil_saldo e
        WHERE
            idempresa       = p_idempresa
        AND idctacontabil   = p_idctacontabil
        
        /* registro ANTES */
        AND dtmovimento    >= ld_prev
        
        /* registro DEPOIS */
        AND dtmovimento    <= ld_next
        
        ORDER BY
            e.dtmovimento DESC /* order do maior para o menor */
        WITH RR
    DO
        IF ld_dtfim IS NULL THEN
            -- na entrada do loop, apenas na primeira iteracao
            -- ld_dtfim sera NULL
            -- note que os argumentos sao do loop
            SET ld_dtfim = COALESCE((
                SELECT
                    min(e2.dtmovimento)
                FROM
                    dba.contabil_saldo e2
                WHERE
                    e2.idempresa        = li_idempresa
                AND e2.idctacontabil    = li_idctacontabil
                AND e2.dtmovimento      > ld_dtmovimento
            ),DATE(DBA.UF_MAX_DTFIM()));
        END IF;
    
        -- o update so eh feito se o dtfim for diferente
        -- isso economiza log transacional se o valor nao
        -- foi alterado
        UPDATE
            dba.contabil_saldo
        SET
            dtfim = ld_dtfim
        WHERE
            idempresa       = li_idempresa
        AND idctacontabil   = li_idctacontabil
        AND dtmovimento     = ld_dtmovimento
        AND (dtfim <> ld_dtfim OR dtfim IS NULL);
        
        -- Agora, DTFIM passa a ser DTMOVIMENTO para o proximo
        -- registro
        SET ld_dtfim = ld_dtmovimento;
    END FOR;
END
~
COMMIT
~

-- 
-- Procedure para atualizar em trigger - PRODUTO_CUSTO
--
CREATE OR REPLACE PROCEDURE DBA.SP_PROCESSA_DTFIM_PROCUS(
    p_idempresa         INTEGER,
    p_idproduto         INTEGER,
    p_idsubproduto      INTEGER,
    p_dtmovimento       TIMESTAMP
)
BEGIN ATOMIC
    DECLARE ld_prev             TIMESTAMP;
    DECLARE ld_next             TIMESTAMP;
    DECLARE ld_dtfim            TIMESTAMP;
    
    -- DTMOVIMENTO do registro ANTERIOR ao alterado
    SET ld_prev = COALESCE((
        SELECT
            max(e2.dtmovimento)
        FROM
            dba.produto_custo e2
        WHERE
            e2.idempresa        = p_idempresa
        AND e2.idproduto        = p_idproduto
        AND e2.idsubproduto     = p_idsubproduto
        AND e2.dtmovimento      < p_dtmovimento
    ),'1900-01-01 00:00:00.000000');
    
    -- DTMOVIMENTO do registro POSTERIOR ao alterado
    SET ld_next = COALESCE((
        SELECT
            min(e2.dtmovimento)
        FROM
            dba.produto_custo e2
        WHERE
            e2.idempresa        = p_idempresa
        AND e2.idproduto        = p_idproduto
        AND e2.idsubproduto     = p_idsubproduto
        AND e2.dtmovimento      > p_dtmovimento
    ),DBA.UF_MAX_DTFIM());
    

    --
    -- Cursor pega o range do registro anterior
    -- e do posterior para atualizar
    --
    FOR vdtfim AS cdtfim CURSOR FOR
        SELECT
            idempresa       AS li_idempresa,
            idproduto       AS li_idproduto,
            idsubproduto    AS li_idsubproduto,
            dtmovimento     AS ld_dtmovimento
        FROM
            dba.produto_custo e
        WHERE
            idempresa       = p_idempresa
        AND idproduto       = p_idproduto
        AND idsubproduto    = p_idsubproduto
        
        /* registro ANTES */
        AND dtmovimento    >= ld_prev
        
        /* registro DEPOIS */
        AND dtmovimento    <= ld_next
        
        ORDER BY
            e.dtmovimento DESC /* order do maior para o menor */
        WITH RR
    DO
        IF ld_dtfim IS NULL THEN
            -- na entrada do loop, apenas na primeira iteracao
            -- ld_dtfim sera NULL
            -- note que os argumentos sao do loop
            SET ld_dtfim = COALESCE((
                SELECT
                    min(e2.dtmovimento)
                FROM
                    dba.produto_custo e2
                WHERE
                    e2.idempresa        = li_idempresa
                AND e2.idproduto        = li_idproduto
                AND e2.idsubproduto     = li_idsubproduto
                AND e2.dtmovimento      > ld_dtmovimento
            ),DBA.UF_MAX_DTFIM());
        END IF;
    
        -- o update so eh feito se o dtfim for diferente
        -- isso economiza log transacional se o valor nao
        -- foi alterado
        UPDATE
            dba.produto_custo
        SET
            dtfim = ld_dtfim
        WHERE
            idempresa       = li_idempresa
        AND idproduto       = li_idproduto
        AND idsubproduto    = li_idsubproduto
        AND dtmovimento     = ld_dtmovimento
        AND (dtfim <> ld_dtfim OR dtfim IS NULL);
        
        -- Agora, DTFIM passa a ser DTMOVIMENTO para o proximo
        -- registro
        SET ld_dtfim = ld_dtmovimento;
    END FOR;
END
~
COMMIT
~


-- 
-- Procedure para atualizar em trigger - MOVIMENTO_CUSTO
--
CREATE OR REPLACE PROCEDURE DBA.SP_PROCESSA_DTFIM_MOVCUS(
    p_idempresa         INTEGER,
    p_idproduto         INTEGER,
    p_idsubproduto      INTEGER,
    p_dtmovimento       TIMESTAMP
)
BEGIN ATOMIC
    DECLARE ld_prev             TIMESTAMP;
    DECLARE ld_next             TIMESTAMP;
    DECLARE ld_dtfim            TIMESTAMP;
    
    -- DTMOVIMENTO do registro ANTERIOR ao alterado
    SET ld_prev = COALESCE((
        SELECT
            max(e2.dtmovimento)
        FROM
            dba.MOVIMENTO_CUSTO e2
        WHERE
            e2.idempresa        = p_idempresa
        AND e2.idproduto        = p_idproduto
        AND e2.idsubproduto     = p_idsubproduto
        AND e2.dtmovimento      < p_dtmovimento
    ),'1900-01-01 00:00:00.000000');
    
    -- DTMOVIMENTO do registro POSTERIOR ao alterado
    SET ld_next = COALESCE((
        SELECT
            min(e2.dtmovimento)
        FROM
            dba.MOVIMENTO_CUSTO e2
        WHERE
            e2.idempresa        = p_idempresa
        AND e2.idproduto        = p_idproduto
        AND e2.idsubproduto     = p_idsubproduto
        AND e2.dtmovimento      > p_dtmovimento
    ),DBA.UF_MAX_DTFIM());
    

    --
    -- Cursor pega o range do registro anterior
    -- e do posterior para atualizar
    --
    FOR vdtfim AS cdtfim CURSOR FOR
        SELECT
            idempresa       AS li_idempresa,
            idproduto       AS li_idproduto,
            idsubproduto    AS li_idsubproduto,
            dtmovimento     AS ld_dtmovimento
        FROM
            dba.MOVIMENTO_CUSTO e
        WHERE
            idempresa       = p_idempresa
        AND idproduto       = p_idproduto
        AND idsubproduto    = p_idsubproduto
        
        /* registro ANTES */
        AND dtmovimento    >= ld_prev
        
        /* registro DEPOIS */
        AND dtmovimento    <= ld_next
        
        ORDER BY
            e.dtmovimento DESC /* order do maior para o menor */
        WITH RR
    DO
        IF ld_dtfim IS NULL THEN
            -- na entrada do loop, apenas na primeira iteracao
            -- ld_dtfim sera NULL
            -- note que os argumentos sao do loop
            SET ld_dtfim = COALESCE((
                SELECT
                    min(e2.dtmovimento)
                FROM
                    dba.MOVIMENTO_CUSTO e2
                WHERE
                    e2.idempresa        = li_idempresa
                AND e2.idproduto        = li_idproduto
                AND e2.idsubproduto     = li_idsubproduto
                AND e2.dtmovimento      > ld_dtmovimento
            ),DBA.UF_MAX_DTFIM());
        END IF;
    
        -- o update so eh feito se o dtfim for diferente
        -- isso economiza log transacional se o valor nao
        -- foi alterado
        UPDATE
            dba.MOVIMENTO_CUSTO
        SET
            dtfim = ld_dtfim
        WHERE
            idempresa       = li_idempresa
        AND idproduto       = li_idproduto
        AND idsubproduto    = li_idsubproduto
        AND dtmovimento     = ld_dtmovimento
        AND (dtfim <> ld_dtfim OR dtfim IS NULL);
        
        -- Agora, DTFIM passa a ser DTMOVIMENTO para o proximo
        -- registro
        SET ld_dtfim = ld_dtmovimento;
    END FOR;
END
~
COMMIT
~


--
-- Trigger que atualiza DTFIM - INSERT - ESTOQUE_SINTETICO
--
CREATE OR REPLACE TRIGGER DBA.TR_DTFIM_ESTSIN_AI
AFTER INSERT
ON DBA.ESTOQUE_SINTETICO
REFERENCING NEW AS N
FOR EACH ROW 
BEGIN ATOMIC
    CALL DBA.SP_PROCESSA_DTFIM_ESTSIN(
        n.idempresa,
        n.idproduto,
        n.idsubproduto,
        n.idlocalestoque,
        n.dtmovimento
    );
END
~
COMMIT
~

--
-- Trigger que atualiza DTFIM - DELETE - ESTOQUE_SINTETICO
--
CREATE OR REPLACE TRIGGER DBA.TR_DTFIM_ESTSIN_AD
AFTER DELETE
ON DBA.ESTOQUE_SINTETICO
REFERENCING OLD AS D
FOR EACH ROW 
BEGIN ATOMIC
    CALL DBA.SP_PROCESSA_DTFIM_ESTSIN(
        d.idempresa,
        d.idproduto,
        d.idsubproduto,
        d.idlocalestoque,
        d.dtmovimento
    );
END
~
COMMIT
~

--
-- Trigger que atualiza DTFIM - update - ESTOQUE_SINTETICO
--
CREATE OR REPLACE TRIGGER DBA.TR_DTFIM_ESTSIN_AU
AFTER UPDATE
OF DTMOVIMENTO /* Soh interessa se pelo menos um desses valores mudar */
ON DBA.ESTOQUE_SINTETICO
REFERENCING OLD AS O NEW AS N
FOR EACH ROW 
BEGIN ATOMIC
    CALL DBA.SP_PROCESSA_DTFIM_ESTSIN(
        o.idempresa,
        o.idproduto,
        o.idsubproduto,
        o.idlocalestoque,
        o.dtmovimento
    );
    
    CALL DBA.SP_PROCESSA_DTFIM_ESTSIN(
        n.idempresa,
        n.idproduto,
        n.idsubproduto,
        n.idlocalestoque,
        n.dtmovimento
    );
END
~
COMMIT
~


--
-- Trigger que atualiza DTFIM - INSERT - CONTABIL_SALDO
--
CREATE OR REPLACE TRIGGER DBA.TR_DTFIM_CONSAL_AI
AFTER INSERT
ON DBA.CONTABIL_SALDO
REFERENCING NEW AS N
FOR EACH ROW 
BEGIN ATOMIC
    CALL DBA.SP_PROCESSA_DTFIM_CONSAL(
        n.idempresa,
        n.idctacontabil,
        n.dtmovimento
    );
END
~
COMMIT
~

--
-- Trigger que atualiza DTFIM - DELETE - CONTABIL_SALDO
--
CREATE OR REPLACE TRIGGER DBA.TR_DTFIM_CONSAL_AD
AFTER DELETE
ON DBA.CONTABIL_SALDO
REFERENCING OLD AS D
FOR EACH ROW 
BEGIN ATOMIC
    CALL DBA.SP_PROCESSA_DTFIM_CONSAL(
        d.idempresa,
        d.idctacontabil,
        d.dtmovimento
    );
END
~
COMMIT
~

--
-- Trigger que atualiza DTFIM - UPDATE - CONTABIL_SALDO
--
CREATE OR REPLACE TRIGGER DBA.TR_DTFIM_CONSAL_AU
AFTER UPDATE
OF DTMOVIMENTO
ON DBA.CONTABIL_SALDO
REFERENCING OLD AS O NEW AS N
FOR EACH ROW 
BEGIN ATOMIC
    CALL DBA.SP_PROCESSA_DTFIM_CONSAL(
        o.idempresa,
        o.idctacontabil,
        o.dtmovimento
    );
    
    CALL DBA.SP_PROCESSA_DTFIM_CONSAL(
        n.idempresa,
        n.idctacontabil,
        n.dtmovimento
    );
END
~
COMMIT
~


--
-- Trigger que atualiza DTFIM - INSERT - PRODUTO_CUSTO
--
CREATE OR REPLACE TRIGGER DBA.TR_DTFIM_PROCUS_AI
AFTER INSERT
ON DBA.PRODUTO_CUSTO
REFERENCING NEW AS N
FOR EACH ROW 
BEGIN ATOMIC
    CALL DBA.SP_PROCESSA_DTFIM_PROCUS(
        n.idempresa,
        n.idproduto,
        n.idsubproduto,
        n.dtmovimento
    );
END
~
COMMIT
~

--
-- Trigger que atualiza DTFIM - DELETE - PRODUTO_CUSTO
--
CREATE OR REPLACE TRIGGER DBA.TR_DTFIM_PROCUS_AD
AFTER DELETE
ON DBA.PRODUTO_CUSTO
REFERENCING OLD AS D
FOR EACH ROW 
BEGIN ATOMIC
    CALL DBA.SP_PROCESSA_DTFIM_PROCUS(
        d.idempresa,
        d.idproduto,
        d.idsubproduto,
        d.dtmovimento
    );
END
~
COMMIT
~

--
-- Trigger que atualiza DTFIM - update - PRODUTO_CUSTO
--
CREATE OR REPLACE TRIGGER DBA.TR_DTFIM_PROCUS_AU
AFTER UPDATE
OF DTMOVIMENTO 
ON DBA.PRODUTO_CUSTO
REFERENCING OLD AS O NEW AS N
FOR EACH ROW 
BEGIN ATOMIC
    CALL DBA.SP_PROCESSA_DTFIM_PROCUS(
        o.idempresa,
        o.idproduto,
        o.idsubproduto,
        o.dtmovimento
    );
    
    CALL DBA.SP_PROCESSA_DTFIM_PROCUS(
        n.idempresa,
        n.idproduto,
        n.idsubproduto,
        n.dtmovimento
    );
END
~
COMMIT
~


--
-- Trigger que atualiza DTFIM - INSERT - MOVIMENTO_CUSTO
--
CREATE OR REPLACE TRIGGER DBA.TR_DTFIM_MOVCUS_AI
AFTER INSERT
ON DBA.MOVIMENTO_CUSTO
REFERENCING NEW AS N
FOR EACH ROW 
BEGIN ATOMIC
    CALL DBA.SP_PROCESSA_DTFIM_MOVCUS(
        n.idempresa,
        n.idproduto,
        n.idsubproduto,
        n.dtmovimento
    );
END
~
COMMIT
~

--
-- Trigger que atualiza DTFIM - DELETE - MOVIMENTO_CUSTO
--
CREATE OR REPLACE TRIGGER DBA.TR_DTFIM_MOVCUS_AD
AFTER DELETE
ON DBA.MOVIMENTO_CUSTO
REFERENCING OLD AS D
FOR EACH ROW 
BEGIN ATOMIC
    CALL DBA.SP_PROCESSA_DTFIM_MOVCUS(
        d.idempresa,
        d.idproduto,
        d.idsubproduto,
        d.dtmovimento
    );
END
~
COMMIT
~

--
-- Trigger que atualiza DTFIM - update - MOVIMENTO_CUSTO
--
CREATE OR REPLACE TRIGGER DBA.TR_DTFIM_MOVCUS_AU
AFTER UPDATE
OF DTMOVIMENTO 
ON DBA.MOVIMENTO_CUSTO
REFERENCING OLD AS O NEW AS N
FOR EACH ROW 
BEGIN ATOMIC
    CALL DBA.SP_PROCESSA_DTFIM_MOVCUS(
        o.idempresa,
        o.idproduto,
        o.idsubproduto,
        o.dtmovimento
    );
    
    CALL DBA.SP_PROCESSA_DTFIM_MOVCUS(
        n.idempresa,
        n.idproduto,
        n.idsubproduto,
        n.dtmovimento
    );
END
~
COMMIT
~

--
-- Altera colunas DTFIM para NOT NULL
--
ALTER TABLE DBA.ESTOQUE_SINTETICO   ALTER COLUMN DTFIM SET NOT NULL
~
ALTER TABLE DBA.CONTABIL_SALDO      ALTER COLUMN DTFIM SET NOT NULL
~
ALTER TABLE DBA.PRODUTO_CUSTO       ALTER COLUMN DTFIM SET NOT NULL
~
ALTER TABLE DBA.MOVIMENTO_CUSTO     ALTER COLUMN DTFIM SET NOT NULL
~
COMMIT
~
