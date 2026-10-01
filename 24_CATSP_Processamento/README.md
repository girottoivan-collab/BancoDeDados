# CATSP — mapa detalhado do levantamento para restituição

## Finalidade

Este diretório implementa o levantamento de produtos e a composição do saldo de estoque pelas notas de compra, para subsidiar o cálculo de restituição de ICMS/ICMS-ST na posição de 30/09/2026.

Há somente dois arquivos SQL:

1. [01_deploy_catsp_restituicao.sql](01_deploy_catsp_restituicao.sql): cria as três tabelas, índices, importa os NCMs e cria a única procedure de processamento;
2. [02_consulta_final_restituicao_catsp.sql](02_consulta_final_restituicao_catsp.sql): retorna o detalhamento final para análise ou exportação.

Nenhum arquivo contém host, usuário ou senha.

## Implantação e execução

```powershell
db2 -td@ -vf 01_deploy_catsp_restituicao.sql
```

```sql
CALL DBA.SP_CATSP_PROCESSA_RESTITUICAO(DATE('2026-09-30'))
```

A procedure única contém as duas fases abaixo, executadas na mesma chamada.

## Etapa 1 — relação de NCMs

Tabela: `DBA.CATSP_NCM`.

- Fonte: `Relacao_NCMs_Anexos_VII_VIII_XIV_XVIII_XXI.xlsx`.
- Foram importados 208 registros dos Anexos VII, VIII, XIV, XVIII e XXI.
- São gravados anexo, CEST, NCM original, NCM sem pontuação e descrição.
- `NCM_SEM_PONTUACAO` é usado como prefixo de busca. Assim, um NCM da relação como `4011` inclui todo produto cujo NCM comece por `4011`.

## Etapa 2 — produtos elegíveis e posição de estoque

Tabela: `DBA.CATSP_PRODUTO`.

Na primeira fase da `DBA.SP_CATSP_PROCESSA_RESTITUICAO`, a procedure:

- localiza em `DBA.PRODUTOS_VIEW` os produtos cujo NCM atende à relação da etapa 1;
- grava `IDPRODUTO`, `IDSUBPRODUTO`, `DESCRCOMPRODUTO`, NCM, `CODCEST` e `EMBALAGEMSAIDA` (unidade disponível na view);
- faz `CROSS JOIN` com `DBA.EMPRESA`;
- chama `DBA.UF_SALDOEST_DTPOSICAO(IDEMPRESA, IDPRODUTO, IDSUBPRODUTO, DTPOSICAO)`;
- soma `QTDATUALESTOQUE` de todas as empresas, gravando `QTD_ESTOQUE`;
- registra a data da posição em `DTMOVIMENTO`.

Para a execução solicitada, a data é `DATE('2026-09-30')`. Antes de recarregar a data, os registros existentes dessa mesma posição são substituídos.

## Etapa 3 — composição do saldo pelas compras

Tabela: `DBA.CATSP_CONSUMO_ENTRADA`.

Na segunda fase da mesma procedure:

- parte dos produtos e quantidades de `CATSP_PRODUTO`;
- busca em `DBA.ESTOQUE_ANALITICO` somente compras com `IDOPERACAO < 1000`, `TIPOCATEGORIA = 'C'` e `QTDPRODUTO > 0`;
- relaciona as notas por `IDEMPRESA` e `IDPLANILHA`, e o item XML também por `NUMSEQUENCIA`;
- ordena as entradas da mais recente para a mais antiga por data de emissão, data de movimento, empresa, planilha e sequência;
- consome cada entrada até atingir o saldo de posição: uma nota pode ser consumida integralmente ou apenas pela quantidade remanescente;
- grava `QTD_ADQUIRIDA` e `QTD_CONSIDERADA`, preservando a rastreabilidade do consumo.

Dados gravados da nota:

- empresa, planilha e sequência do item;
- chave NF-e de `NOTA_FISCAL_ELETRONICA_TERCEIROS.CHAVENFE`;
- número e série de `NOTAS.NUMNOTA` e `NOTAS.SERIENOTA`;
- data de emissão e CNPJ do fornecedor de `NOTAS_ENTRADA_SAIDA`;
- código do item de entrada de `ESTOQUE_ANALITICO_XML.CODPRODUTO`.

Produtos sem compra elegível permanecem sem linha na tabela de consumo; a consulta final traz uma consulta comentada para identificá-los.

## Etapa 4 — valores fiscais e prioridade de origem

Todos os valores abaixo são gravados em nível unitário na tabela de consumo:

| Informação | Regra aplicada |
| --- | --- |
| Valor unitário da mercadoria | `ESTOQUE_ANALITICO.VALUNITBRUTO` |
| Custo unitário líquido | `ESTOQUE_ANALITICO.VALTOTLIQUIDO / QTDPRODUTO` |
| Base de ICMS próprio | `ESTOQUE_ANALITICO_ST.VALBASEICMSCREDITO / QTDPRODUTO`; se zero, `ESTOQUE_ANALITICO.VALBASEICM / QTDPRODUTO` |
| Alíquota de ICMS próprio | `ESTOQUE_ANALITICO_ST.PERICMSCREDITO`; se zero, `ESTOQUE_ANALITICO.PERICM` |
| Valor unitário de ICMS próprio | `ESTOQUE_ANALITICO_ST.VALICMSCREDITO / QTDPRODUTO`; se zero, `ESTOQUE_ANALITICO.VALICMS / QTDPRODUTO` |
| Base de ICMS-ST retido | `ESTOQUE_ANALITICO_ST.VALBASESTRETIDO / QTDPRODUTO`; se zero, `ESTOQUE_ANALITICO.VALBASESUBST / QTDPRODUTO` |
| Valor unitário de ICMS-ST retido | `ESTOQUE_ANALITICO_ST.VALICMSSTRETIDO / QTDPRODUTO`; se zero, `ESTOQUE_ANALITICO.VALICMSUBST / QTDPRODUTO` |
| Quantidade utilizada | `QTD_CONSIDERADA`, parcela da nota usada para atender o estoque |
| Redução de base | `ESTOQUE_ANALITICO.PERREDTRIB` |
| Alíquota interna | `ESTOQUE_ANALITICO_ST.PERICMSST`; se zero, `ESTOQUE_ANALITICO.PERICM` |
| Alíquota interestadual | `ESTOQUE_ANALITICO_ST.PERICMSCREDITO` |

A consulta final calcula também os valores considerados: quantidade utilizada multiplicada pelo ICMS próprio unitário e pelo ICMS-ST retido unitário.

## Resultado de referência no FERRARI

Na carga de 30/09/2026 foram gravados 5.831 produtos elegíveis e 8.765 linhas de consumo, com 1.973.685 unidades compostas por entradas. O saldo total de posição foi 1.998.637 unidades; 24.293 unidades ficaram sem lastro por entrada de compra elegível.
