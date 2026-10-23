# Importador de cartões — apresentação da solução

**Referência:** aplicativo 1.3.2 e procedure V7.
**Data:** 22/10/2026.

## 1. Objetivo

A solução importa planilhas de vendas com cartões e utiliza os dados importados para identificar o terminal nas informações de retorno de contas a receber do banco DB2.

O processo possui duas etapas independentes:

1. **Aplicativo desktop:** recebe as planilhas, valida os dados, grava os movimentos em uma tabela de entrada e organiza os arquivos importados.
2. **Procedure no banco:** verifica os movimentos importados, atualiza os terminais permitidos e registra o resultado de cada processamento.

**O executável não chama automaticamente a procedure.** A execução manual e o agendamento disponíveis no aplicativo realizam a importação das planilhas. A procedure deve ser executada separadamente, de forma manual ou por um agendamento específico no ambiente do banco.

## 2. Visão geral do fluxo

```text
Planilhas colocadas em Pendentes
              |
              v
Aplicativo valida e importa os dados
              |
              +--> TMP.CARTOES_MOVIMENTO: movimentos aguardando validação
              |
              +--> Arquivo transferido para Processadas

Execução separada da procedure
              |
              v
Validação do cadastro de terminais e localização do retorno
              |
              +--> Atualização de CODTERMINAL, quando aplicável
              |
              +--> Resultado arquivado em TMP.CARTOES_MOVIMENTO_PROCESSADOS
              |
              +--> Movimentos recentes ainda sem retorno permanecem pendentes
```

**Uma planilha na pasta Processadas significa que seus dados foram importados.** Isso não significa que todos os movimentos já tiveram o terminal atualizado. A conclusão dessa segunda etapa é acompanhada pelos registros do banco e pelo relatório.

## 3. Instalação e requisitos

A distribuição é entregue em um arquivo ZIP para **Windows de 64 bits**. Deve-se extrair a pasta completa e executar `ImportadorCartoes.exe`.

O pacote inclui o ambiente Java e o driver JDBC do DB2. Portanto, não é necessário instalar Java ou um cliente DB2 na máquina do usuário.

Para funcionar, são necessários:

- Acesso de rede ao servidor DB2.
- Usuário de banco com as permissões correspondentes às operações utilizadas.
- Permissão de escrita na pasta do aplicativo e no diretório configurado para as planilhas.
- As tabelas e a procedure implantadas no banco.
- Cadastro dos terminais autorizados preenchido antes do processamento pela procedure.

O executável depende das pastas `app` e `runtime` que acompanham o pacote. Elas devem permanecer junto dele. O aplicativo precisa permanecer aberto para executar as importações automáticas; ele não é um serviço do Windows.

## 4. Configuração do aplicativo

### Aba Configuração

Permite informar e salvar:

| Configuração | Finalidade |
|---|---|
| Diretório base | Local em que serão organizadas as pastas de planilhas. |
| Servidor, porta e banco | Endereço de conexão com o DB2. |
| Usuário e senha | Credenciais utilizadas nas operações do aplicativo. |
| Intervalo de execução | Tempo entre os ciclos automáticos de importação, de 5 a 86.400 segundos. |

O botão **Testar conexão** apresenta o resultado em mensagem e no log, com limite de espera de 15 segundos na interface.

A configuração possui os botões **Salvar configurações** e **Testar conexão**. A implantação dos objetos fica a cargo da equipe de banco, por meio do arquivo SQL versionado `sql/objetos_v1.3.2.sql`, entregue separadamente do executável. O aplicativo não oferece botão ou comando para criar ou alterar tabelas e procedures.

As configurações ficam no arquivo `config.properties`, no diretório do aplicativo. A senha é armazenada com criptografia AES-256-GCM e a chave fica no arquivo `secret.key`. Os dois arquivos devem ser preservados juntos ao transferir as configurações para outra instalação. O acesso à pasta deve ser restrito, pois a posse dos dois arquivos permite recuperar a senha.

### Organização das planilhas

O diretório base utiliza esta estrutura:

```text
DiretorioConfigurado/
├── Pendentes/
└── Processadas/
```

Os arquivos a importar devem ser colocados em **Pendentes**. Após a gravação bem-sucedida no banco, o aplicativo os transfere para **Processadas**, sem sobrescrever arquivos existentes.

## 5. Importação das planilhas

O aplicativo aceita arquivos **`.xlsx` e `.xls`**. Arquivos ocultos e arquivos temporários de bloqueio são ignorados.

As colunas são identificadas pelos títulos do cabeçalho, sem depender de uma posição fixa de linha. Cada aba da planilha é examinada; abas sem o cabeçalho completo reconhecido são ignoradas.

