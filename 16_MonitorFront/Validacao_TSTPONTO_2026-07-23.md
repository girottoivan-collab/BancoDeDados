# Validacao TSTPONTO - Monitor CissFront

Data da validacao: 2026-07-23

## Ambiente

- Host: `163.176.143.73`
- Banco: `TSTPONTO`
- Porta: `49470`
- Usuario: `dba`
- Cliente local: IBM Db2 CLP `SQL11013`
- Servidor: `DB2/LINUXX8664 11.5.9.0`

Senha nao registrada neste arquivo.

## Objetivo

Validar o comportamento das consultas v2 quando a CTE `EMPRESAS_BASE` recebe filtro parcial por empresa, especialmente comparando uma empresa contra duas empresas.

## Metodologia

- Script usado: `validar_monitorfront_db2clp.ps1`.
- Filtros aplicados dentro de `EMPRESAS_BASE`:
  - `WHERE EMPRESA.IDEMPRESA IN (1)`
  - `WHERE EMPRESA.IDEMPRESA IN (1,2)`
- Parametros simulados na validacao:
  - `:RA_DTMONITOR` = `TIMESTAMP('1900-01-01 00:00:00')`
  - `:RA_COMPLETA` = `'F'`
- Medicao feita com `SELECT COUNT(*) FROM (<consulta>)`, sem transferir todo o resultado.

## Dados observados da base

As primeiras empresas consultadas possuem a mesma UF e o mesmo volume em `DBA.POLITICA_PRECO_PRODUTO`:

| IDEMPRESA | UF | QTD_POLITICA_PRECO |
| --- | --- | ---: |
| 1 | PR | 269380 |
| 2 | PR | 269380 |
| 3 | PR | 269380 |
| 4 | PR | 269380 |
| 5 | PR | 269380 |
| 6 | PR | 269380 |
| 7 | PR | 269380 |
| 8 | PR | 269380 |
| 9 | PR | 269380 |
| 10 | PR | 269380 |
| 11 | PR | 269380 |
| 12 | PR | 269380 |
| 13 | PR | 269380 |
| 14 | PR | 269380 |
| 15 | PR | 269380 |
| 16 | PR | 269380 |
| 17 | PR | 269380 |
| 18 | PR | 269380 |
| 19 | PR | 269380 |
| 20 | PR | 269380 |

## Resultado medido

### `SelectProdutosSemCenarioFiscal_v2.txt`

| Filtro em `EMPRESAS_BASE` | Linhas | Tempo `COUNT(*)` |
| --- | ---: | ---: |
| `IDEMPRESA IN (1)` | 89006 | 33,189s |
| `IDEMPRESA IN (1,2)` | 178012 | 56,349s |

Conclusao: o volume dobrou exatamente ao incluir a segunda empresa. O tempo de `COUNT(*)` cresceu quase linearmente. Como a consulta real retorna muitas colunas e o app precisa transferir todas as linhas, a lentidao percebida no retorno com duas empresas tende a vir do volume duplicado de linhas, ordenacao/distinct e trafego, nao de vazamento de empresas fora da CTE.

### `SelectProdutosComCenarioFiscal_v2.txt`

A consulta foi submetida para os mesmos filtros, mas a medicao por `COUNT(*)` no CLP falhou antes de retornar contagem:

- `SQL0437W`: consulta complexa, desempenho possivelmente abaixo do otimo.
- `SQL0180N`: sintaxe da representacao de cadeia de data/hora incorreta.

Foram ajustados fallbacks literais de timestamp nas v2 para `CAST('1900-01-01 00:00:00' AS TIMESTAMP)`, mas ainda resta falha de conversao durante a avaliacao da consulta com cenario no CLP. O erro pode estar relacionado a alguma expressao de data calculada ou dado retornado por alguma funcao/view usada no cenario fiscal.

## Revisao dos filtros da CTE

Pontos confirmados nas v2:

- Nao ha mais `:RA_IDEMPRESA` nem `:RA_UF` nas versoes v2.
- Nao ha `JOIN DBA.EMPRESA` fora da CTE nas versoes v2.
- Os ramos principais usam `EMPRESAS_BASE.IDEMPRESA` e/ou `EMPRESAS_BASE.UF`.
- `DBA.PRODUTO_EMPRESA` nos `LEFT JOIN LATERAL` foi amarrada a empresa corrente.
- Os joins auxiliares de empresa, preco, desconto, mix e permissao respeitam a empresa corrente.

## Observacao de desempenho

Como as empresas 1 e 2 estao na mesma UF (`PR`) e possuem mesmo volume de politica de preco, os ramos tributarios por UF continuam encontrando o mesmo conjunto fiscal para cada empresa filtrada. O resultado final deve trazer uma copia por empresa, pois campos de preco, permissao e regras dependem de `IDEMPRESA`.

Para uso operacional com muitas empresas, a alternativa mais previsivel tende a ser executar por empresa ou por pequenos lotes de empresas, principalmente quando a aplicacao precisa consumir o resultado completo.
