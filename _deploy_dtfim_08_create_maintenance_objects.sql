CONNECT TO NOPONTO USER dba USING "a9d9p8.E10"
~

CREATE OR REPLACE PROCEDURE DBA.SP_PROCESSA_DTFIM_ESTSIN(
    p_idempresa INTEGER,
    p_idproduto INTEGER,
    p_idsubproduto INTEGER,
    p_idlocalestoque INTEGER,
    p_dtmovimento DATE
)
LANGUAGE SQL
BEGIN ATOMIC
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
     WHERE t.idempresa = p_idempresa
       AND t.idproduto = p_idproduto
       AND t.idsubproduto = p_idsubproduto
       AND t.idlocalestoque = p_idlocalestoque
       AND (
            t.dtmovimento = p_dtmovimento
         OR t.dtmovimento = (
                SELECT MAX(t3.dtmovimento)
                FROM dba.estoque_sintetico t3
                WHERE t3.idempresa = p_idempresa
                  AND t3.idproduto = p_idproduto
                  AND t3.idsubproduto = p_idsubproduto
                  AND t3.idlocalestoque = p_idlocalestoque
                  AND t3.dtmovimento < p_dtmovimento
            )
       );
END
~
COMMIT
~

CREATE OR REPLACE PROCEDURE DBA.SP_PROCESSA_DTFIM_CONSAL(
    p_idempresa INTEGER,
    p_idctacontabil INTEGER,
    p_dtmovimento DATE
)
LANGUAGE SQL
BEGIN ATOMIC
    UPDATE dba.contabil_saldo t
       SET dtfim = COALESCE((
            SELECT MIN(t2.dtmovimento)
            FROM dba.contabil_saldo t2
            WHERE t2.idempresa = t.idempresa
              AND t2.idctacontabil = t.idctacontabil
              AND t2.dtmovimento > t.dtmovimento
       ), DATE(DBA.UF_MAX_DTFIM()))
     WHERE t.idempresa = p_idempresa
       AND t.idctacontabil = p_idctacontabil
       AND (
            t.dtmovimento = p_dtmovimento
         OR t.dtmovimento = (
                SELECT MAX(t3.dtmovimento)
                FROM dba.contabil_saldo t3
                WHERE t3.idempresa = p_idempresa
                  AND t3.idctacontabil = p_idctacontabil
                  AND t3.dtmovimento < p_dtmovimento
            )
       );
END
~
COMMIT
~

CREATE OR REPLACE PROCEDURE DBA.SP_PROCESSA_DTFIM_PROCUS(
    p_idempresa INTEGER,
    p_idproduto INTEGER,
    p_idsubproduto INTEGER,
    p_dtmovimento TIMESTAMP
)
LANGUAGE SQL
BEGIN ATOMIC
    UPDATE dba.produto_custo t
       SET dtfim = COALESCE((
            SELECT MIN(t2.dtmovimento)
            FROM dba.produto_custo t2
            WHERE t2.idempresa = t.idempresa
              AND t2.idproduto = t.idproduto
              AND t2.idsubproduto = t.idsubproduto
              AND t2.dtmovimento > t.dtmovimento
       ), DBA.UF_MAX_DTFIM())
     WHERE t.idempresa = p_idempresa
       AND t.idproduto = p_idproduto
       AND t.idsubproduto = p_idsubproduto
       AND (
            t.dtmovimento = p_dtmovimento
         OR t.dtmovimento = (
                SELECT MAX(t3.dtmovimento)
                FROM dba.produto_custo t3
                WHERE t3.idempresa = p_idempresa
                  AND t3.idproduto = p_idproduto
                  AND t3.idsubproduto = p_idsubproduto
                  AND t3.dtmovimento < p_dtmovimento
            )
       );
END
~
COMMIT
~

