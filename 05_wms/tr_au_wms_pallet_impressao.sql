-- Db2 CLP: db2 -td@ -f 05_wms/tr_au_wms_pallet_impressao.sql
-- Gera uma solicitacao a cada transicao de FLAGPROCESSADO para T.
CREATE TRIGGER WMS.TR_AU_WMS_PALLET_IMPRESSAO
AFTER UPDATE OF FLAGPROCESSADO ON WMS.TB_WMS_PALLET
REFERENCING OLD AS O NEW AS N
FOR EACH ROW
WHEN (N.FLAGPROCESSADO = 'T' AND
      (O.FLAGPROCESSADO IS NULL OR O.FLAGPROCESSADO <> 'T'))
INSERT INTO DBA.GERENCIAMENTO_IMPRESSAO
    (IDEMPRESA, DOCUMENTOS, FLAGPROCESSADO, TIPOINTEGRACAO, IDUSUARIO)
VALUES (
    N.IDEMPRESAORIGEM,
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    || '<documento><tipodocumento>NFTRANSWMS</tipodocumento>'
    || '<iddocumento>' || TRIM(CHAR(N.NRODOCPALLET))
    || '</iddocumento></documento>',
    'F',
    'NFTRANSWMS',
    6
)@
