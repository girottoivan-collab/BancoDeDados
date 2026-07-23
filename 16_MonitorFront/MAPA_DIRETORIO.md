# Mapa do diretorio 16_MonitorFront

Consultas de produtos para o Monitor CissFront, usadas pela aplicacao de emissao de venda em frente de caixa.

## Objetivo

- Manter as consultas originais de captura de produtos.
- Manter versoes ajustadas para buscar produtos de todas as empresas da base.
- Centralizar notas de validacao das consultas neste diretorio.

## Arquivos

- `SelectProdutosComCenarioFiscal.txt`: consulta original para bases/formatos que usam tributacao por cenario fiscal.
- `SelectProdutosComCenarioFiscal_v2.txt`: versao ajustada para usar a CTE `EMPRESAS_BASE` e resolver filtros de empresa/UF por empresa da base.
- `SelectProdutosSemCenarioFiscal.txt`: consulta original para bases/formatos que usam tributacao sem cenario fiscal.
- `SelectProdutosSemCenarioFiscal_v2.txt`: versao ajustada para usar a CTE `EMPRESAS_BASE` e resolver filtros de empresa/UF por empresa da base.
- `Validacao_TSTPONTO_2026-07-23.md`: registro da validacao executada na base `TSTPONTO`, com tempos, volumes e observacoes.
- `validar_monitorfront_db2clp.ps1`: script de validacao via Db2 CLP; recebe a senha por parametro e nao a persiste em arquivo.
- `validar_monitorfront.ps1`: tentativa de validacao via ODBC com host/porta explicitos; mantido como apoio, mas a validacao efetiva foi feita pelo CLP.
- `MAPA_DIRETORIO.md`: mapa local do diretorio.

## Ajuste v2

- A CTE `EMPRESAS_BASE` consulta `DBA.EMPRESA` e fornece `IDEMPRESA` e `UF` para substituir os filtros fixos por `:RA_IDEMPRESA` e `:RA_UF`.
- Caso seja necessario processar somente algumas empresas, aplique o filtro diretamente dentro de `EMPRESAS_BASE`, por exemplo `WHERE EMPRESA.IDEMPRESA IN (...)`.
- Na consulta com cenario fiscal, a CTE tambem carrega campos fiscais necessarios aos joins ja existentes: `IDATIVIDADE`, `IDREGIMEESPECIAL` e `TIPOREGIMETRIBFEDERAL`.
- As funcoes e subconsultas dependentes de empresa passam a usar a empresa da linha corrente (`TMP.IDEMPRESA`, `PPP.IDEMPRESA`, `POLITICA_PRECO_PRODUTO.IDEMPRESA` ou `EMPRESA.IDEMPRESA`, conforme o escopo).
- Os joins auxiliares de empresa e mix por `DBA.PRODUTO_EMPRESA` tambem devem permanecer vinculados a `EMPRESAS_BASE`, para que filtros aplicados na CTE limitem todo o resultado.
- O parametro `:RA_DTMONITOR` foi mantido para controle incremental de alteracoes.
- O parametro `:RA_COMPLETA` foi mantido para preservar o comportamento original de carga completa/inativos.

## Base para validacao

- Host: `163.176.143.73`
- Banco: `TSTPONTO`
- Porta: `49470`
- Usuario: `dba`
- Senha: informada na demanda, nao registrada neste arquivo para evitar persistencia de credencial no repositorio.

## Regras locais

- Nao alterar os arquivos originais sem necessidade explicita.
- Criar novas versoes com sufixo ou prefixo de versao, mantendo o arquivo original como referencia.
- Ao validar em banco, registrar aqui apenas ambiente, data, resultado e observacoes, sem salvar senha ou dados sensiveis.