| Coluna da planilha | Campo gravado no banco |
|---|---|
| Estabelecimento | `ESTABELECIMENTO` |
| CPF/CNPJ do estabelecimento | `CNPJ` |
| Código de autorização | `AUTORIZACAO` |
| NSU/DOC | `NSU` |
| Número da máquina | `NUMERO_MAQUINA` |
| Data da venda | `DTMOVIMENTO` |
| Valor bruto | `VALOR_BRUTO` |

A data da venda e o valor bruto são obrigatórios nas novas importações. O valor bruto é gravado como decimal com duas casas, sem arredondamento silencioso; valores inválidos ou fora da precisão permitida rejeitam o arquivo. O CNPJ é normalizado pela remoção da formatação e deve conter 14 dígitos. Os identificadores são tratados como texto para preservar os zeros à esquerda presentes na planilha.

Antes de gravar, o aplicativo valida os registros do arquivo. Se houver uma linha inválida, ou nenhum registro de venda reconhecido, a importação é rejeitada e o arquivo permanece em Pendentes, com o motivo registrado no log.

### Gravação e controle de duplicidade

Cada arquivo é gravado em uma única transação: os movimentos e o controle de importação são confirmados juntos. Se ocorrer uma falha antes da confirmação, as gravações daquele arquivo são desfeitas.

O aplicativo registra uma identificação SHA-256 do conteúdo binário do arquivo em `TMP.CARTOES_IMPORTACAO`. Isso evita importar novamente o mesmo arquivo, inclusive se ele for apenas renomeado. Caso a gravação tenha terminado e a movimentação física do arquivo falhe, uma nova tentativa reconhece a importação anterior e tenta concluir a transferência sem duplicar os movimentos.

Esse controle identifica arquivos iguais. Planilhas diferentes que contenham vendas repetidas não são automaticamente deduplicadas por venda.

### Execução automática e manual

Na execução automática, o aplicativo aguarda a estabilização do tamanho e da data de alteração do arquivo entre verificações, além de uma idade mínima de cinco segundos, para reduzir a possibilidade de ler uma cópia ainda em andamento.

A execução manual dispensa essa espera de estabilização. Por isso, a cópia e a edição da planilha devem estar concluídas antes de utilizar **Executar agora**.

## 6. Monitoramento da execução

A aba **Monitoramento** é a tela principal ao abrir o aplicativo. Ela apresenta o estado do agendamento, o último ciclo e os logs da execução.

| Ação | Comportamento |
|---|---|
| Iniciar scheduler | Inicia os ciclos automáticos de importação. |
| Parar scheduler | Impede os próximos ciclos; uma importação já iniciada pode concluir. |
| Executar agora | Solicita uma importação manual. Não chama a procedure. |
| Limpar logs | Limpa o conteúdo exibido na tela; os arquivos de log permanecem no disco. |

Cada ciclo gera mensagens, inclusive quando não existem arquivos pendentes. São registrados o início, as esperas por arquivos em estabilização, o resultado da importação, as falhas e o tempo de execução. Assim, o cliente consegue verificar que o aplicativo permanece ativo.

Os logs também ficam em `logs/importador-AAAA-MM-DD.log`, no diretório do aplicativo.

Não há importações simultâneas pelo mesmo aplicativo. O intervalo automático é contado após a conclusão do ciclo anterior.

Ao reabrir o aplicativo com uma configuração já salva, o agendamento é iniciado automaticamente. Na configuração inicial, após salvar, deve-se utilizar **Iniciar scheduler**. Salvar novas configurações enquanto o agendamento está parado não o inicia; se estiver ativo, as novas configurações são aplicadas aos próximos ciclos.

## 7. Processamento pela procedure

**Objeto:** `TMP.SP_PROCESSAR_CARTOES_MOVIMENTO()`
**Arquivo versionado de implantação:** `sql/objetos_v1.3.2.sql`, contendo a SP V7 e os demais objetos da solução.

A procedure percorre os movimentos com `FOR ... WITH HOLD`, sem comandos separados de abertura, leitura e fechamento de cursor. Ela confirma a transação a cada **100 registros avaliados** e confirma também o último lote incompleto.

A execução considera os movimentos existentes até o maior identificador capturado no início. Novos movimentos importados depois desse limite são tratados na próxima chamada.

### Controle de execução e acompanhamento

A tabela `TMP.CARTOES_PROCESSAMENTO_CONTROLE` impede a sobreposição de chamadas. Antes de processar, a SP reserva a execução de forma atômica. Se outra sessão já estiver executando, a nova chamada sai imediatamente, com um aviso, sem aguardar seu término e sem processar movimentos.

