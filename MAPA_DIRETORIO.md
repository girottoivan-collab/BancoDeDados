# Mapa do diretorio BancoDeDados

Este arquivo centraliza a organizacao do diretorio principal e indica onde cada assunto/objeto deve ficar.

## Regras gerais

- Mantenha na raiz apenas arquivos de mapa/controle geral e diretorios de trabalho.
- Nao mova `.git`, `.agents` e `.vscode`; eles sao pastas de suporte do workspace.
- Preserve o nome original dos scripts SQL para facilitar busca por objeto, ticket ou rotina.
- Ao criar novo script, coloque-o primeiro na pasta do assunto. Se o assunto ainda nao existir, crie uma pasta numerada e registre aqui.
- Scripts relacionados ao mesmo prompt, ticket ou solucao devem ficar juntos, mesmo quando misturam `FUNCTION`, `TRIGGER`, `VIEW` e documentacao.
- Backups pontuais devem ficar ao lado do objeto principal, com sufixo de data ou contexto.
- Cada diretorio de trabalho deve manter seu proprio `MAPA_DIRETORIO.md` com objetivo, arquivos e regras locais.

## Estrutura

| Diretorio | Assunto | Instrucoes |
| --- | --- | --- |
| `00_referencias` | Referencias de ambiente, conexoes e bases acessiveis | Use para notas de infraestrutura, catalogos de conexao e informacoes que apoiam mais de um assunto. Nao registrar senhas. |
| `01_padroes_sql` | Padrao de desenvolvimento e formatacao SQL | Use para guias, exemplos base, configuracoes de formatter e convencoes de DDL/DML. Consulte antes de reformatar scripts. |
| `02_taxas_administradoras` | Arquitetura e objetos de historico de taxas de administradoras | Use para documentacao, DER e objetos SQL da solucao de taxas por administradora/bandeira/parcela. |
| `03_produto_fornecedor` | Consulta e analise de produto x fornecedor | Use para consultas, evidencias e CSVs relacionados a produto, fornecedor, precificacao e analises de SQL corrente desse tema. |
| `04_pedido_compra` | Procedure, views e ajustes de pedido de compra | Use para `SP_INSERT_PEDIDO_COMPRA_PROD`, views GEA, backups ou versoes de apoio das rotinas de pedido de compra. |
| `05_wms` | Integracao WMS, conferencia de pedido e views de entrada | Use para funcoes, triggers e views que controlam uso de WMS ou geram entrada WMS. |
| `06_cenario_fiscal` | Cenario fiscal e origem do produto | Use para funcoes e consultas relacionadas a busca de origem fiscal, composicao de cenario e regras fiscais por produto/empresa. |
| `07_validade_fifo` | Controle de validade FIFO | Use para procedures e estudos de consumo/saldo por validade em ordem FIFO. |
| `08_tickets_ciss` | Scripts vinculados a tickets CISS | Use para scripts identificados por numero de ticket, especialmente quando alteram mais de uma tabela ou regra. |
| `09_catalogo_dbadmin` | Exportacao/catalogo do DbAdmin | Use para scripts e resultados exportados do catalogo DbAdmin. Atualizacoes devem manter script e saida juntos. |
| `10_integracoes_integrin` | Integracoes INTEGRIM/Integrin | Use para funcoes e migrations ligadas ao schema `INTEGRIM` e a rotinas de integracao externa. |
| `11_Artigos` | Artigos e resumos tecnicos | Use para textos, resumos e estudos que nao sejam scripts executaveis de banco. |
| `12_CONTROL` | Demandas e scripts da aplicacao Control | Use para alteracoes vinculadas ao Control, incluindo scripts de DDL/DML e procedures auxiliares. |
| `14_DRE_Caixa` | Consultas e estudos de DRE de caixa | Use para scripts de DRE, visoes sinteticas e comparativos de totais relacionados a caixa. |
| `15_CMC` | Objetos de custo medio de compra | Use para tabelas, funcoes, procedures e triggers relacionadas ao processamento de CMC. |

## Arquivos por diretorio

### `00_referencias`

- `MAPA_DIRETORIO.md`: mapa local do diretorio.
- `BASES_ACESSIVEIS.md`: conexoes Db2 e SQLTools identificadas no ambiente.

### `01_padroes_sql`

