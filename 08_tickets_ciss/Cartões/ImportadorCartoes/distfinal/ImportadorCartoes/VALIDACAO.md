# Validação — 22/10/2026

## Versão 1.3.2 - implantação separada do aplicativo - 22/10/2026

- Botão Criar tabelas e seu listener removidos; removidos Database.install, Database.exists e o comando --install da CLI. Código Java sem CREATE/ALTER/DROP de objetos.
- SQLs de implantação excluídos dos recursos do JAR. Build limpo evita recursos antigos remanescentes. Pacote entrega um único arquivo de implantação versionado e a consulta de checkpoint separada.
- Release `sql/releases/objetos_v1.3.2.sql` validada em 9 verificações DB2 com objetos isolados: criação completa, compilação da SP, repetição preservando dados/cadastro/checkpoint, recusa com sessão ativa e restauração do timeout em sucesso/erro. Objetos de teste removidos ao final.
- Nenhum DDL aplicado aos objetos reais no BIGSM para esta alteração. As regras da SP V7 permanecem e o aplicativo não a chama.
- Compilação limpa Maven / Java 17 e pacote Windows 1.3.2 concluídos. JAR inspecionado: nenhum recurso .sql, nenhum botão Criar tabelas, nenhum comando --install e nenhuma rotina de instalação de objetos.
- Apresentação de cliente em Markdown/PDF atualizada para implantação manual; PDF de nove páginas renderizado e revisado.


## Versão 1.3.1 / SP V7 - 22/10/2026

- 22 verificações de regressão da SP em objetos isolados, com valor bruto, status 0 a 4, precisão da busca, tratamento de erro e checkpoint. Migração 11 executada duas vezes para validar idempotência.
- 13 verificações de concorrência com conexões independentes: segunda chamada sai em menos de dois segundos com a primeira pausada depois de um commit; tabela de processados consultável; reserva permanece ativa após o commit; disputa por linha do checkpoint também sai sem aguardar; timeout original restaurado.
- Commit de exatamente 100 registros confirmado e último lote de uma linha confirmado em cenário de 101 movimentos. Checkpoint indica total 101 e último ID 101.
- Sessão viva com reserva antiga preservada; reserva órfã recuperada somente após desconexão; falha fatal libera reserva, registra diagnóstico e permite nova execução.
- Todos esses testes usaram tabelas e procedures isoladas removidas ao final, sem processar retornos reais.
- Implantação no BIGSM: checkpoint criado livre (EM_EXECUCAO=N) e SP V7 válida (VALID=Y). Mantidos 358 pendentes e 3.231 processados; nenhuma chamada da rotina real feita na implantação.
- Compilação Maven / Java 17 e pacote Windows 1.3.1 concluídos. Documentação de cliente atualizada e PDF de nove páginas renderizado e revisado.


## Versão 1.3.0 / SP V6 - 22/10/2026

- Compilação Java 17 / Maven concluída.
- 18 verificações de leitura monetária: XLS/XLSX, números, formato brasileiro, moeda, fórmula com resultado numérico, zeros iniciais, precisão, limites, zero e negativos. Valores inválidos rejeitados sem arredondamento silencioso.
- Cinco planilhas fornecidas lidas: 3.589 vendas, valor bruto total 652.718,22.
- 20 verificações DB2 em objetos isolados, removidos ao final: busca por valor bruto apesar de NSU/estabelecimento divergentes, valor diferente não atualizado, CNPJ e autorização obrigatórios, status 0 a 4, terminal literal/nulo/vazio, histórico preserva valor bruto, rollback da linha em falha e commit intermediário de 1.000 linhas.
- Testes da SP não atualizaram retornos reais. A implantação da definição da procedure não executa seu processamento.
- BIGSM: migração aplicada, valor bruto recuperado por origem em 3.589 registros (358 pendentes e 3.231 arquivados), sem alterar status. SP V6 instalada com VALID=Y; não chamada sobre os movimentos reais.
- Valor bruto de 300 registros retornados pelo repositório do relatório conferido diretamente com as tabelas, somente por leitura.
- Executável Windows 1.3.0 gerado com Java e JDBC incluídos; teste de conexão realizado com sucesso pelo próprio executável.
- Apresentação Markdown e PDF atualizada para V6; nove páginas renderizadas e revisadas.