Essa reserva permanece válida entre os commits, sem bloquear exclusivamente a tabela de processados. O checkpoint registra início, última atualização, quantidade de linhas avaliadas e último identificador confirmado. Ele é atualizado junto com cada lote de 100 e com o lote final parcial. A quantidade inclui movimentos avaliados que permaneceram pendentes; não representa somente terminais alterados.

Ao concluir ou tratar uma falha fatal, a SP libera sua reserva. Se a conexão cair, uma próxima chamada pode recuperar a reserva após confirmar que a sessão anterior não existe mais. Uma execução longa não perde sua reserva apenas pelo tempo decorrido.

O script `sql/13_consultar_checkpoint.sql` permite acompanhar o controle. Ele usa leitura WITH UR, que não aguarda escritas no checkpoint e pode observar uma alteração ainda não confirmada. A remoção do bloqueio exclusivo permite acompanhar a tabela de processados, mantendo os bloqueios transacionais normais do banco.

### Etapa 1 — Validar o terminal permitido

O `NUMERO_MAQUINA` do movimento precisa existir no campo `CODTERMINAL` da tabela `DBA.BIGSM_CADTERMINAL`.

Se não existir, o movimento é transferido para a tabela de processados com **status 4 — Processado terminal diferente**, sem atualizar o retorno de contas a receber. Essa verificação ocorre antes das demais regras, inclusive da espera de cinco dias.

O cadastro possui os campos `IDEMPRESA` e `CODTERMINAL`. Nesta versão, a autorização é feita pelo código do terminal; `IDEMPRESA` não participa do vínculo com a planilha. Os códigos devem ser cadastrados no formato esperado, preservando eventuais zeros à esquerda.

**O cadastro não é preenchido automaticamente. Se estiver vazio, todos os movimentos avaliados serão classificados com status 4.**

### Etapa 2 — Localizar o retorno correspondente

Para um terminal permitido, a procedure valida a data e a presença do valor bruto e procura o movimento em `DBA.CLW_RETORNO_CONTAS_RECEBER` usando simultaneamente:

| Movimento importado | Retorno de contas a receber |
|---|---|
| `AUTORIZACAO` | `IDAUTORIZACAO` |
| `CNPJ` | `CNPJ` |
| `VALOR_BRUTO` | `VALBRUTOESPERADO` |

O valor bruto é comparado por igualdade exata em DECIMAL(15,2), sem tolerância de centavos. As comparações de `ESTABELECIMENTO` com `CODESTABELECIMENTO` e de `NSU` com `IDNSUHOST` estão temporariamente comentadas na consulta e na atualização, devido a divergências nesses campos. Eles continuam importados e disponíveis para auditoria. Como o NSU não participa da busca nesta versão, a SP não exige sua conversão numérica. A data do movimento é usada somente na regra de prazo.

Movimentos legados sem valor bruto precisam ter o valor recuperado da planilha original antes do processamento. Para terminais permitidos, a falta desse valor gera status 0 com mensagem específica; não é assumido um valor zero.

### Etapa 3 — Atualizar o terminal quando necessário

Quando o retorno é encontrado, o campo `CODTERMINAL` recebe o `NUMERO_MAQUINA` importado somente se o valor atual for:

- Exatamente **`Nao identificado`**, respeitando maiúsculas e minúsculas.
- Nulo.
- Vazio ou composto apenas por espaços.

Se ocorrer pelo menos uma atualização, o movimento é arquivado com **status 1 — Processado**.

Se o retorno já possuir um terminal preenchido com outro valor, esse valor é preservado. Quando nenhum retorno correspondente necessita de alteração, o movimento é arquivado com **status 2 — Processado e não alterado**.

Caso existam vários retornos com as mesmas três chaves, são atualizados os que atendem à regra acima. Os terminais já identificados são preservados. O resultado registra as quantidades encontradas e alteradas; havendo alguma alteração, o status é 1.

A atualização realizada por essa rotina no retorno é restrita ao campo `CODTERMINAL`.

### Etapa 4 — Tratar movimentos sem retorno

Se nenhum retorno for encontrado:

- O movimento permanece em `TMP.CARTOES_MOVIMENTO` enquanto sua data não for anterior à data atual menos cinco dias.
- Quando a data for **estritamente anterior** a esse limite, ele é arquivado com **status 3 — Processado e não encontrado**.

