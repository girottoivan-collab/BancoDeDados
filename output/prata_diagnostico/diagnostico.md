# Diagnostico MEUPRATA — 19/10/2026

Conexao direta ao Db2 11.5.9.0. Planos coletados de SYSTOOLS.EXPLAIN_* em transacao encerrada com rollback. Nenhuma alteracao de indices, estatisticas ou dados da aplicacao foi aplicada.

## Ponto critico confirmado

O filtro BANDEIRA.IDADMINISTRADORA = 99 muda a ordem dos joins e o caminho de acesso a DBA.CONTAS_RECEBER, tabela com cardinalidade estatistica de 59.750.706 linhas.

| Variante | Acesso a CONTAS_RECEBER | Aplicacao do vencimento |
|---|---|---|
| Com filtro original | IE_FK_0000363 (IDEMPRESA, IDBANDEIRA, IDADMINISTRADORA) | Predicado SARG no FETCH, depois do acesso ao indice |
| Sem filtro | CON_REC_IDEDTVFBX (IDEMPRESA, DTVENCIMENTO, FLAGBAIXADA) | START/STOP no IXSCAN |
| Com filtro e guideline validada | CON_REC_IDEDTVFBX | Restricao por vencimento no acesso ao indice |

No plano original filtrado, o Db2 parte de ADMINISTRADORAS_BANDEIRA e faz nested loops para buscar os titulos por empresa/bandeira/administradora. Como o indice escolhido nao tem DTVENCIMENTO, pode recuperar titulos de todo o historico para somente depois descartar os que nao vencem em 18/10/2026. No caminho rapido, o banco delimita empresa e vencimento antes dos demais joins.

Essa e a regressao de plano identificada. Nao e necessario que exista um TBSCAN na tabela grande para ocorrer a lentidao: IXSCAN com muitos FETCHes tambem pode ser caro. Os TBSCANs de resultados intermediarios nao devem ser confundidos com uma leitura integral de CONTAS_RECEBER.

O custo estimado do plano filtrado e 3.546,19 timerons, contra 57.226,97 sem filtro. Esses valores sao estimativas, nao segundos: o otimizador considera o plano lento mais barato. A saida do join filtrado e estimada em aproximadamente 1,45 linha, enquanto a consulta retorna 30. Isso evidencia a limitacao da estimativa, mas nao comprova isoladamente qual estatistica precisa ser corrigida. A estatistica de CONTAS_RECEBER consultada data de 16/10/2026; portanto nao se pode atribuir o problema simplesmente a estatisticas antigas.

## Correcao imediata testada

Manter integralmente a consulta, inclusive o filtro da administradora, e acrescentar depois de FOR READ ONLY, antes do ponto e virgula:

```sql
/* <OPTGUIDELINES>
     <IXSCAN TABLE='CR' INDEX='CON_REC_IDEDTVFBX'/>
   </OPTGUIDELINES> */
```

A consulta completa esta em consulta_indice_direcionado.sql. O EXPLAIN confirmou o uso do indice solicitado. Esta medida direciona somente o acesso de CR; o Db2 continua escolhendo os demais acessos e joins.

Medicoes com leitura integral do resultado pelo cliente Python:

| Consulta | Linhas | Tempo |
|---|---:|---:|
| Sem filtro | 58 | 0,0797 s |
| Com filtro original | 30 | 201,6365 s (3 min 21,64 s) |
| Com filtro e guideline, primeira rodada | 30 | 0,0630 s |
| Com filtro e guideline, apos a original | 30 | 0,0697 s |

A comparacao de todas as colunas e multiplicidades confirmou resultados identicos entre a original filtrada e a corrigida (equivalencia.json). A reducao observada foi de aproximadamente 2.893 vezes usando 0,0697 s como referencia. Tempos dependem de cache e carga e nao representam garantia para outros intervalos. Nao foram coletados contadores reais por operador; a localizacao do gargalo decorre dos EXPLAINs e do teste controlado de troca de indice.

Trocar apenas BANDEIRA.IDADMINISTRADORA por CR.IDADMINISTRADORA nao garante corrigir o plano, pois as colunas sao igualadas no INNER JOIN e o otimizador pode propagar o predicado. Uma CTE simples tambem pode ser incorporada ao plano sem materializacao.

## Evolucao estrutural

Ja existe um indice util para esta consulta, de modo que a correcao imediata dispensa criar objetos. Como alternativa para homologacao, avaliar um indice em (IDEMPRESA, DTVENCIMENTO, IDADMINISTRADORA, ORIGEMMOVIMENTO), conforme recomendacao_indice.sql. Nao foi criado nem validado por execucao. O beneficio depende dos intervalos e distribuicoes reais e deve ser comparado ao custo de manutencao e armazenamento em quase 60 milhoes de titulos.

Avaliar estatisticas de distribuicao de administradora, empresa, vencimento e bandeira e estatisticas de grupos de colunas correlacionadas antes de um RUNSTATS amplo. Atualizar estatisticas e recompilar pode ajudar, mas nao foi testado e nao e apresentado como solucao garantida.

## Observacoes de semantica

O FETCH FIRST 1 ROWS ONLY em CONTAS_RECEBER_BAIXAS_DETALHES nao tem ORDER BY; se houver multiplas linhas elegiveis com origens diferentes, a origem escolhida nao e deterministica. Definir uma regra de negocio para essa escolha e uma melhoria independente. Os joins de baixas e conciliacoes tambem podem multiplicar linhas; nao foram alterados para preservar a consulta fornecida.

## Evidencias

Os arquivos JSON guardam operadores, objetos, predicados, argumentos e streams dos tres planos. Arquivos *_execucao.json guardam as medicoes; equivalencia.json, quando produzido, registra a comparacao de todas as colunas e multiplicidades da consulta original filtrada contra a corrigida. Nenhum resultado financeiro foi salvo.

Referencia IBM: https://www.ibm.com/docs/en/db2/11.1?topic=plans-optimization-profiles-guidelines