## Atualização 1.2.9 — período e status 1 resumido

- Status 1 incluído somente como rótulo com contagem, sem filhos na árvore, sem detalhes e sem consulta paginada de seus registros.
- Filtro por DTMOVIMENTO com datas inclusivas, padrão hoje e nove dias anteriores. Aplicado a todos os totais, pendentes e páginas dos status 2/3/4. Período aplicado mantido na paginação até nova atualização.
- 21 verificações em tabelas isoladas: fronteiras inicial/final, dados fora do intervalo, datas nulas, período vazio, um dia, sucesso somente em contagem, paginação 100+8 com filtro fixo, alteração/aplicação de datas, rejeição de datas inválidas/intervalo invertido e restauração dos últimos dez dias. Objetos de teste removidos.
- Interface renderizada e inspecionada. Compilação concluída e pacote 1.2.9 gerado, com ícone e SP V5 preservados. Nenhum movimento real processado.

## Atualização 1.2.8 — pendentes no relatório

- Primeiro grupo da árvore: Pendentes de processamento, consultado diretamente em TMP.CARTOES_MOVIMENTO e incluído no total geral. Mantidos status 2, 3 e 4 dos processados.
- Detalhes dos pendentes mostram dados de origem e mantêm data/contadores de processamento vazios, sem criar status no banco. Paginação de 100 registros pelo ID.
- 25 verificações em tabelas isoladas, incluindo 107 pendentes (100+7), um pendente legado sem data, totais, ausência de duplicação, detalhes com zeros preservados, contadores nulos e manutenção do status 4. A contagem dos pendentes permaneceu igual depois das consultas; objetos de teste removidos.
- Interface renderizada e inspecionada. Compilação concluída e ZIP verificado por CRC; consultas de pendentes/status 2/3/4, ícone e SP V5 conferidos no pacote 1.2.8. Nenhum movimento real processado.

## Atualização 1.2.7 — status 4 no relatório e comentário

- Relatório ampliado para status 2, 3 e 4 na consulta, totais, árvore e descrição dos detalhes; rótulos centralizados para evitar apresentar status 4 como status 3.
- 13 verificações com dados em tabelas isoladas: 107 registros no status 4, três no 2, dois no 3, exclusão de 0/1, paginação 100+7 sem duplicação e detalhes preservando zeros. Interface renderizada e inspecionada. Tabelas de teste removidas.
- Comentário da coluna TMP.CARTOES_MOVIMENTO_PROCESSADOS.STATUS gravado e consultado no catálogo do BIGSM, com descrição dos status 0 a 4. Comentário presente na migração 04 e no script independente 08_comentario_status.sql.
- Compilação concluída e ZIP 1.2.7 verificado por CRC. Filtro 2/3/4, recursos SQL, comentário, SP V5 e ícone conferidos no pacote. Nenhuma SP de processamento executada sobre movimentos reais.

## Atualização 1.2.5 — FOR WITH HOLD

- Novo arquivo sql/07_procedure_v5_for_with_hold.sql. Varredura por FOR MOVIMENTO AS C_MOVIMENTO INSENSITIVE CURSOR WITH HOLD FOR, sem declaração separada nem OPEN/FETCH/CLOSE manuais.
- O registro é acessado por MOVIMENTO.CAMPO. INSENSITIVE preserva o conjunto selecionado ao remover linhas; WITH HOLD preserva a varredura através dos commits de 1000 linhas. O limite de ID continua excluindo novas importações da chamada atual.
- 28 verificações passaram em tabelas isoladas, incluindo todos os status, comparação exata, cadastro de terminais, rollback por linha, processamento além da primeira milésima linha, pendentes, reexecução e interrupção após commit intermediário.
- Todos os objetos de teste removidos. Nenhum movimento real processado nos testes.
- Provisionamento do aplicativo 1.2.5 passa a instalar a V5; todas as versões anteriores permanecem preservadas. O ícone personalizado é mantido.

## Atualização 1.2.4 — ícone