O prazo é calculado pela **data da venda (`DTMOVIMENTO`)**, não pela data de importação. Um movimento com exatamente cinco dias ainda permanece pendente. Por exemplo, em uma execução no dia 22, um movimento do dia 17 permanece pendente, enquanto um do dia 16 já ultrapassou o prazo.

Os movimentos mantidos na tabela de entrada serão reavaliados na próxima execução da procedure.

### Etapa 5 — Registrar erros

Uma falha individual desfaz as alterações daquela linha e tenta arquivá-la com **status 0 — Com erro**, incluindo código, estado SQL e mensagem do erro. Após o arquivamento, a linha é removida da entrada e o processamento prossegue.

Falhas que impeçam também o registro do erro podem interromper a procedure e desfazer o lote ainda não confirmado. Os lotes já confirmados permanecem gravados.

Registros arquivados com erro não são tentados novamente automaticamente. Eles precisam de análise e de um reprocessamento controlado após a correção da causa.

## 8. Significado dos resultados

| Situação / status | Significado | Local após a avaliação |
|---|---|---|
| Pendente | Terminal permitido, mas retorno ainda não encontrado e prazo não ultrapassado; também inclui movimentos ainda não avaliados. | `TMP.CARTOES_MOVIMENTO` |
| 0 — Com erro | Ocorreu uma falha no tratamento do movimento. | `TMP.CARTOES_MOVIMENTO_PROCESSADOS` |
| 1 — Processado | Pelo menos um terminal foi atualizado. | `TMP.CARTOES_MOVIMENTO_PROCESSADOS` |
| 2 — Processado e não alterado | Retorno encontrado, sem necessidade de substituir o terminal preenchido. | `TMP.CARTOES_MOVIMENTO_PROCESSADOS` |
| 3 — Processado e não encontrado | Retorno não localizado e data da venda anterior ao limite de cinco dias. | `TMP.CARTOES_MOVIMENTO_PROCESSADOS` |
| 4 — Processado terminal diferente | Número da máquina ausente no cadastro de terminais permitidos. | `TMP.CARTOES_MOVIMENTO_PROCESSADOS` |

Os movimentos arquivados são removidos da tabela de entrada. A tabela de processados mantém o resultado e os dados de origem, incluindo arquivo, aba, linha, datas e quantidades encontradas/alteradas. A coluna `STATUS` possui comentário no banco com a descrição dos códigos.

“Processado” como arquivamento não significa sempre sucesso de atualização: os códigos permitem distinguir sucesso, ausência de alteração, ausência de retorno, terminal não autorizado e erro.

## 9. Relatório no aplicativo

A aba **Relatório** consulta a situação atual no banco e organiza os dados em uma árvore de grupos.

| Grupo | Apresentação |
|---|---|
| Pendentes de processamento | Contagem e detalhamento dos movimentos ainda na tabela de entrada. |
| Status 1 — Processado | Somente rótulo e contagem; não carrega os registros individuais. |
| Status 2 — Processado e não alterado | Contagem e registros detalhados. |
| Status 3 — Processado e não encontrado | Contagem e registros detalhados. |
| Status 4 — Processado terminal diferente | Contagem e registros detalhados. |

O status 0 não é exibido nessa aba e deve ser consultado no banco pela equipe de suporte.

Ao selecionar um registro detalhado, o usuário pode consultar seus identificadores, data do movimento, valor bruto, máquina, origem na planilha e informações do processamento. Os registros são carregados em páginas de 100, com opção de carregar mais.

### Filtro por período

O filtro utiliza **DTMOVIMENTO**, com as datas inicial e final incluídas no período. O padrão é **hoje e os nove dias anteriores**, totalizando dez datas.

O usuário pode alterar as datas no formato `dd/mm/aaaa` e aplicar com **Atualizar relatório** ou Enter. O botão **Últimos 10 dias** restaura e aplica o período padrão.

As contagens e os detalhes utilizam o mesmo período. Registros antigos podem não aparecer no padrão de dez dias; para consultá-los, amplie o intervalo. Registros legados sem `DTMOVIMENTO` não aparecem no filtro por data.

Atualizar o relatório apenas consulta os dados: não importa planilhas nem executa a procedure.

## 10. Rotina de operação recomendada

### Preparação

1. Extrair o pacote completo do aplicativo.
2. A equipe responsável deve implantar os objetos pelo arquivo `sql/objetos_v1.3.2.sql`, em uma janela sem importações ou processamento da SP e usando conexão dedicada. O script reúne os objetos e migrações, recusa implantação quando identifica uma execução ativa e usa timeout zero para não aguardar locks. Em ambiente já atualizado para V7, basta substituir o aplicativo. Movimentos legados sem valor bruto exigem recuperação pelas planilhas originais, sem reenviar arquivos para duplicar importações.
3. Preencher e conferir `DBA.BIGSM_CADTERMINAL` antes de chamar a procedure.
4. Configurar diretório, conexão e intervalo; salvar e testar a conexão.
5. Definir quem executará a procedure ou configurar um agendamento separado para ela.

