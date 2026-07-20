# Mapa do diretorio 04_pedido_compra

## Objetivo

Organizar procedure, views, backups e ajustes relacionados a pedido de compra.

## Conteudo

- `SP_INSERT_PEDIDO_COMPRA_PROD.sql`: procedure principal.
- `SP_INSERT_PEDIDO_COMPRA_PROD_bkp10072026.sql`: backup datado da procedure.
- `VW_GEA_PEDIDO_COMPRA.sql`: view de pedido de compra para integracao GEA.
- `VW_GEA_PEDIDO_COMPRA_ALTERADO.sql`: view alterada de pedido de compra para integracao GEA.
- `MAPA_DIRETORIO.md`: este mapa local.

## Regras locais

- Preserve backups datados ao lado da rotina principal.
- Views GEA e procedure de pedido devem permanecer juntas quando fizerem parte da mesma entrega.
- Scripts que afetem WMS devem ir para `05_wms`, salvo quando forem parte inseparavel da rotina de pedido.
