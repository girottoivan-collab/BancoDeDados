-- CISS-183841
-- Rastreamento de alteracoes da ESTOQUE_SINTETICO para reprocessamento de CMV.
-- Executar com: db2 -td@ -vf 01_deploy_cmv_dtalteracao.sql
-- Alias logico da demanda: NOPONTO_NEW (catalogo DB2 local: NOPNEW01; limite DB2: 8 caracteres).

CONNECT TO NOPNEW01 USER dba USING "a9d9p8.E10"@

-- Mantem os registros historicos como NULL: eles nao representam uma alteracao
-- ocorrida apos a implantacao e, portanto, nao provocam reprocessamento em massa.
ALTER TABLE DBA.ESTOQUE_SINTETICO
    ADD COLUMN DTALTERACAO TIMESTAMP@

-- Carimba tambem inclusoes novas, pois elas podem ser de movimento retroativo.
CREATE TRIGGER DBA.TR_ESTSIN_DTALTERACAO_BI
    NO CASCADE BEFORE INSERT ON DBA.ESTOQUE_SINTETICO
    REFERENCING NEW AS N
    FOR EACH ROW
    MODE DB2SQL
    SET N.DTALTERACAO = CURRENT TIMESTAMP@

-- Carimba toda atualizacao, inclusive as efetuadas pela SP de custo medio.
CREATE TRIGGER DBA.TR_ESTSIN_DTALTERACAO_BU
    NO CASCADE BEFORE UPDATE ON DBA.ESTOQUE_SINTETICO
    REFERENCING NEW AS N
    FOR EACH ROW
    MODE DB2SQL
    SET N.DTALTERACAO = CURRENT TIMESTAMP@

-- Exclusoes nao deixam uma linha para ser identificada por DTALTERACAO. Reabre
-- apenas a fila da data afetada; o reprocessador reabre as posteriores, quando houver.
-- TPSTATUS: 0 = Pendente, 1 = Concluido, 2 = Erro.
CREATE TRIGGER DBA.TR_ESTSIN_CMV_AD
    AFTER DELETE ON DBA.ESTOQUE_SINTETICO
    REFERENCING OLD AS O
    FOR EACH ROW
    MODE DB2SQL
    UPDATE DBA.CONTABIL_PROCESSAMENTO_CMV
       SET TPSTATUS = 0
     WHERE IDEMPRESA = O.IDEMPRESA
       AND DTPROCESSAMENTO = O.DTMOVIMENTO
       AND TPSTATUS <> 0@

-- A leitura do processador e dirigida pela janela de alteracao; este indice evita
-- varredura da tabela para localizar empresa/dia afetados.
CREATE INDEX DBA.IX_ESTSIN_DTALT_EMP_DT
    ON DBA.ESTOQUE_SINTETICO (DTALTERACAO, IDEMPRESA, DTMOVIMENTO)@

RUNSTATS ON TABLE DBA.ESTOQUE_SINTETICO
    AND INDEXES ALL@

CONNECT RESET@