- Imagem do link fornecido baixada e convertida, sem cortes, em PNG para a janela e ICO com sete tamanhos de 16 a 256 pixels.
- Ícone definido no jpackage e em JFrame.setIconImages. Imagem incluída no JAR; não depende da URL em tempo de execução.
- Compilação concluída; ZIP, ICO distribuído, PNG no JAR e referência do recurso na classe App verificados. Ícone extraído do próprio executável para conferência visual.

## Atualização 1.2.3 — procedure V4 simplificada

- Novo arquivo sql/06_procedure_v4_simplificada.sql, preservando as versões anteriores. Uma procedure, um WHILE, sem cursores nem rotinas auxiliares.
- Redução de 198 para 141 linhas, uma única seleção para buscar a próxima linha e validações com saídas antecipadas em lugar de IFs aninhados. Classificação por CASE e COUNT de terminais sem identificação.
- Mantidos cadastro de terminais, status 0 a 4, comparação exata, prazo estrito de cinco dias, arquivamento, rollback por linha e commits a cada 1000 avaliados.
- 27 verificações passaram em tabelas isoladas, incluindo interrupção após o primeiro commit para comprovar o lote intermediário. Todos os objetos de teste foram removidos; os movimentos reais não foram processados.
- O provisionamento do aplicativo 1.2.3 instala a V4.

## Atualização 1.2.2 — cadastro de terminais e status 4

- Nova versão preservada em sql/05_procedure_v3_cadastro_terminal.sql. Somente NUMERO_MAQUINA presente em DBA.BIGSM_CADTERMINAL.CODTERMINAL segue para as regras de retorno; os demais são arquivados com status 4 antes da busca/atualização do retorno.
- Migração sql/04_migracao_status4.sql cria o cadastro com a estrutura fornecida, se ausente, e amplia a restrição de status. Nenhum terminal é inserido automaticamente.
- 27 verificações em tabelas isoladas: migração repetida sem perda de dados, terminais cadastrados/não cadastrados/duplicados, status 4 sem atualizar o retorno, quatro status anteriores, comparação exata, rollback por linha e commit intermediário de 1000 avaliados.
- Objetos de teste removidos; vendas reais não processadas nos testes. Cadastro usa somente CODTERMINAL, pois o movimento não dispõe de IDEMPRESA.
- O provisionamento do aplicativo 1.2.2 passa a instalar a migração e a V3, sem chamar a SP de processamento. Relatório continua limitado aos status 2 e 3.
- Migração e V3 publicadas no BIGSM; procedure válida e restrição de status 0 a 4 confirmadas. Cadastro criado e consultado: zero registros. Preencher os códigos antes da execução operacional; a SP não foi chamada sobre os movimentos reais.
- ZIP 1.2.2, recursos SQL e referências de provisionamento no JAR verificados.

## Atualização 1.2.1 — procedure V2

- Novo arquivo sql/03_procedure_v2_sem_cursor.sql, com indentação e um único WHILE; nenhum cursor declarado ou aberto, inclusive para resumo de retorno.
- Comparação direta CODTERMINAL = 'Nao identificado', mantendo nulos/vazios conforme regra aprovada. Variações de caixa e acento preservadas como status 2.
- 23 verificações em tabelas isoladas: status, diagnósticos, rollback por linha, reexecução e comparação exata. Interrupção controlada após o primeiro commit confirmou que 1000 linhas avaliadas foram confirmadas e o lote seguinte não foi processado.
- Objetos de teste removidos. Procedure V2 instalada e válida no BIGSM, sem processar vendas reais.
- Versão inicial sql/02_procedure.sql preservada byte a byte; SHA-256: 0c6d98e89fea28413960073a91426829573f3c541a6c9b8ee6b618abac39bf3b.
- Aplicativo 1.2.1 passa a instalar a V2 pelo botão Criar tabelas. ZIP, recursos SQL e referência do provisionamento no JAR verificados.

## Atualização 1.2.0 — abas e relatório

- Monitoramento selecionada por padrão, com estado da scheduler, último ciclo, iniciar, parar, execução manual e limpar logs.
- Configuração separada; salvar mantém a scheduler parada quando estava parada e reaplica a configuração se estiver em execução.
- Relatório somente dos status 2 e 3, árvore de registros e detalhes, páginas de 100 itens e consultas em segundo plano.
- 20 verificações com tabelas isoladas: 205 registros no status 2, três no status 3 e exemplos de status 0/1 excluídos. Paginação sem duplicação, detalhes preservando zeros, estado dos botões, inicialização, limpeza de logs e mensagem de falha de conexão verificados.
- Tabelas de teste removidas. As três abas foram renderizadas e inspecionadas visualmente.
- ZIP 1.2.0 verificado por CRC.

