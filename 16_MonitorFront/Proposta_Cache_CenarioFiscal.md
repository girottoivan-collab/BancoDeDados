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

Fluxo recomendado:

1. Identificar empresas/produtos/subprodutos impactados por alteracao em produto, grade ou cenario.
2. Reexecutar a regra fiscal original somente para as chaves impactadas.
3. Fazer `MERGE` na tabela `PRODUTO_GRADE_CENARIO_FISCAL`.
4. Marcar como `FLAGVALIDO = 'F'` as linhas que deixarem de se enquadrar em qualquer regra.
5. Executar a consulta v3 apenas para linhas com cache valido.

Para evitar que triggers executem a regra fiscal completa dentro da transacao operacional, a sugestao e usar uma fila simples de pendencias e uma procedure processada por rotina agendada.

## Pontos de atencao

- Alteracoes em `DBA.EMPRESA` tambem podem mudar o cenario fiscal porque a regra depende de `UF`, `IDATIVIDADE`, `IDREGIMEESPECIAL` e `TIPOREGIMETRIBFEDERAL`.
- Alteracoes na regra de origem do produto usada pela `CENARIO_FISCAL_PADRAO_PRODUTO_VW` tambem exigem recarga das chaves afetadas.
- Se a view `PTCV` puder retornar mais de um cenario para a mesma chave empresa/produto/subproduto, a procedure precisa manter exatamente a mesma cardinalidade esperada pela consulta atual ou aplicar a mesma regra de desempate do sistema.
- A consulta v3 deve ser homologada comparando quantidade de linhas, chaves e campos fiscais contra a v2 para o mesmo filtro em `EMPRESAS_BASE`.

## Roteiro de validacao

1. Popular a tabela cache para uma empresa pequena.
2. Executar a v2 e a v3 com a mesma CTE `EMPRESAS_BASE`.
3. Comparar `COUNT(*)`.
4. Comparar chaves `IDEMPRESA`, `IDPRODUTO`, `IDSUBPRODUTO`, `IDCENARIOFISCAL`.
5. Comparar campos fiscais retornados por `PTCV` contra `PGCF`.
6. Repetir com duas ou mais empresas na CTE para validar que o filtro da CTE limita todos os pontos.
7. Medir tempo de execucao da v2 contra v3.

