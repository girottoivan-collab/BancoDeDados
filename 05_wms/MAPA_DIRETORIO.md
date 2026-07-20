# Mapa do diretorio 05_wms

## Objetivo

Centralizar funcoes, triggers e views relacionadas a integracao WMS, conferencia de pedido e entrada WMS.

## Conteudo

- `TR_INS_CONFPED_PERSON.sql`: trigger de insercao em conferencia de pedido.
- `UF_CONFERE_PEDIDO_UTILIZA_WMS.sql`: function que decide uso de WMS na conferencia de pedido.
- `V_WMS_ENTRADA.sql`: view WMS de entrada.
- `V_WMS_ENTRADA_V2.sql`: segunda versao da view WMS de entrada.
- `MAPA_DIRETORIO.md`: este mapa local.

## Regras locais

- Mantenha juntas as rotinas que participam do fluxo de conferencia/entrada WMS.
- Versoes novas de views devem indicar claramente a variante no nome.
- Alteracoes de pedido sem impacto em WMS devem ficar em `04_pedido_compra`.