### Operação diária

1. Manter o aplicativo aberto e conferir se o scheduler está ativo.
2. Colocar as planilhas concluídas na pasta Pendentes.
3. Acompanhar os logs e a transferência dos arquivos para Processadas.
4. Executar a procedure pelo mecanismo definido para o banco.
5. Atualizar o relatório e verificar pendências e resultados, ajustando o período quando necessário.
6. Encaminhar erros ou divergências à equipe responsável, com os dados do registro e os logs correspondentes.

As duas frequências são independentes: o intervalo configurado na interface controla somente a importação. A frequência da procedure depende do agendamento definido fora do aplicativo.

### Tratamento de ocorrências

| Ocorrência | Orientação |
|---|---|
| Arquivo permanece em Pendentes | Consultar o log; verificar conteúdo, cópia em andamento e acesso ao banco. |
| Arquivo foi movido, mas há movimentos pendentes | A importação terminou; verificar a execução da procedure e a disponibilidade dos retornos. |
| Status 2 | Conferir o terminal já existente, caso seja necessária análise da divergência. |
| Status 3 | Investigar as três chaves de localização e a existência do retorno. |
| Status 4 | Conferir o número da máquina e o cadastro de terminais permitidos. |
| Status 0 | Consultar os diagnósticos no banco e corrigir a causa antes de planejar o reprocessamento. |
| Registro não aparece no relatório | Conferir o período e a data do movimento; erros de status 0 exigem consulta no banco. |

Corrigir o cadastro não reabre automaticamente os registros já arquivados com status 4. Da mesma forma, reenviar um arquivo idêntico não reimporta seus movimentos, devido ao controle de duplicidade. Reprocessamentos de registros arquivados devem ser conduzidos pela equipe responsável.

## 11. Referência para a equipe técnica

### Objetos envolvidos

| Objeto | Responsabilidade |
|---|---|
| `TMP.CARTOES_PROCESSAMENTO_CONTROLE` | Reserva da execução e checkpoint dos lotes. |
| `TMP.CARTOES_IMPORTACAO` | Histórico e identificação dos arquivos importados para controle de duplicidade. |
| `TMP.CARTOES_MOVIMENTO` | Fila de movimentos aguardando processamento ou retorno. |
| `TMP.CARTOES_MOVIMENTO_PROCESSADOS` | Histórico dos movimentos avaliados e seus resultados. |
| `DBA.BIGSM_CADTERMINAL` | Cadastro dos terminais permitidos. |
| `DBA.CLW_RETORNO_CONTAS_RECEBER` | Retornos consultados e destino da atualização de `CODTERMINAL`. |
| `TMP.SP_PROCESSAR_CARTOES_MOVIMENTO()` | Aplicação das regras de validação, atualização e arquivamento. |

### Chamada da procedure

```sql
CALL TMP.SP_PROCESSAR_CARTOES_MOVIMENTO();
```

Utilizar uma conexão dedicada, sem outras alterações pendentes, pois a procedure realiza commits internos. A solução não instala automaticamente um agendamento dessa chamada no banco.

### Consulta de erros para suporte

```sql
SELECT
    ID,
    DTMOVIMENTO,
    ESTABELECIMENTO,
    CNPJ,
    AUTORIZACAO,
    NSU,
    NUMERO_MAQUINA,
    SQLSTATE_ERRO,
    SQLCODE_ERRO,
    MENSAGEM_ERRO,
    PROCESSADO_EM
FROM TMP.CARTOES_MOVIMENTO_PROCESSADOS
WHERE STATUS = 0
ORDER BY PROCESSADO_EM DESC;
```

### Atualização do aplicativo

Fechar a versão anterior, extrair integralmente a nova distribuição e preservar juntos `config.properties` e `secret.key`. Manter o diretório de planilhas e os logs necessários ao histórico operacional. Não substituir apenas o arquivo `.exe`, pois a aplicação utiliza os demais componentes do pacote.

O arquivo `sql/objetos_v1.3.2.sql` é a referência versionada para implantação. Ele pode ser repetido sem limpar os dados e preserva o cadastro e o checkpoint existentes; não chama a SP. Os documentos `README.md` e `VALIDACAO.md` complementam esta apresentação com instruções e registros de validação técnica.
