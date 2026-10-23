# Importador de cartões — Windows x64

## Versão atual - 1.3.2

O botão **Criar tabelas** foi removido. O aplicativo não possui mais rotina de instalação de objetos, nem a opção `--install`. O executável não cria/atualiza tabelas, índices ou procedures. Os SQLs de implantação não ficam dentro do JAR.

**Objetos versionados em um único arquivo:** `sql/objetos_v1.3.2.sql` no pacote distribuído (fonte: `sql/releases/objetos_v1.3.2.sql`). Esse arquivo reúne as tabelas, índices, migrações, comentários e a SP V7 com commit a cada 100 avaliados. Deve ser executado manualmente pela equipe de banco, com separador `@`, em conexão dedicada e janela sem importações/processamento. A implantação verifica atividade da SP e checkpoint com sessão ativa, utiliza timeout zero e aborta em erro. Não chama a SP, não limpa os dados e não reinicia o cadastro/checkpoint existente.

No BIGSM já atualizado para V7, a troca do aplicativo não exige executar novamente o SQL. Em outros ambientes, provisionar os objetos antes de usar o importador. Preservar `config.properties` e `secret.key` na atualização. Evitar voltar a pacotes anteriores que ainda tinham o botão de implantação.

### Histórico das versões anteriores


Versão 1.3.1: instala a SP V7 (`sql/12_procedure_v7_checkpoint.sql`) e o controle `TMP.CARTOES_PROCESSAMENTO_CONTROLE` (`sql/11_migracao_checkpoint.sql`). **Commit a cada 100 registros avaliados**, inclusive o lote final parcial. O LOCK TABLE exclusivo dos processados foi removido. Se outra sessão já estiver processando, a nova chamada sai imediatamente, sem aguardar e sem alterar o checkpoint da execução em andamento; retorna aviso SQLSTATE 01000. A reserva atômica usa timeout zero somente na sua aquisição e restaura o valor anterior para processar. Uma desconexão deixa uma reserva órfã, recuperada na próxima chamada ao confirmar que a sessão proprietária não existe mais. Não há liberação automática baseada apenas no tempo decorrido. Todas as regras de valor bruto e status da V6 continuam.

**Implantação da V7:** aplicar `sql/11_migracao_checkpoint.sql` e depois `sql/12_procedure_v7_checkpoint.sql`, em conexão dedicada, sem uma execução anterior em andamento. O botão **Criar tabelas** do novo pacote instala essa versão, sem chamá-la. Pacotes antigos podem reinstalar SPs anteriores; atualizar a distribuição completa. Use `sql/13_consultar_checkpoint.sql` para consultar estado, último lote confirmado e contador. Esse contador inclui registros mantidos pendentes e não substitui os totais por status.


Versão 1.3.0: importa **Valor bruto** em `VALOR_BRUTO DECIMAL(15,2)` e o apresenta nos detalhes do relatório. A SP V6 (`sql/10_procedure_v6_valor_bruto.sql`) procura por **IDAUTORIZACAO + CNPJ + VALBRUTOESPERADO**, usando o valor bruto da planilha. As condições de CODESTABELECIMENTO e IDNSUHOST estão temporariamente comentadas no SELECT e no UPDATE; a validação numérica de NSU também fica comentada enquanto não participar da busca. A versão V5 permanece preservada. Os demais critérios, status e commits a cada mil linhas continuam vigentes.

**Atualização do banco para 1.3.0:** aplicar `sql/09_migracao_valor_bruto.sql` nas tabelas de entrada e processados e depois instalar a SP V6. O botão **Criar tabelas** faz essas alterações, mas não recupera os valores antigos nem chama a SP. Antes do processamento dos legados, recuperar o valor bruto das planilhas originais por hash, aba, linha e identificadores. O comando técnico `br.com.cartoes.Cli --backfill-values <planilhas>` preenche somente valores nulos nas duas tabelas, sem alterar status ou reabrir registros. Ele utiliza a variável de ambiente CARTOES_DB_PASSWORD. Não apague o controle de importações nem reenvie arquivos idênticos para essa recuperação. Terminal permitido com valor bruto ausente será arquivado com status 0, SQLSTATE 75004.


Versão 1.2.9: relatório inclui o rótulo **1 — Processado**, somente com a contagem, sem expandir registros nem consultar seus detalhes. O filtro usa **DTMOVIMENTO** e aplica as datas inicial e final, inclusive, aos totais, pendentes e páginas dos status 2, 3 e 4. O padrão é hoje e os nove dias anteriores (dez dias ao todo). Informe datas em dd/mm/aaaa e clique **Atualizar relatório**, ou use **Últimos 10 dias** para restaurar e aplicar o padrão. O período aplicado aparece acima da árvore e permanece o mesmo ao carregar as próximas páginas; alterações nos campos só entram na próxima atualização. Registros sem DTMOVIMENTO não entram em um filtro de datas.

