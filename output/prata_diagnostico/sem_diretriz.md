# Consulta sem diretriz — validacao de 19/10/2026

Arquivo completo: consulta_sem_diretriz.sql.

Unica alteracao em relacao ao SQL original:

```sql
-- Antes, no JOIN com ADMINISTRADORAS_BANDEIRA:
BANDEIRA.IDBANDEIRA = CR.IDBANDEIRA
-- Depois:
BANDEIRA.IDBANDEIRA = CR.IDBANDEIRA + 0
```

O filtro BANDEIRA.IDADMINISTRADORA = 99 permanece no WHERE. Nao ha OPTGUIDELINES no SQL entregue.

A expressao na chave de bandeira altera a possibilidade de explorar essa coluna como chave de busca direta do indice IE_FK_0000363. No EXPLAIN coletado, o Db2 passou a utilizar CON_REC_IDEDTVFBX, com delimitacao por empresa e vencimento. Alterar somente o filtro da administradora nao havia sido suficiente nos testes.

A execucao sem diretriz retornou 30 linhas em 0,3618 segundo. Comparei todas as colunas e multiplicidades com a versao com diretriz, previamente comparada com a original: resultados identicos. Os tempos variam conforme carga e cache.

Esta e uma reescrita para influenciar o plano, nao uma imposicao contratual de um indice pelo nome. Alteracoes nas estatisticas, parametros, intervalos, versao ou simplificacoes futuras do otimizador podem mudar a escolha; validar novamente o EXPLAIN nessas circunstancias.

Nenhum indice, estatistica ou dado da aplicacao foi alterado. Evidencias: join_bandeira_soma_zero_object.json, join_bandeira_soma_zero_predicate.json e sem_diretriz_validacao.json.
