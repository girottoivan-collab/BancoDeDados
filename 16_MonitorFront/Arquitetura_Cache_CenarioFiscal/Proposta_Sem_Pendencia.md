# Proposta sem controle de pendencia

## Objetivo

Criar uma tabela cache com os dados fiscais hoje resolvidos pela `DBA.PRODUTO_TRIBUTACAO_CENARIO_VIEW` na consulta com cenario fiscal do Monitor CissFront, mantendo a atualizacao por uma procedure agendada e sem parametros.

Esta alternativa reduz a complexidade inicial porque nao cria fila nem triggers. A carga do cache fica sob responsabilidade de uma aplicacao ou rotina agendada que chama continuamente a procedure.

## Arquivos relacionados

- `SelectProdutosComCenarioFiscal_v3_cache.txt`: consulta que consome o cache.
- `Objetos_Cache_CenarioFiscal_sem_pendencia.sql`: DDL da tabela cache, tabela de controle de ultimo processamento, indices e procedure sem parametros.

## Componentes

### Tabela cache

Tabela: `DBA.PRODUTO_GRADE_CENARIO_FISCAL`

Chave primaria:

- `IDEMPRESA`
- `IDPRODUTO`
- `IDSUBPRODUTO`

Campos fiscais armazenados:

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

Campos de controle:

- `DTALTERACAO_ORIGEM`
- `DTPROCESSAMENTO`
- `FLAGVALIDO`

### Tabela de controle

Tabela: `DBA.MONITORFRONT_CENFIS_CONTROLE`

Campo unico:

- `DTULTPROCESSAMENTO`

Objetivo:

- guardar a data/hora ate onde a ultima execucao processou;
- servir como marco incremental da proxima execucao;
- eliminar a necessidade de parametros de entrada na procedure.

### Procedure

Procedure: `DBA.SP_MONITORFRONT_ATUALIZA_CENFIS`

Parametros: nenhum.

A procedure busca `MAX(DTULTPROCESSAMENTO)` em `DBA.MONITORFRONT_CENFIS_CONTROLE`, define um timestamp de processamento no inicio da execucao e processa os registros cuja data de alteracao seja maior que o ultimo marco e menor ou igual ao timestamp da execucao atual.

Esse desenho evita perder registros alterados enquanto a procedure esta rodando: alteracoes posteriores ao timestamp inicial ficam para a proxima chamada.

## Fluxo operacional

1. Uma aplicacao ou rotina agendada chama `SP_MONITORFRONT_ATUALIZA_CENFIS`.
2. A procedure le `DTULTPROCESSAMENTO` na tabela de controle.
3. A procedure fixa `V_DT_PROCESSAMENTO` com o timestamp de inicio da execucao.
4. A consulta base da procedure processa produtos/cenarios com `DTALTERACAO_ORIGEM` maior que o ultimo processamento e menor ou igual ao timestamp atual.
5. O resultado e consolidado por `IDEMPRESA`, `IDPRODUTO` e `IDSUBPRODUTO`.
6. A procedure faz `MERGE` em `PRODUTO_GRADE_CENARIO_FISCAL`.
7. Ao final, a procedure grava `V_DT_PROCESSAMENTO` em `MONITORFRONT_CENFIS_CONTROLE`.
8. A consulta v3 usa join direto na tabela cache.

## Quando usar

Esta versao e indicada para:

- primeira homologacao da arquitetura;
- ambientes onde ainda nao se deseja criar triggers;
- execucoes continuas por agendador externo;
- comparacao de performance entre v2 e v3 com menor impacto estrutural.

## Vantagens

- Menor quantidade de objetos no banco.
- Menor risco operacional inicial.
- Procedure simples de acionar, sem parametros.
- Controle incremental centralizado no banco.
- Nenhum impacto transacional em cadastros fiscais.

## Limitacoes

- O cache depende da rotina agendada ser executada continuamente.
- Alteracoes podem demorar ate refletir no frente de caixa, dependendo da frequencia da chamada.
- Sem fila, nao ha rastreabilidade nativa de quais alteracoes motivaram cada recarga.
- Se a procedure falhar antes de gravar o novo controle, a proxima execucao reprocessa a mesma janela.

## Pontos de atencao

- A procedure ainda usa a regra atual como fonte de verdade; portanto, ela pode continuar pesada durante a carga.
- A consulta v3 somente deve ser usada para empresas/produtos cujo cache esteja populado.
- Se a regra fiscal retornar mais de uma linha para a mesma chave, a minuta usa desempate deterministico: UF especifica, maior `CENFISDTALTERACAO` e maior `IDCENARIOFISCAL`.
- Deve existir rotina para carga inicial completa antes de habilitar a consulta v3.
- A tabela `MONITORFRONT_CENFIS_CONTROLE` deve manter apenas uma linha. A minuta faz `DELETE` e `INSERT` ao final para preservar esse comportamento mesmo sem chave primaria.

## Validacao sugerida

1. Inicializar `MONITORFRONT_CENFIS_CONTROLE` com `1900-01-01 00:00:00`.
2. Executar `SP_MONITORFRONT_ATUALIZA_CENFIS`.
3. Confirmar que `DTULTPROCESSAMENTO` foi atualizado.
4. Executar novamente sem alteracoes e validar que o volume processado tende a zero.
5. Alterar um produto/cenario em ambiente de teste com `DTALTERACAO` posterior ao controle.
6. Executar a procedure e confirmar que a chave foi atualizada no cache.
7. Comparar a consulta v2 e a v3 com a mesma CTE `EMPRESAS_BASE`.
8. Medir tempo da consulta v2 contra a v3.
