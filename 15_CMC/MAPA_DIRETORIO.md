# Mapa do diretorio 15_CMC

## Objetivo

Guardar objetos e estudos relacionados ao processamento de custo medio de compra (CMC).

## Conteudo

- `ObjetosCMC.sql`: objetos de CMC, incluindo tabelas de processamento/historico/controle, indices, function, procedure e triggers.
- `ObjetosCMC_v2.sql`: recorte com objetos novos e objetos alterados em relacao a primeira versao do Git.
- `Detalhamento_Alteracoes_ObjetosCMC.md`: documentacao das mudancas, dicionario das novas tabelas e roteiro de validacao.
- `DER_Agrupamento_Custo_CMC.mmd`: DER Mermaid das tabelas de agrupamento de custo para CMC.
- `DER_Agrupamento_Custo_CMC.svg`: renderizacao SVG do DER de agrupamento de custo para CMC.
- `MAPA_DIRETORIO.md`: este mapa local.

## Regras locais

- Mantenha objetos de fila, historico, calculo e triggers de CMC juntos.
- Nomeie variacoes pelo assunto principal e criterio, como `ObjetosCMC_teste.sql` ou `ObjetosCMC_ajuste_trigger.sql`.
- Evidencias de validacao devem indicar periodo, empresa e origem dos movimentos quando forem adicionadas.