CREATE OR REPLACE PROCEDURE DBA.SP_PROCESSA_DTFIM_MOVCUS(
    p_idempresa INTEGER,
    p_idproduto INTEGER,
    p_idsubproduto INTEGER,
    p_dtmovimento TIMESTAMP
)
LANGUAGE SQL
BEGIN ATOMIC
    UPDATE dba.movimento_custo t
       SET dtfim = COALESCE((
            SELECT MIN(t2.dtmovimento)
            FROM dba.movimento_custo t2
            WHERE t2.idempresa = t.idempresa
              AND t2.idproduto = t.idproduto
              AND t2.idsubproduto = t.idsubproduto
              AND t2.dtmovimento > t.dtmovimento
       ), DBA.UF_MAX_DTFIM())
     WHERE t.idempresa = p_idempresa
       AND t.idproduto = p_idproduto
       AND t.idsubproduto = p_idsubproduto
       AND (
            t.dtmovimento = p_dtmovimento
         OR t.dtmovimento = (
                SELECT MAX(t3.dtmovimento)
                FROM dba.movimento_custo t3
                WHERE t3.idempresa = p_idempresa
                  AND t3.idproduto = p_idproduto
                  AND t3.idsubproduto = p_idsubproduto
                  AND t3.dtmovimento < p_dtmovimento
            )
       );
END
~
COMMIT
~

CREATE OR REPLACE TRIGGER DBA.TR_DTFIM_ESTSIN_AI
AFTER INSERT ON DBA.ESTOQUE_SINTETICO
REFERENCING NEW AS N
FOR EACH ROW
BEGIN ATOMIC
    CALL DBA.SP_PROCESSA_DTFIM_ESTSIN(N.idempresa, N.idproduto, N.idsubproduto, N.idlocalestoque, N.dtmovimento);
END
~
COMMIT
~

CREATE OR REPLACE TRIGGER DBA.TR_DTFIM_ESTSIN_AD
AFTER DELETE ON DBA.ESTOQUE_SINTETICO
REFERENCING OLD AS D
FOR EACH ROW
BEGIN ATOMIC
    CALL DBA.SP_PROCESSA_DTFIM_ESTSIN(D.idempresa, D.idproduto, D.idsubproduto, D.idlocalestoque, D.dtmovimento);
END
~
COMMIT
~

CREATE OR REPLACE TRIGGER DBA.TR_DTFIM_ESTSIN_AU
AFTER UPDATE OF DTMOVIMENTO, IDEMPRESA, IDPRODUTO, IDSUBPRODUTO, IDLOCALESTOQUE ON DBA.ESTOQUE_SINTETICO
REFERENCING OLD AS O NEW AS N
FOR EACH ROW
BEGIN ATOMIC
    CALL DBA.SP_PROCESSA_DTFIM_ESTSIN(O.idempresa, O.idproduto, O.idsubproduto, O.idlocalestoque, O.dtmovimento);
    CALL DBA.SP_PROCESSA_DTFIM_ESTSIN(N.idempresa, N.idproduto, N.idsubproduto, N.idlocalestoque, N.dtmovimento);
END
~
COMMIT
~

CREATE OR REPLACE TRIGGER DBA.TR_DTFIM_CONSAL_AI
AFTER INSERT ON DBA.CONTABIL_SALDO
REFERENCING NEW AS N
FOR EACH ROW
BEGIN ATOMIC
    CALL DBA.SP_PROCESSA_DTFIM_CONSAL(N.idempresa, N.idctacontabil, N.dtmovimento);
END
~
COMMIT
~

CREATE OR REPLACE TRIGGER DBA.TR_DTFIM_CONSAL_AD
AFTER DELETE ON DBA.CONTABIL_SALDO
REFERENCING OLD AS D
FOR EACH ROW
BEGIN ATOMIC
    CALL DBA.SP_PROCESSA_DTFIM_CONSAL(D.idempresa, D.idctacontabil, D.dtmovimento);
END
~
COMMIT
~

