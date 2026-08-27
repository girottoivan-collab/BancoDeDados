# Proposta com controle de pendencia

## Objetivo

Materializar os dados fiscais usados pela consulta com cenario fiscal do Monitor CissFront e controlar o reprocessamento por duas tabelas:

- `DBA.MONITORFRONT_CENFIS_PENDENTE`: contem somente produtos ainda pendentes.
- `DBA.MONITORFRONT_CENFIS_HISTORICO`: registra o que foi processado e qual origem gerou o processamento.

Com isso, a pendencia deixa de misturar estado atual e auditoria. O que precisa processar fica em uma tabela pequena; o rastro operacional fica no historico.

## Tabela cache

Tabela: `DBA.PRODUTO_GRADE_CENARIO_FISCAL`

Finalidade:

- armazenar o resultado fiscal ja resolvido;
- substituir, na consulta online, os joins com `PRODUTO_TRIBUTACAO_CENARIO_VIEW`, `ATIVIDADE_TIPO_ATIVIDADE` e `CENARIO_FISCAL_PADRAO_PRODUTO_VW`;
- permitir join direto por `IDEMPRESA`, `IDPRODUTO` e `IDSUBPRODUTO`.

Chave primaria:

- `IDEMPRESA`
- `IDPRODUTO`
- `IDSUBPRODUTO`

Campos fiscais cacheados:

- `IDCENARIOFISCAL`
- `PERICMSAI`
- `TIPO_ANTECIPACAO`
- `IDSITTRIBSAI`
- `PERREDTRIBSAI`
- `PERICMECF`
- `UFORIGEM`
- `CENFISDTALTERACAO`
- `FLAGEVIDENCIAC`
- `ICMS_FCEP`

## Tabela de pendentes

Tabela: `DBA.MONITORFRONT_CENFIS_PENDENTE`

Finalidade:

- manter apenas os produtos que ainda precisam ser processados;
- evitar duplicidade para a mesma chave;
- servir como lista enxuta de trabalho para a rotina agendada.

Chave primaria:

- `IDEMPRESA`
- `IDPRODUTO`
- `IDSUBPRODUTO`

Campos:

- `IDEMPRESA`: empresa impactada.
- `IDPRODUTO`: produto impactado.
- `IDSUBPRODUTO`: subproduto impactado.
- `DTPENDENCIA`: data/hora em que a chave entrou ou voltou para pendencia.
- `ORIGEM`: origem mais recente que marcou a chave como pendente, por exemplo `EMPRESA`, `CENARIO_FISCAL_INSERT` ou `CENARIO_FISCAL_UPDATE`.

Comportamento:

- trigger faz `MERGE` na tabela de pendentes;
- se a chave nao existe, insere;
- se a chave ja existe, atualiza `DTPENDENCIA` e `ORIGEM`;
- apos processamento com sucesso, a chave e removida da tabela de pendentes.

## Tabela de historico

Tabela: `DBA.MONITORFRONT_CENFIS_HISTORICO`

Finalidade:

- registrar cada processamento concluido;
- preservar a origem que gerou a pendencia;
- permitir auditoria sem manter registros ja processados na tabela de pendentes.

Chave primaria:

- `IDHISTORICO`

Campos:

- `IDHISTORICO`: identificador sequencial do historico.
- `IDEMPRESA`: empresa processada.
- `IDPRODUTO`: produto processado.
- `IDSUBPRODUTO`: subproduto processado.
- `DTPENDENCIA`: data/hora em que a chave foi marcada como pendente.
- `DTPROCESSAMENTO`: data/hora em que a chave foi processada.
- `ORIGEM`: origem da pendencia processada.

## Procedure de atualizacao do cache

Procedure: `DBA.SP_MONITORFRONT_ATUALIZA_CENFIS`

Finalidade:

- recalcular o cache fiscal para uma chave especifica;
- usar a regra fiscal atual como fonte de verdade;
- gravar o resultado em `DBA.PRODUTO_GRADE_CENARIO_FISCAL` por `MERGE`.

Na proposta com pendencia, a chamada normal e feita por:

- `IDEMPRESA`
- `IDPRODUTO`
- `IDSUBPRODUTO`

## Procedure de processamento

Procedure: `DBA.SP_MONITORFRONT_PROCESSA_PEND_CENFIS`

Finalidade:

- buscar as chaves existentes em `DBA.MONITORFRONT_CENFIS_PENDENTE`;
- limitar o lote por `PI_QTDLOTE`;
- chamar `SP_MONITORFRONT_ATUALIZA_CENFIS` para cada chave;
- gravar o processamento em `DBA.MONITORFRONT_CENFIS_HISTORICO`;
- remover a chave processada de `DBA.MONITORFRONT_CENFIS_PENDENTE`.

Essa procedure deve ser chamada por uma aplicacao ou agendador continuo.

## Trigger em empresa

Trigger: `DBA.TR_MONFRONT_CENFIS_EMPRESA_AU`

Evento:

- `AFTER UPDATE OF UF, IDATIVIDADE, IDREGIMEESPECIAL, TIPOREGIMETRIBFEDERAL`

Regra:

- dispara apenas quando algum dos quatro campos realmente mudar;
- busca na `DBA.CENARIO_FISCAL_PADRAO_PRODUTO_VW` todos os produtos padrao vinculados a empresa alterada;
- faz `MERGE` em `DBA.MONITORFRONT_CENFIS_PENDENTE` para cada chave encontrada.

## Triggers em cenario fiscal

Tabela: `DBA.CENARIO_FISCAL`

Triggers:

- `DBA.TR_MONFRONT_CENFIS_CENARIO_AI`: dispara no cadastro de novo cenario fiscal.
- `DBA.TR_MONFRONT_CENFIS_CENARIO_AU`: dispara na alteracao de campos fiscais retornados pela consulta/cache.

Campos monitorados no update:

- `PERICMSAI`
- `TIPO_ANTECIPACAO`
- `IDSITTRIBSAI`
- `PERREDTRIBSAI`
- `PERICMECF`
- `UFORIGEM`
- `DTALTERACAO`
- `FLAGEVIDENCIA`
- `PERFCEP`

Regra:

- valida se o `IDPRODUTO` e `IDSUBPRODUTO` do cenario aparecem como produto padrao em alguma empresa pela `DBA.CENARIO_FISCAL_PADRAO_PRODUTO_VW`;
- confirma o enquadramento fiscal pela `DBA.PRODUTO_TRIBUTACAO_CENARIO_VIEW`, amarrando o `IDCENARIOFISCAL`;
- se o cenario for aplicavel como padrao, faz `MERGE` da chave `IDEMPRESA`, `IDPRODUTO`, `IDSUBPRODUTO` em `DBA.MONITORFRONT_CENFIS_PENDENTE`.

## Fluxo operacional

1. Ocorre alteracao fiscal em `DBA.EMPRESA` ou `DBA.CENARIO_FISCAL`.
2. A trigger identifica as chaves impactadas.
3. A trigger faz `MERGE` em `DBA.MONITORFRONT_CENFIS_PENDENTE`.
4. Uma aplicacao/agendador chama `DBA.SP_MONITORFRONT_PROCESSA_PEND_CENFIS`.
5. A procedure processadora recalcula o cache para cada chave pendente.
6. A procedure grava uma linha em `DBA.MONITORFRONT_CENFIS_HISTORICO`.
7. A procedure remove a chave de `DBA.MONITORFRONT_CENFIS_PENDENTE`.
8. A consulta v3 passa a consumir o novo dado fiscal por join direto no cache.

## Escopo inicial

Nao foram criadas triggers em:

- `DBA.PRODUTO`
- `DBA.PRODUTO_GRADE`

Nesta etapa, a pendencia e exclusiva para alteracoes fiscais que impactam a resolucao do cenario.

## Vantagens

- Mantem a tabela de pendentes pequena, apenas com trabalho aberto.
- Evita duplicidade de pendencias para a mesma empresa/produto/subproduto.
- Separa controle operacional de auditoria.
- Permite rastrear quando e por qual origem cada chave foi processada.
- Reduz o impacto das triggers, que apenas marcam pendencias.
- Garante que alteracao de cenario fiscal movimente somente produtos onde o cenario e padrao/aplicavel.

## Pontos de atencao

- Os nomes fisicos dos campos em `DBA.CENARIO_FISCAL` devem ser confirmados no catalogo antes da execucao.
- A trigger de empresa pode inserir muitas pendencias quando uma empresa com muitos produtos padrao for alterada.
- A rotina processadora deve ser executada continuamente para evitar acumulo em `DBA.MONITORFRONT_CENFIS_PENDENTE`.
- A carga inicial do cache ainda deve ser feita antes de habilitar a consulta v3.
- Se a procedure falhar antes de remover a pendencia, a chave permanece pendente e sera reprocessada na proxima execucao.

## Validacao sugerida

1. Criar e popular inicialmente `DBA.PRODUTO_GRADE_CENARIO_FISCAL`.
2. Confirmar que `DBA.MONITORFRONT_CENFIS_PENDENTE` possui PK em `IDEMPRESA`, `IDPRODUTO`, `IDSUBPRODUTO`.
3. Confirmar que `DBA.MONITORFRONT_CENFIS_HISTORICO` possui PK propria em `IDHISTORICO`.
4. Alterar `UF`, `IDATIVIDADE`, `IDREGIMEESPECIAL` ou `TIPOREGIMETRIBFEDERAL` em uma empresa de teste.
5. Confirmar que os produtos padrao dessa empresa foram inseridos/remarcados em `MONITORFRONT_CENFIS_PENDENTE`.
6. Inserir ou alterar um cenario fiscal de produto/subproduto que seja padrao em alguma empresa.
7. Confirmar que somente as chaves aplicaveis entraram em `MONITORFRONT_CENFIS_PENDENTE`.
8. Executar `DBA.SP_MONITORFRONT_PROCESSA_PEND_CENFIS`.
9. Confirmar que as chaves processadas sairam de `MONITORFRONT_CENFIS_PENDENTE`.
10. Confirmar que as chaves processadas entraram em `MONITORFRONT_CENFIS_HISTORICO` com a origem correta.
11. Comparar a consulta v3 contra a v2 para as mesmas empresas/chaves.

