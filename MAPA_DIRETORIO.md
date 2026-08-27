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
- `19_DtFim_TabSinteticas`: Scripts e resumo tecnico de DTFIM em tabelas sinteticas.
- `Cards`: Anotacoes rapidas e listas de acompanhamento.

## Arquivos imediatos

- `'`: Arquivo de apoio, evidencia ou saida avulsa.
- `')`: Arquivo de apoio, evidencia ou saida avulsa.
- `.gitignore`: Regras de arquivos ignorados pelo Git.
- `_alter_log_reprocessa_dtfim_tmp.sql`: Script SQL de consulta, DDL, DML, function, trigger, view ou procedure.
- `_consulta_log_reprocessa_dtfim_tmp.sql`: Script SQL de consulta, DDL, DML, function, trigger, view ou procedure.
- `_deploy_dtfim_01_add_columns.sql`: Script SQL de deploy, manutencao ou validacao de DTFIM.
- `_deploy_dtfim_02_create_backfill_objects.sql`: Script SQL de deploy, manutencao ou validacao de DTFIM.
- `_deploy_dtfim_03_backfill_estoque_sintetico.sql`: Script SQL de deploy, manutencao ou validacao de DTFIM.
- `_deploy_dtfim_03b_backfill_estoque_sintetico_setbased.sql`: Script SQL de deploy, manutencao ou validacao de DTFIM.
- `_deploy_dtfim_04_backfill_contabil_saldo.sql`: Script SQL de deploy, manutencao ou validacao de DTFIM.
- `_deploy_dtfim_05_backfill_movimento_custo.sql`: Script SQL de deploy, manutencao ou validacao de DTFIM.
- `_deploy_dtfim_05b_backfill_movimento_custo_setbased.sql`: Script SQL de deploy, manutencao ou validacao de DTFIM.
- `_deploy_dtfim_06_backfill_produto_custo.sql`: Script SQL de deploy, manutencao ou validacao de DTFIM.
- `_deploy_dtfim_07_create_indexes.sql`: Script SQL de deploy, manutencao ou validacao de DTFIM.
- `_deploy_dtfim_08_create_maintenance_objects.sql`: Script SQL de deploy, manutencao ou validacao de DTFIM.
- `_deploy_dtfim_09_set_not_null.sql`: Script SQL de deploy, manutencao ou validacao de DTFIM.
- `_deploy_dtfim_10_validation.sql`: Script SQL de deploy, manutencao ou validacao de DTFIM.
- `_deploy_sp_reprocessa_dtfim_tmp_log.sql`: Script SQL de deploy, manutencao ou validacao de DTFIM.
- `_tmp_apps_nop48.sql`: Script SQL temporario de inspecao, apoio ou validacao.
- `_tmp_consulta_log_antigo.sql`: Script SQL temporario de inspecao, apoio ou validacao.
- `_tmp_count_log_reprocessa.sql`: Script SQL temporario de inspecao, apoio ou validacao.
- `_tmp_db2look_dba.sql`: Script SQL temporario de inspecao, apoio ou validacao.
- `_tmp_describe_locks.sql`: Script SQL temporario de inspecao, apoio ou validacao.
- `_tmp_describe_routines.sql`: Script SQL temporario de inspecao, apoio ou validacao.
- `_tmp_export_routines.sql`: Script SQL temporario de inspecao, apoio ou validacao.
- `_tmp_find_trigger_blocker.sql`: Script SQL temporario de inspecao, apoio ou validacao.
- `_tmp_inspect_triggers.sql`: Script SQL temporario de inspecao, apoio ou validacao.
- `_tmp_inspect_update_triggers.sql`: Script SQL temporario de inspecao, apoio ou validacao.
- `_tmp_lockwait_log_reprocessa.sql`: Script SQL temporario de inspecao, apoio ou validacao.
- `_tmp_lockwait_log_reprocessa_v2.sql`: Script SQL temporario de inspecao, apoio ou validacao.
- `_tmp_noponto_preflight.sql`: Script SQL temporario de inspecao, apoio ou validacao.
- `_tmp_progress_dtfim.sql`: Script SQL temporario de inspecao, apoio ou validacao.
- `_tmp_routines.del`: Resultado ou evidencia em formato DEL.
- `_valida_assinatura_sp_reprocessa_dtfim_tmp.sql`: Script SQL de validacao ou revalidacao.
- `_valida_sp_reprocessa_dtfim_tmp.sql`: Script SQL de validacao ou revalidacao.
- `1`: Arquivo de apoio, evidencia ou saida avulsa.
- `guia_plano_acesso_sql_performance.md`: Documentacao tecnica ou registro de analise.
- `MAPA_DIRETORIO.md`: Mapa local do diretorio.
- `revalidar_divisao_estrutura_NOP48.out`: Saida de execucao, resultado ou evidencia de validacao.
- `revalidar_divisao_estrutura_NOP48.sql`: Script SQL de validacao ou revalidacao.
- `revalidar_estrutura_mercadologica.out`: Saida de execucao, resultado ou evidencia de validacao.
- `revalidar_estrutura_mercadologica.sql`: Script SQL de validacao ou revalidacao.
- `revalidar_estrutura_mercadologica_NOP48.out`: Saida de execucao, resultado ou evidencia de validacao.
- `top10_fornecedores_notas_compra.sql`: Script SQL de consulta, DDL, DML, function, trigger, view ou procedure.
- `UF_PRODUTOS_SALDO_ESTOQUE_EMPRESA.sql`: Script SQL de consulta, DDL, DML, function, trigger, view ou procedure.
- `validacao_baixas_contabil_queiroz.csv`: Resultado ou evidencia em formato CSV.
- `validacao_baixas_contabil_queiroz.del`: Resultado ou evidencia em formato DEL.
- `validacao_baixas_contabil_queiroz.sql`: Script SQL de validacao ou revalidacao.
- `validar_estrutura_mercadologica.out`: Saida de execucao, resultado ou evidencia de validacao.
- `validar_estrutura_mercadologica.sql`: Script SQL de validacao ou revalidacao.
- `validar_estrutura_mercadologica_detalhe.out`: Saida de execucao, resultado ou evidencia de validacao.
- `validar_estrutura_mercadologica_detalhe.sql`: Script SQL de validacao ou revalidacao.
- `validar_estrutura_mercadologica_fk.out`: Saida de execucao, resultado ou evidencia de validacao.
- `validar_estrutura_mercadologica_fk.sql`: Script SQL de validacao ou revalidacao.
- `validar_estrutura_mercadologica_pos_rollback.out`: Saida de execucao, resultado ou evidencia de validacao.
- `validar_estrutura_mercadologica_pos_rollback.sql`: Script SQL de validacao ou revalidacao.
- `validar_estrutura_mercadologica_transacao_teste.out`: Saida de execucao, resultado ou evidencia de validacao.
- `validar_estrutura_mercadologica_transacao_teste.sql`: Script SQL de validacao ou revalidacao.