Versão 1.2.8: relatório inclui **Pendentes de processamento**, consultados diretamente em `TMP.CARTOES_MOVIMENTO`, além dos status 2, 3 e 4 da tabela de processados. Pendentes têm detalhes de origem e paginação de 100 registros, mas não apresentam data nem contadores de processamento. **Atualizar relatório** refaz os totais e a árvore com a situação atual do banco.

Versão 1.2.7: relatório com os status **2, 3 e 4** e comentário da coluna `TMP.CARTOES_MOVIMENTO_PROCESSADOS.STATUS` descrevendo os cinco status. O comentário faz parte da migração 04 e também está disponível separadamente em `sql/08_comentario_status.sql`.

Versão 1.2.6: relatório ampliado para os status **2, 3 e 4**, incluindo **4 — Processado terminal diferente** na árvore, no total e nos detalhes. Todos usam carregamento em páginas de 100 registros. Status 1 permanece fora do relatório.

Versão 1.2.5: instala `sql/07_procedure_v5_for_with_hold.sql`, com varredura por FOR WITH HOLD, sem DECLARE CURSOR separado nem OPEN/FETCH/CLOSE manuais. O FOR usa o registro MOVIMENTO e mantém a varredura após cada commit de 1000 linhas. Os status 0 a 4, o cadastro de terminais e todas as regras anteriores continuam vigentes. O ícone personalizado permanece no executável e na janela. A SP continua sem execução automática pelo aplicativo.

Versão 1.2.4: ícone do executável e da janela alterado para a imagem de cartão fornecida. O ICO contém tamanhos de 16 a 256 pixels e a imagem da janela fica incluída no JAR.

Versão 1.2.3: instala a procedure V4 de `sql/06_procedure_v4_simplificada.sql`. O fluxo foi reduzido a selecionar, validar, atualizar e arquivar, com saídas antecipadas, uma única seleção da próxima linha e sem cursores ou SP auxiliar. Mantém os status 0 a 4, o cadastro de terminais, a comparação exata e os commits a cada 1000 linhas. As versões anteriores permanecem nos arquivos SQL.

Versão 1.2.2: inclui a procedure V3, que processa somente `NUMERO_MAQUINA` presente em `DBA.BIGSM_CADTERMINAL.CODTERMINAL`. Demais movimentos são arquivados com status **4 — Processado terminal diferente**, sem alterar o retorno. **Criar tabelas** cria o cadastro se ausente, amplia a restrição de status e instala a V3. Preencha o cadastro de terminais antes de executar a SP; ele não é populado automaticamente. A SP continua sem chamada automática pelo aplicativo. O relatório mantém somente os status 2 e 3, conforme solicitado.

Versão 1.2.1: **Criar tabelas** instala a procedure V2 (`sql/03_procedure_v2_sem_cursor.sql`), sem cursor de retorno e com comparação `CODTERMINAL = 'Nao identificado'`. Nulos e vazios continuam sendo preenchidos conforme a regra aprovada. A versão inicial está preservada em `sql/02_procedure.sql`.

Versão 1.2.0: interface em abas **Configuração**, **Monitoramento** (principal ao abrir) e **Relatório**. O relatório apresenta uma árvore somente com os status 2 e 3 e os detalhes de cada registro, incluindo data, CNPJ, autorização, NSU, máquina e arquivo. Expanda um status para carregar os primeiros 100 registros; use **Carregar mais 100** para continuar. **Atualizar relatório** refaz a consulta no banco, usando a configuração salva. As consultas rodam em segundo plano.

Versão 1.1.0: importa **Data da venda** para `DTMOVIMENTO` e inclui os scripts da tabela de processados e da procedure. Consulte `sql/README.md` para processar os registros no banco. A agenda do aplicativo continua responsável pela importação das planilhas; ela não chama a procedure de validação automaticamente.

Versão 1.0.3: botão **Limpar logs** limpa as mensagens exibidas no painel. O histórico na pasta `logs` é preservado e os próximos eventos continuam aparecendo normalmente.

Versão 1.0.2: runtime Java inclui os módulos `java.management`, `java.rmi` e `jdk.unsupported`, requeridos pelo driver DB2. Corrige a falha `javax/management/MalformedObjectNameException` no pacote portátil.

Versão 1.0.1: o teste de conexão registra início e resultado no painel e exibe uma janela de sucesso/falha, com limite de 15 segundos, independentemente da fila de importação. Cada ciclo registra início, resumo (encontradas, processadas, aguardando e erros) e término; a pasta vazia também gera mensagem.

Para atualizar, feche a versão anterior, extraia o novo ZIP e copie `config.properties` e `secret.key` da pasta antiga para junto do novo executável. Preserve o diretório de planilhas já configurado.

Extraia **toda** a pasta do ZIP em um diretório com permissão de gravação (por exemplo `C:\Aplicativos\ImportadorCartoes`). Abra `ImportadorCartoes.exe`. Java 17 e driver JDBC DB2 estão incluídos; não é necessário instalar clientes Java ou DB2. O executável deve permanecer junto das pastas `app` e `runtime`.

## Utilização