CREATE OR REPLACE TRIGGER DBA.TR_DTFIM_CONSAL_AU
AFTER UPDATE OF DTMOVIMENTO, IDEMPRESA, IDCTACONTABIL ON DBA.CONTABIL_SALDO
REFERENCING OLD AS O NEW AS N
FOR EACH ROW
BEGIN ATOMIC
    CALL DBA.SP_PROCESSA_DTFIM_CONSAL(O.idempresa, O.idctacontabil, O.dtmovimento);
    CALL DBA.SP_PROCESSA_DTFIM_CONSAL(N.idempresa, N.idctacontabil, N.dtmovimento);
END
~
COMMIT
~

CREATE OR REPLACE TRIGGER DBA.TR_DTFIM_PROCUS_AI
AFTER INSERT ON DBA.PRODUTO_CUSTO
REFERENCING NEW AS N
FOR EACH ROW
BEGIN ATOMIC
    CALL DBA.SP_PROCESSA_DTFIM_PROCUS(N.idempresa, N.idproduto, N.idsubproduto, N.dtmovimento);
END
~
COMMIT
~

CREATE OR REPLACE TRIGGER DBA.TR_DTFIM_PROCUS_AD
AFTER DELETE ON DBA.PRODUTO_CUSTO
REFERENCING OLD AS D
FOR EACH ROW
BEGIN ATOMIC
    CALL DBA.SP_PROCESSA_DTFIM_PROCUS(D.idempresa, D.idproduto, D.idsubproduto, D.dtmovimento);
END
~
COMMIT
~

CREATE OR REPLACE TRIGGER DBA.TR_DTFIM_PROCUS_AU
AFTER UPDATE OF DTMOVIMENTO, IDEMPRESA, IDPRODUTO, IDSUBPRODUTO ON DBA.PRODUTO_CUSTO
REFERENCING OLD AS O NEW AS N
FOR EACH ROW
BEGIN ATOMIC
    CALL DBA.SP_PROCESSA_DTFIM_PROCUS(O.idempresa, O.idproduto, O.idsubproduto, O.dtmovimento);
    CALL DBA.SP_PROCESSA_DTFIM_PROCUS(N.idempresa, N.idproduto, N.idsubproduto, N.dtmovimento);
END
~
COMMIT
~

CREATE OR REPLACE TRIGGER DBA.TR_DTFIM_MOVCUS_AI
AFTER INSERT ON DBA.MOVIMENTO_CUSTO
REFERENCING NEW AS N
FOR EACH ROW
BEGIN ATOMIC
    CALL DBA.SP_PROCESSA_DTFIM_MOVCUS(N.idempresa, N.idproduto, N.idsubproduto, N.dtmovimento);
END
~
COMMIT
~

CREATE OR REPLACE TRIGGER DBA.TR_DTFIM_MOVCUS_AD
AFTER DELETE ON DBA.MOVIMENTO_CUSTO
REFERENCING OLD AS D
FOR EACH ROW
BEGIN ATOMIC
    CALL DBA.SP_PROCESSA_DTFIM_MOVCUS(D.idempresa, D.idproduto, D.idsubproduto, D.dtmovimento);
END
~
COMMIT
~

CREATE OR REPLACE TRIGGER DBA.TR_DTFIM_MOVCUS_AU
AFTER UPDATE OF DTMOVIMENTO, IDEMPRESA, IDPRODUTO, IDSUBPRODUTO ON DBA.MOVIMENTO_CUSTO
REFERENCING OLD AS O NEW AS N
FOR EACH ROW
BEGIN ATOMIC
    CALL DBA.SP_PROCESSA_DTFIM_MOVCUS(O.idempresa, O.idproduto, O.idsubproduto, O.dtmovimento);
    CALL DBA.SP_PROCESSA_DTFIM_MOVCUS(N.idempresa, N.idproduto, N.idsubproduto, N.dtmovimento);
END
~
COMMIT
~

CONNECT RESET
~