## Inventario de diretorios

| Diretorio | Arquivos | Subdiretorios | Mapa local | Assunto |
| --- | ---: | ---: | --- | --- |
| `.agents` | 1 | 0 | sim | Arquivos locais de apoio a agentes do workspace. |
| `.codex` | 1 | 0 | sim | Arquivos locais de configuracao e apoio do Codex neste workspace. |
| `.vscode` | 3 | 0 | sim | Configuracoes do Visual Studio Code para o projeto. |
| `00_referencias` | 3 | 0 | sim | Referencias de ambiente, conexoes e bases acessiveis. |
| `01_padroes_sql` | 6 | 0 | sim | Padroes de desenvolvimento, formatacao e boas praticas SQL. |
| `02_taxas_administradoras` | 5 | 0 | sim | Arquitetura e objetos de historico de taxas de administradoras. |
| `03_produto_fornecedor` | 3 | 0 | sim | Consultas e analises de produto x fornecedor. |
| `04_pedido_compra` | 5 | 0 | sim | Procedures, views e ajustes de pedido de compra. |
| `05_wms` | 5 | 0 | sim | Integracao WMS, conferencia de pedido e views de entrada. |
| `06_cenario_fiscal` | 2 | 0 | sim | Cenario fiscal e origem do produto. |
| `07_validade_fifo` | 2 | 0 | sim | Controle de validade FIFO. |
| `08_tickets_ciss` | 36 | 0 | sim | Scripts, evidencias e documentacao vinculados a tickets CISS. |
| `09_catalogo_dbadmin` | 2 | 1 | sim | Exportacao e catalogo do DbAdmin. |
| `09_catalogo_dbadmin\dbadmin_catalog` | 1 | 0 | sim | Saida do catalogo exportado do DbAdmin. |
| `10_integracoes_integrin` | 2 | 0 | sim | Integracoes INTEGRIM/Integrin. |
| `11_Artigos` | 8 | 0 | sim | Artigos, estudos e resumos tecnicos. |
| `12_CONTROL` | 2 | 0 | sim | Demandas e scripts da aplicacao Control. |
| `14_DRE_Caixa` | 3 | 0 | sim | Consultas e estudos de DRE de caixa. |
| `15_CMC` | 7 | 0 | sim | Objetos de custo medio de compra. |
| `16_MonitorFront` | 9 | 1 | sim | Consultas e propostas para Monitor CissFront. |
| `16_MonitorFront\Arquitetura_Cache_CenarioFiscal` | 7 | 0 | sim | Arquitetura proposta de cache de cenario fiscal. |
| `17_GEFOX` | 5 | 0 | sim | Ajustes e documentacoes do projeto GEFOX. |
| `18_Validação_Notas` | 24 | 1 | sim | Mapa local do diretorio 18_Validação_Notas. |
| `18_Validação_Notas\Formato 19 - Consultas Individuais` | 13 | 0 | sim | Mapa local do diretorio Formato 19 - Consultas Individuais. |
| `19_DtFim_TabSinteticas` | 3 | 0 | sim | Scripts e resumo tecnico de DTFIM em tabelas sinteticas. |
| `Cards` | 3 | 0 | sim | Anotacoes rapidas e listas de acompanhamento. |

## Regras locais

- Atualize este mapa quando diretorios forem criados, removidos ou reclassificados.
- Atualize os mapas locais quando arquivos forem adicionados, removidos ou renomeados.
