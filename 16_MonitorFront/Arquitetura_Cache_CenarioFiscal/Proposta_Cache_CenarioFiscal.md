# Proposta de cache de cenario fiscal para Monitor CissFront

## Objetivo

Reduzir o custo da consulta `SelectProdutosComCenarioFiscal_v2.txt` removendo, no fluxo online de carga do frente de caixa, a resolucao direta pela `DBA.PRODUTO_TRIBUTACAO_CENARIO_VIEW PTCV`.

A consulta atual resolve os campos fiscais atraves da combinacao de:

- `DBA.PRODUTO_TRIBUTACAO_CENARIO_VIEW`
- `DBA.EMPRESA`
- `DBA.ATIVIDADE_TIPO_ATIVIDADE`
- `DBA.CENARIO_FISCAL_PADRAO_PRODUTO_VW`
- `DBA.PRODUTO_GRADE`
- `DBA.PRODUTO`

A proposta e materializar o resultado fiscal por empresa/produto/subproduto em uma tabela filha de `PRODUTO_GRADE`, mantendo a regra atual como fonte de verdade em uma procedure de atualizacao.

## Tabela proposta

Tabela: `DBA.PRODUTO_GRADE_CENARIO_FISCAL`

Chave primaria:

- `IDEMPRESA`
- `IDPRODUTO`
- `IDSUBPRODUTO`

Campos fiscais retornados atualmente pela `PTCV`:

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

Campos operacionais sugeridos:

- `DTALTERACAO_ORIGEM`: maior data considerada entre produto/grade/cenario para auditoria da carga.
- `DTPROCESSAMENTO`: data em que a linha foi recalculada.
- `FLAGVALIDO`: permite invalidar a linha sem excluir imediatamente, facilitando auditoria e comparacao.

## Consulta v3

Arquivo: `SelectProdutosComCenarioFiscal_v3_cache.txt`

Alteracao aplicada:

- Remove do ramo `P.TIPOBAIXAMESTRE <> 'C'` os joins com `PRODUTO_TRIBUTACAO_CENARIO_VIEW`, `ATIVIDADE_TIPO_ATIVIDADE` e `CENARIO_FISCAL_PADRAO_PRODUTO_VW`.
- Inclui join direto com `DBA.PRODUTO_GRADE_CENARIO_FISCAL PGCF`.
- Mantem a CTE `EMPRESAS_BASE`, portanto filtros pontuais por empresa continuam devendo ser aplicados nela.
- Mantem o restante da consulta, inclusive politica de preco, mix, filtros incrementais e ramo de componente `TIPOBAIXAMESTRE = 'C'`.

## Alimentacao

A procedure de atualizacao deve recalcular as linhas usando a mesma regra fiscal da consulta v2. A mudanca de arquitetura e somente deslocar esse custo para um processamento controlado, antes da consulta do Monitor Front.

Fluxo recomendado sem controle de pendencia:

1. Uma aplicacao ou rotina agendada chama a procedure sem parametros.
2. A procedure le `DTULTPROCESSAMENTO` em `DBA.MONITORFRONT_CENFIS_CONTROLE`.
3. A procedure processa a consulta base para itens com data de alteracao posterior ao ultimo processamento.
4. Fazer `MERGE` na tabela `PRODUTO_GRADE_CENARIO_FISCAL`.
5. Ao final, gravar o timestamp da execucao atual em `MONITORFRONT_CENFIS_CONTROLE`.
6. Executar a consulta v3 apenas para linhas com cache valido.

Fluxo recomendado com controle de pendencia:

1. Triggers em tabelas fiscais fazem `MERGE` das chaves em `DBA.MONITORFRONT_CENFIS_PENDENTE`, mantendo somente produtos ainda pendentes.
2. Uma rotina agendada chama `DBA.SP_MONITORFRONT_PROCESSA_PEND_CENFIS`.
3. A rotina processa as chaves pendentes e chama `DBA.SP_MONITORFRONT_ATUALIZA_CENFIS`.
4. A rotina grava o processamento em `DBA.MONITORFRONT_CENFIS_HISTORICO` e remove a chave da tabela de pendentes.
5. A regra fiscal completa continua fora da transacao de cadastro.

Foram separadas duas versoes de implementacao:

- `Objetos_Cache_CenarioFiscal_sem_pendencia.sql`: nao cria fila nem triggers. A procedure nao possui parametros e usa tabela de controle de ultimo processamento.
- `Objetos_Cache_CenarioFiscal_com_pendencia.sql`: cria tabela de pendentes por `IDEMPRESA`, `IDPRODUTO` e `IDSUBPRODUTO`, tabela de historico, procedure de processamento e triggers para remarcar chaves fiscais pendentes.

## Pontos de atencao

- Alteracoes em `DBA.EMPRESA` tambem podem mudar o cenario fiscal porque a regra depende de `UF`, `IDATIVIDADE`, `IDREGIMEESPECIAL` e `TIPOREGIMETRIBFEDERAL`.
- Alteracoes na regra de origem do produto usada pela `CENARIO_FISCAL_PADRAO_PRODUTO_VW` tambem exigem recarga das chaves afetadas.
- Se a view `PTCV` puder retornar mais de um cenario para a mesma chave empresa/produto/subproduto, a procedure precisa manter exatamente a mesma cardinalidade esperada pela consulta atual ou aplicar a mesma regra de desempate do sistema.
- A consulta v3 deve ser homologada comparando quantidade de linhas, chaves e campos fiscais contra a v2 para o mesmo filtro em `EMPRESAS_BASE`.
- Nesta versao inicial, a tabela de pendentes e exclusiva para mudancas fiscais. Nao foram propostas triggers em `PRODUTO` e `PRODUTO_GRADE`.

## Triggers da versao com pendencia

- `TR_MONFRONT_CENFIS_EMPRESA_AU`: dispara em `DBA.EMPRESA` somente se mudar `UF`, `IDATIVIDADE`, `IDREGIMEESPECIAL` ou `TIPOREGIMETRIBFEDERAL`, enfileirando os produtos padrao vinculados a empresa.
- `TR_MONFRONT_CENFIS_CENARIO_AI`: dispara em insert de `DBA.CENARIO_FISCAL`, enfileirando somente quando o cenario cadastrado for padrao do produto em alguma empresa.
- `TR_MONFRONT_CENFIS_CENARIO_AU`: dispara em update de `DBA.CENARIO_FISCAL` somente se mudar campo fiscal retornado na consulta/cache, enfileirando somente quando o cenario alterado for padrao do produto em alguma empresa.
- As triggers fazem `MERGE` na tabela de pendentes; a procedure grava historico e remove a pendencia processada.

## Roteiro de validacao

1. Popular a tabela cache para uma empresa pequena.
2. Executar a v2 e a v3 com a mesma CTE `EMPRESAS_BASE`.
3. Comparar `COUNT(*)`.
4. Comparar chaves `IDEMPRESA`, `IDPRODUTO`, `IDSUBPRODUTO`, `IDCENARIOFISCAL`.
5. Comparar campos fiscais retornados por `PTCV` contra `PGCF`.
6. Repetir com duas ou mais empresas na CTE para validar que o filtro da CTE limita todos os pontos.
7. Medir tempo de execucao da v2 contra v3.