1. Escolha um diretório base. O aplicativo criará `Pendentes` e `Processadas` dentro dele.
2. Informe servidor, porta, banco, usuário, senha e intervalo (5 a 86400 segundos).
3. Use **Testar conexão**. Em outro banco, a equipe responsável deve implantar previamente `sql/objetos_v1.3.2.sql`; o aplicativo não provisiona objetos.
4. Na aba **Configuração**, clique **Salvar configurações**. Na aba **Monitoramento**, clique **Iniciar scheduler** e coloque arquivos `.xlsx` ou `.xls` em `Pendentes`. O processamento automático espera o arquivo permanecer com tamanho/data estáveis entre duas verificações, e ter ao menos cinco segundos de idade.
5. Na aba **Monitoramento**, **Executar agora** processa usando a última configuração salva, sem aguardar a estabilização entre ciclos. Termine a cópia/edição dos arquivos antes de clicar. **Parar scheduler** interrompe os próximos ciclos e permite concluir o atual. Salvar configurações com a scheduler em execução reaplica o intervalo e o diretório; se estiver parada, permanece parada. **Limpar logs** esvazia somente o painel.
6. Na aba **Relatório**, informe o período por **Data do movimento** e clique **Atualizar relatório**. O padrão são os últimos dez dias, incluindo hoje. Expanda **Pendentes de processamento** ou os status 2, 3 e 4 para ver os registros; o status 1 apresenta somente o rótulo com a contagem. Os pendentes vêm de TMP.CARTOES_MOVIMENTO. O status 0 da tabela de processados não faz parte desta tela.

O aplicativo precisa permanecer aberto para executar a agenda. Ao abrir novamente, carrega a configuração e retoma a agenda. Não é um serviço do Windows. Ao fechar, aguarda a transação em andamento terminar.

## Dados e recuperação

Os cabeçalhos são localizados por nome em cada aba, mesmo com linhas de apresentação acima da tabela. Mapeamento:

| Planilha | TMP.CARTOES_MOVIMENTO |
|---|---|
| Estabelecimento | ESTABELECIMENTO |
| CPF/CNPJ do estabelecimento | CNPJ (14 dígitos, sem pontuação) |
| Código de autorização | AUTORIZACAO |
| NSU/DOC | NSU |
| Número da máquina | NUMERO_MAQUINA |
| Data da venda | DTMOVIMENTO (DATE) |

Os cinco identificadores e a data da venda são obrigatórios. Identificadores são texto para preservar zeros já presentes na planilha. Abas sem cabeçalho reconhecido são ignoradas; arquivos sem vendas reconhecidas são rejeitados. Qualquer linha inválida rejeita o arquivo inteiro. Erros ficam no painel e em `logs/importador-AAAA-MM-DD.log`; o arquivo permanece em Pendentes para correção e nova tentativa.

Cada arquivo é validado em uma cópia temporária e gravado em uma única transação. Apenas após commit é movido para Processadas. Um SHA-256 registrado em `TMP.CARTOES_IMPORTACAO` evita importar novamente o mesmo conteúdo, mesmo renomeado, inclusive se houver falha na movimentação após commit. Um nome já existente em Processadas recebe prefixo único; nada é sobrescrito. Relatórios diferentes com vendas sobrepostas NÃO são deduplicados entre si: faltam data/hora na chave solicitada para determinar uma venda única com segurança.

Colunas técnicas ID, hash, aba, linha e data registram a origem. Não remova o histórico de importação se precisar manter a proteção contra repetição. As planilhas originais do diretório Cartões não são movidas automaticamente; envie as desejadas a Pendentes.

## Configuração e senha

`config.properties` fica junto ao executável. A senha é cifrada com AES-256-GCM, IV aleatório e autenticação. A chave está no arquivo `secret.key` ao lado; preserve ambos e restrinja o acesso à pasta pelo Windows aos operadores autorizados. Quem puder ler os dois arquivos poderá recuperar a senha. A distribuição não inclui credenciais nem configurações de produção. Configure a senha no primeiro uso. A conexão padrão usa JDBC TCP, sem TLS; redes que exigem TLS precisam de configuração adicional.

## Compilação

Requer JDK 17 x64 e Maven 3.9+, acesso ao Maven Central. Execute `powershell -File build.ps1 -Maven C:\caminho\mvn.cmd -Jdk C:\caminho\jdk-17`. A saída portátil fica em `dist/ImportadorCartoes-Windows-x64.zip`. Exclua ou renomeie a saída `dist/ImportadorCartoes` antes de reconstruir com jpackage. Esta distribuição contém um lançador `.exe`, não um instalador MSI.

Validação sem banco: `java -cp "target/importador-cartoes-1.0.0.jar;target/lib/*" br.com.cartoes.App --validate caminho.xlsx` e `--self-test`.

Referências de implementação: [Apache POI](https://poi.apache.org/components/spreadsheet/quick-guide.html), [jpackage](https://docs.oracle.com/en/java/javase/22/docs/specs/man/jpackage.html). Dependências declaradas no pom.xml; licenças dos componentes Java/JDBC/Apache permanecem nos artefatos distribuídos e devem ser observadas ao redistribuir.
