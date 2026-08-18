# Mapa do diretorio BancoDeDados

## Objetivo

Mapa central do projeto BancoDeDados.

## Regras gerais

- Mantenha na raiz apenas arquivos de mapa/controle geral e diretorios de trabalho.
- Nao registre credenciais, senhas ou dados sensiveis nos mapas.
- Preserve o nome original dos scripts SQL para facilitar busca por objeto, ticket ou rotina.
- Ao criar novo script, coloque-o primeiro na pasta do assunto; se o assunto ainda nao existir, crie uma pasta numerada e registre aqui.
- Cada diretorio deve manter seu proprio `MAPA_DIRETORIO.md` atualizado.

## Atalho operacional: `VersioneGit`

Quando o usuario digitar exatamente a expressao `VersioneGit`, executar a verificacao e o versionamento Git dos diretorios de trabalho conhecidos no workspace.

- Verificar branch, remote, arquivos modificados, arquivos novos e arquivos removidos.
- Revisar o diff antes do commit e nao incluir credenciais, caches, dependencias ou saidas temporarias indevidas.
- Quando houver rotina de validacao do projeto, executa-la antes do commit.
- Criar commit com mensagem objetiva em portugues e publicar no remote configurado com `git push`.
- Se o remote estiver ausente, incorreto, sem autenticacao ou rejeitar envio, informar o bloqueio sem forcar historico.

## Subdiretorios imediatos

- `.agents`: Arquivos locais de apoio a agentes do workspace.
- `.codex`: Arquivos locais de configuracao e apoio do Codex neste workspace.
- `.vscode`: Configuracoes do Visual Studio Code para o projeto.
- `00_referencias`: Referencias de ambiente, conexoes e bases acessiveis.
- `01_padroes_sql`: Padroes de desenvolvimento, formatacao e boas praticas SQL.
- `02_taxas_administradoras`: Arquitetura e objetos de historico de taxas de administradoras.
- `03_produto_fornecedor`: Consultas e analises de produto x fornecedor.
- `04_pedido_compra`: Procedures, views e ajustes de pedido de compra.
- `05_wms`: Integracao WMS, conferencia de pedido e views de entrada.
- `06_cenario_fiscal`: Cenario fiscal e origem do produto.
- `07_validade_fifo`: Controle de validade FIFO.
- `08_tickets_ciss`: Scripts, evidencias e documentacao vinculados a tickets CISS.
- `09_catalogo_dbadmin`: Exportacao e catalogo do DbAdmin.
- `10_integracoes_integrin`: Integracoes INTEGRIM/Integrin.
- `11_Artigos`: Artigos, estudos e resumos tecnicos.
- `12_CONTROL`: Demandas e scripts da aplicacao Control.
- `14_DRE_Caixa`: Consultas e estudos de DRE de caixa.
- `15_CMC`: Objetos de custo medio de compra.
- `16_MonitorFront`: Consultas e propostas para Monitor CissFront.
- `17_GEFOX`: Ajustes e documentacoes do projeto GEFOX.
- `18_Validação_Notas`: Validacao de notas fiscais e comparativos tributarios.
- `Cards`: Anotacoes rapidas e listas de acompanhamento.

## Arquivos imediatos

- `.gitignore`: Regras de arquivos ignorados pelo Git.
- `MAPA_DIRETORIO.md`: Mapa local do diretorio.
- `top10_fornecedores_notas_compra.sql`: Script SQL de consulta, DDL, DML, function, trigger, view ou procedure.
- `UF_PRODUTOS_SALDO_ESTOQUE_EMPRESA.sql`: Script SQL de consulta, DDL, DML, function, trigger, view ou procedure.
- `validacao_baixas_contabil_queiroz.csv`: Resultado ou evidencia em formato CSV.
- `validacao_baixas_contabil_queiroz.del`: Resultado ou evidencia em formato DEL.
- `validacao_baixas_contabil_queiroz.sql`: Script SQL de consulta, DDL, DML, function, trigger, view ou procedure.

## Inventario de diretorios

| Diretorio | Arquivos | Subdiretorios | Mapa local | Assunto |
| --- | ---: | ---: | --- | --- |
| `.agents` | 1 | 0 | sim | Arquivos locais de apoio a agentes do workspace. |
| `.codex` | 1 | 0 | sim | Arquivos locais de configuracao e apoio do Codex neste workspace. |
| `.vscode` | 3 | 0 | sim | Configuracoes do Visual Studio Code para o projeto. |
| `00_referencias` | 3 | 0 | sim | Referencias de ambiente, conexoes e bases acessiveis. |
| `01_padroes_sql` | 6 | 0 | sim | Padroes de desenvolvimento, formatacao e boas praticas SQL. |
| `02_taxas_administradoras` | 5 | 0 | sim | Arquitetura e objetos de historico de taxas de administradoras. |
| `03_produto_fornecedor` | 2 | 0 | sim | Consultas e analises de produto x fornecedor. |
| `04_pedido_compra` | 5 | 0 | sim | Procedures, views e ajustes de pedido de compra. |
| `05_wms` | 5 | 0 | sim | Integracao WMS, conferencia de pedido e views de entrada. |
| `06_cenario_fiscal` | 2 | 0 | sim | Cenario fiscal e origem do produto. |
| `07_validade_fifo` | 2 | 0 | sim | Controle de validade FIFO. |
| `08_tickets_ciss` | 30 | 0 | sim | Scripts, evidencias e documentacao vinculados a tickets CISS. |
| `09_catalogo_dbadmin` | 2 | 1 | sim | Exportacao e catalogo do DbAdmin. |
| `09_catalogo_dbadmin\dbadmin_catalog` | 1 | 0 | sim | Saida do catalogo exportado do DbAdmin. |
| `10_integracoes_integrin` | 2 | 0 | sim | Integracoes INTEGRIM/Integrin. |
| `11_Artigos` | 6 | 0 | sim | Artigos, estudos e resumos tecnicos. |
| `12_CONTROL` | 2 | 0 | sim | Demandas e scripts da aplicacao Control. |
| `14_DRE_Caixa` | 3 | 0 | sim | Consultas e estudos de DRE de caixa. |
| `15_CMC` | 7 | 0 | sim | Objetos de custo medio de compra. |
| `16_MonitorFront` | 12 | 0 | sim | Consultas e propostas para Monitor CissFront. |
| `17_GEFOX` | 5 | 0 | sim | Ajustes e documentacoes do projeto GEFOX. |
| `18_Validação_Notas` | 12 | 0 | sim | Validacao de notas fiscais e comparativos tributarios. |
| `Cards` | 3 | 0 | sim | Anotacoes rapidas e listas de acompanhamento. |

## Regras locais

- Atualize este mapa quando diretorios forem criados, removidos ou reclassificados.
- Atualize os mapas locais quando arquivos forem adicionados, removidos ou renomeados.
