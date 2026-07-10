# Mapa do diretorio BancoDeDados

Este arquivo centraliza a organizacao do diretorio principal e indica onde cada assunto/objeto deve ficar.

## Regras gerais

- Mantenha na raiz apenas arquivos de mapa/controle geral e diretorios de trabalho.
- Nao mova `.git`, `.agents` e `.vscode`; eles sao pastas de suporte do workspace.
- Preserve o nome original dos scripts SQL para facilitar busca por objeto, ticket ou rotina.
- Ao criar novo script, coloque-o primeiro na pasta do assunto. Se o assunto ainda nao existir, crie uma pasta numerada e registre aqui.
- Scripts relacionados ao mesmo prompt, ticket ou solucao devem ficar juntos, mesmo quando misturam `FUNCTION`, `TRIGGER`, `VIEW` e documentacao.
- Backups pontuais devem ficar ao lado do objeto principal, com sufixo de data ou contexto.
- Arquivos temporarios/bloqueados devem ser movidos para a pasta correta assim que forem liberados pelo aplicativo que os estiver usando.

## Estrutura

| Diretorio | Assunto | Instrucoes |
| --- | --- | --- |
| `00_referencias` | Referencias de ambiente, conexoes e bases acessiveis | Use para notas de infraestrutura, catalogos de conexao e informacoes que apoiam mais de um assunto. Nao registrar senhas. |
| `01_padroes_sql` | Padrao de desenvolvimento e formatacao SQL | Use para guias, exemplos base, configuracoes de formatter e convencoes de DDL/DML. Consulte antes de reformatar scripts. |
| `02_taxas_administradoras` | Arquitetura e objetos de taxas de administradoras por vigencia | Use para documentacao, DER e objetos SQL da solucao de taxas por administradora/bandeira/parcela. |
| `03_produto_fornecedor` | Consulta e analise de produto x fornecedor | Use para consultas, evidencias e CSVs relacionados a produto, fornecedor, precificacao e analises de SQL corrente desse tema. |
| `04_pedido_compra` | Procedure, views e ajustes de pedido de compra | Use para `SP_INSERT_PEDIDO_COMPRA_PROD`, views GEA, backups ou versoes de apoio das rotinas de pedido de compra. |
| `05_wms` | Integracao WMS, conferencia de pedido e views de entrada | Use para funcoes, triggers e views que controlam uso de WMS ou geram entrada WMS. |
| `06_cenario_fiscal` | Cenario fiscal e origem do produto | Use para funcoes e consultas relacionadas a busca de origem fiscal, composicao de cenario e regras fiscais por produto/empresa. |
| `07_validade_fifo` | Controle de validade FIFO | Use para procedures e estudos de consumo/saldo por validade em ordem FIFO. |
| `08_tickets_ciss` | Scripts vinculados a tickets CISS | Use para scripts identificados por numero de ticket, especialmente quando alteram mais de uma tabela ou regra. |
| `09_catalogo_dbadmin` | Exportacao/catalogo do DbAdmin | Use para scripts e resultados exportados do catalogo DbAdmin. Atualizacoes devem manter script e saida juntos. |
| `10_integracoes_integrin` | Integracoes INTEGRIM/Integrin | Use para funcoes e migrations ligadas ao schema `INTEGRIM` e a rotinas de integracao externa. |

## Arquivos por diretorio

### `00_referencias`

- `BASES_ACESSIVEIS.md`: conexoes Db2 e SQLTools identificadas no ambiente.

### `01_padroes_sql`

- `.sql-formatter.json`: configuracao do formatter SQL.
- `SQL_FORMATTING_GUIDELINES.md`: diretrizes de indentacao e estilo SQL.
- `ExemploBaseIdentacao.sql`: exemplo base de indentacao SQL.
- `PadraoDevBD.sql`: regras gerais de desenvolvimento de banco.

### `02_taxas_administradoras`

- `ArquiteturaTaxasAdministradoras.md`: desenho funcional/tecnico da solucao.
- `DER_TaxasAdministradoras.svg`: diagrama visual do modelo.
- `TR_ADMIN_BANDEIRA_TAXA_VIGENCIA.sql`: trigger da solucao de vigencia.
- `UF_ADMIN_BANDEIRA_TAXA_DATA.sql`: function de consulta de taxa por data/vigencia.

### `03_produto_fornecedor`

- `ConsultaProdutoxFornecedor.sql`: consulta principal de produto x fornecedor.

Observacao: o arquivo original `moncurrentsqlNOPONTO.csv` permaneceu temporariamente na raiz porque estava bloqueado por outro processo no momento da organizacao.

### `04_pedido_compra`

- `SP_INSERT_PEDIDO_COMPRA_PROD.sql`: procedure principal.
- `SP_INSERT_PEDIDO_COMPRA_PROD_bkp10072026.sql`: backup datado da procedure.
- `VW_GEA_PEDIDO_COMPRA.sql`: view de pedido de compra para integracao GEA.
- `VW_GEA_PEDIDO_COMPRA_ALTERADO.sql`: view alterada de pedido de compra para integracao GEA.

### `05_wms`

- `UF_CONFERE_PEDIDO_UTILIZA_WMS.sql`: function que decide uso de WMS na conferencia de pedido.
- `TR_INS_CONFPED_PERSON.sql`: trigger de insercao em conferencia de pedido.
- `V_WMS_ENTRADA.sql`: view WMS de entrada.
- `V_WMS_ENTRADA_V2.sql`: segunda versao da view WMS de entrada.

### `06_cenario_fiscal`

- `UF_ORIGEM_PRODUTO_CENARIO_FISCAL.sql`: function para resolver origem do produto no cenario fiscal.

### `07_validade_fifo`

- `ControleValidadeFIFO.sql`: procedure de processamento de validade FIFO.

### `08_tickets_ciss`

- `CISS-174814.sql`: script associado ao ticket CISS-174814.
- `CISS-175870.sql`: script associado ao ticket CISS-175870.

### `09_catalogo_dbadmin`

- `export_dbadmin_catalog.ps1`: script de exportacao do catalogo.
- `dbadmin_catalog/`: saida/catalogo exportado.

### `10_integracoes_integrin`

- `V46__function_set_item_pedido_integrin_v2.sql`: migration/function `INTEGRIM.SET_ITEM_PEDIDO_INTEGRIN_V2`.
