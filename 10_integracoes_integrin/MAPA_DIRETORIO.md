# Mapa do diretorio 10_integracoes_integrin

## Objetivo

Guardar funcoes e migrations ligadas ao schema `INTEGRIM` e a rotinas de integracao externa Integrin.

## Conteudo

- `V46__function_set_item_pedido_integrin_v2.sql`: migration/function `INTEGRIM.SET_ITEM_PEDIDO_INTEGRIN_V2`.
- `MAPA_DIRETORIO.md`: este mapa local.

## Regras locais

- Preserve o prefixo de migration quando o script fizer parte de uma esteira versionada.
- Rotinas do schema `INTEGRIM` devem permanecer neste diretorio.
- Scripts de integracao de outro dominio devem ganhar diretorio proprio se o volume crescer.