- `MAPA_DIRETORIO.md`: mapa local do diretorio.
- `.sql-formatter.json`: configuracao do formatter SQL.
- `SQL_FORMATTING_GUIDELINES.md`: diretrizes de indentacao e estilo SQL.
- `ExemploBaseIdentacao.sql`: exemplo base de indentacao SQL.
- `PadraoDevBD.sql`: regras gerais de desenvolvimento de banco.

### `02_taxas_administradoras`

- `MAPA_DIRETORIO.md`: mapa local do diretorio.
- `ArquiteturaTaxasAdministradoras.md`: desenho funcional/tecnico da solucao.
- `DER_TaxasAdministradoras.svg`: diagrama visual do modelo.
- `ADMINISTRADORAS_BANDEIRA_TAXA_HISTORICO.sql`: script completo da tabela historica, function de consulta e configuracao.
- `UF_ADMIN_BANDEIRA_TAXA_DATA.sql`: function de consulta de taxa por data historica.

### `03_produto_fornecedor`

- `MAPA_DIRETORIO.md`: mapa local do diretorio.
- `ConsultaProdutoxFornecedor.sql`: consulta principal de produto x fornecedor.

### `04_pedido_compra`

- `MAPA_DIRETORIO.md`: mapa local do diretorio.
- `SP_INSERT_PEDIDO_COMPRA_PROD.sql`: procedure principal.
- `SP_INSERT_PEDIDO_COMPRA_PROD_bkp10072026.sql`: backup datado da procedure.
- `VW_GEA_PEDIDO_COMPRA.sql`: view de pedido de compra para integracao GEA.
- `VW_GEA_PEDIDO_COMPRA_ALTERADO.sql`: view alterada de pedido de compra para integracao GEA.

### `05_wms`

- `MAPA_DIRETORIO.md`: mapa local do diretorio.
- `UF_CONFERE_PEDIDO_UTILIZA_WMS.sql`: function que decide uso de WMS na conferencia de pedido.
- `TR_INS_CONFPED_PERSON.sql`: trigger de insercao em conferencia de pedido.
- `V_WMS_ENTRADA.sql`: view WMS de entrada.
- `V_WMS_ENTRADA_V2.sql`: segunda versao da view WMS de entrada.

### `06_cenario_fiscal`

- `MAPA_DIRETORIO.md`: mapa local do diretorio.
- `UF_ORIGEM_PRODUTO_CENARIO_FISCAL.sql`: function para resolver origem do produto no cenario fiscal.

### `07_validade_fifo`

- `MAPA_DIRETORIO.md`: mapa local do diretorio.
- `ControleValidadeFIFO.sql`: procedure de processamento de validade FIFO.

### `08_tickets_ciss`

- `MAPA_DIRETORIO.md`: mapa local do diretorio.
- `CISS-172088.sql`: script associado ao ticket CISS-172088.
- `CISS-174814.sql`: script associado ao ticket CISS-174814.
- `CISS-175870.sql`: script associado ao ticket CISS-175870.

### `09_catalogo_dbadmin`

- `MAPA_DIRETORIO.md`: mapa local do diretorio.
- `export_dbadmin_catalog.ps1`: script de exportacao do catalogo.
- `dbadmin_catalog/`: saida/catalogo exportado.

### `10_integracoes_integrin`

- `MAPA_DIRETORIO.md`: mapa local do diretorio.
- `V46__function_set_item_pedido_integrin_v2.sql`: migration/function `INTEGRIM.SET_ITEM_PEDIDO_INTEGRIN_V2`.

### `11_Artigos`

- `MAPA_DIRETORIO.md`: mapa local do diretorio.
- `resumo_9_must_have_skills_for_codex_2026.md`: resumo tecnico sobre skills essenciais para Codex em 2026.

### `12_CONTROL`

- `MAPA_DIRETORIO.md`: mapa local do diretorio.
- `SP_ATUALIZA_QTDALTERACOESMANUAIS_CONFERE_PEDIDO.sql`: script para criar o campo `QTDALTERACOESMANUAIS`, atualizar nulos em lotes e aplicar `NOT NULL`.

### `14_DRE_Caixa`

- `MAPA_DIRETORIO.md`: mapa local do diretorio.
- `DRE_Novo.sql`: consulta/script principal da nova DRE de caixa.
- `DRE_Novo_sintetico_totais.sql`: versao sintetica com totais da nova DRE de caixa.

### `15_CMC`

- `MAPA_DIRETORIO.md`: mapa local do diretorio.
- `ObjetosCMC.sql`: objetos para processamento de custo medio de compra, incluindo tabelas, indices, function, procedure e triggers.