## Atualização 1.1.0 — processamento no banco

- Criados DTMOVIMENTO DATE na origem, TMP.CARTOES_MOVIMENTO_PROCESSADOS e TMP.SP_PROCESSAR_CARTOES_MOVIMENTO no BIGSM (DB2 LUW 11.5.9).
- Procedure compilada e válida. Testada com 1013 linhas em tabelas isoladas e 15 verificações: quatro status, pendentes recentes, limite exato de cinco dias, NSU numérico com zeros, múltiplas correspondências, dois lotes commitados e reexecução sem duplicação.
- Erro forçado após atualização de terminal e antes do arquivamento confirmou rollback da atualização e registro do status 0 com SQLSTATE, SQLCODE e mensagem.
- Todos os objetos de teste foram removidos. Nenhum CODTERMINAL real foi alterado pelos testes.
- Executável 1.1.0 com runtime incluído leu 3589 linhas nas cinco planilhas, incluindo Data da venda como LocalDate.
- O mesmo executável recuperou e commitou DTMOVIMENTO de 396 movimentos legados, conferindo SHA-256, aba, linha e os cinco identificadores.
- ZIP e scripts SQL verificados por CRC. A procedure de produção foi instalada, mas não foi chamada para processar as vendas reais.

## Atualização 1.0.3

- Incluído botão Limpar logs, que esvazia somente o painel de mensagens e preserva os arquivos de histórico.
- Compilação Java concluída. Agenda e importação mantêm o funcionamento durante a limpeza.

## Atualização 1.0.2

- `jdeps` aplicado ao driver JCC identificou java.management, java.rmi e jdk.unsupported; todos incluídos no runtime portátil.
- Executado o próprio `dist-1.0.2/ImportadorCartoes/ImportadorCartoes.exe --connection-test`, usando o Java incluído, com conexão real ao BIGSM e consulta `VALUES CURRENT SERVER`: sucesso, saída 0.
- Executado o próprio EXE com `--validate` nas cinco planilhas: 3589 registros lidos, saída 0. Sem gravação ou movimentação dos originais.
- Verificados o CRC do ZIP e a presença dos módulos no runtime dentro do ZIP.

## Atualização 1.0.1

- Verificadas na interface as mensagens de início e resultado do teste de conexão, tanto para porta local indisponível quanto para conexão bem-sucedida ao BIGSM.
- Os dois cenários foram executados com a fila de importação ocupada artificialmente: o teste de conexão concluiu independentemente dela.
- Verificados os logs de ciclo automático sem arquivos, resumo de contadores, término e espera por estabilização de arquivo.
- Interface atualizada renderizada para inspeção. Compilação concluída e ZIP da versão 1.0.1 verificado por CRC.
- Os testes de conexão não gravaram dados no banco.

- Compilação Java 17 / Maven: concluída.
- Criadas e consultadas no BIGSM (10.250.4.45:50013): TMP.CARTOES_MOVIMENTO e TMP.CARTOES_IMPORTACAO.
- Leitura das cinco planilhas fornecidas: 396, 1033, 483, 1509 e 168 linhas, total 3589. Zeros iniciais de autorização e máquina preservados; CNPJ convertido em 14 dígitos.
- AES-GCM: gravação, carregamento, troca de senha e ausência da senha em texto claro no arquivo de configuração verificados.
- DB2: inserção dos cinco campos, preservação de zeros, rejeição de NSU nulo e rollback integral do histórico e das linhas verificados. Nenhum dado de teste mantido.
- Interface Swing renderizada e inspecionada visualmente.
- Executável Windows gerado por jpackage; executado com sucesso usando seu runtime incluído (autoteste de configuração/criptografia, saída 0).
- ZIP portátil verificado integralmente por CRC.

As planilhas originais não foram importadas nem movidas. O fluxo completo de agenda/movimentação com commit de vendas reais ainda depende do primeiro uso operacional. O teste de banco usou rollback para não gravar vendas de teste.
