# Prompt e regras — Mapeamento de Tributação

Este documento preserva o contexto funcional da consulta
`MAPEAMENTO_TRIBUTACAO_16_CONSULTAS.sql`, para facilitar correções e novas
classificações sem redescobrir as regras de negócio.

Para executar cada classificação separadamente, use também
`CONSULTAS_INDIVIDUAIS_01_A_16.sql`: execute primeiro a seção **PREPARACAO**
e, na mesma sessão DB2, execute a consulta numerada desejada. Cada uma retorna
somente as dez colunas de saída definidas originalmente.

Para comparação com o resumo-base, use
`CONSULTAS_INDIVIDUAIS_01_A_16_POR_NOTA.sql`. Esta é a versão corrigida: ela
classifica os tipos e a fonte por nota antes de somar os resultados por
fornecedor e tipo.

O fechamento com o resumo-base usa exclusivamente as consultas **01 a 12**.
Elas foram definidas como grupos mutuamente exclusivos por nota: as consultas
06 e 10 são os resíduos multítipo de Cadastro e XML, e 11/12 são os resíduos
de fonte mista. As consultas 13 a 16 são recortes adicionais de Simples
Nacional e não devem ser somadas ao comparativo, pois podem sobrepor 05 e 06.

Use `VALIDACAO_FECHAMENTO_01_A_12.sql` com o mesmo período para conferir o
fechamento. O comparativo usa notas distintas por chave, pois a soma de
`QTDNOTASTIPO` é naturalmente maior quando uma nota multítipo aparece em mais
de uma linha de `TIPO`.

A versão que atende à classificação por fornecedor é
`CONSULTAS_01_A_16_POR_FORNECEDOR_NOTAS_MONOTIPO.sql`: o fornecedor é
classificado pelos tipos existentes nas suas notas monotipo do período, mas o
total exibido por `TIPO` continua contando as notas monotipo. Logo, uma nota
somente CST 40 de um fornecedor que também possui notas somente CST 41 é
classificada na consulta 02/04 e ainda compõe o total `ISENTO-40` do resumo.

## Padrão aprovado — fornecedor x notas monotipo

Este é o padrão definitivo para novas alterações do mapeamento. O arquivo de
referência é `CONSULTAS_01_A_16_POR_FORNECEDOR_NOTAS_MONOTIPO.sql`.

### 1. Universo de notas

Partir do mesmo universo da consulta-resumo: compras, operação de saldo de
produto, nota fiscal não cancelada e período informado. A chave da nota é
`IDEMPRESA` + `IDPLANILHA`.

### 2. Normalização por item

Para cada item, identificar o `TIPO` tributário a partir de `EA.IDSITTRIB` e
`EA.TIPOSITTRIB`, incluindo a separação de CST 60 em `STNORMAL-60` e
`STFRONTEIRA-60`. Identificar também a fonte:

- `EAF.FLAGTRIBUTACAOXML = 'T'`: XML;
- qualquer outro valor, inclusive EAF ausente: Cadastro.

### 3. Definição de nota monotipo

Agrupar os itens por nota. Uma nota é monotipo quando possui exatamente um
`TIPO` tributário distinto. Apenas essas notas integram os totais exibidos por
`TIPO`, pois é esta a regra usada pelo resumo-base.

Notas multítipo não são descartadas por erro: elas apenas não podem compor um
total de nota monotipo de um único `TIPO`.

### 4. Classificação do fornecedor

Depois de identificar as notas monotipo, reunir seus tipos por fornecedor no
período. A classificação 01–16 usa esse conjunto do fornecedor, e não o tipo
isolado de cada nota.

Exemplos:

- fornecedor com todas as notas monotipo CST 40: consulta 01 ou 03, conforme
  perfil de Produtor Rural e fonte;
- fornecedor com notas monotipo CST 40 e CST 41: consulta 02 ou 04;
- fornecedor com notas monotipo CST 40 e CST 00: consulta residual 06, 10 ou
  12, conforme a origem da tributação;
- cada nota somente CST 40 desses dois últimos exemplos continua contribuindo
  para o total `ISENTO-40`.

### 5. Apresentação dos totais

Após definir a consulta do fornecedor, agrupar as suas notas monotipo por:

`CONSULTA`, `IDCLIFOR`, `IDATIVIDADE`, `ATIVIDADE`, `PRODUTOR` e `TIPO`.

`QTDNOTASTIPO` é a quantidade de notas monotipo daquele fornecedor e tipo.
`XML`, `CAD`, `% XML` e `% CAD` são calculados sobre essa mesma quantidade.
Assim, uma única linha representa um fornecedor + tipo, e **não** uma única
nota; para conferir totais, usar `SUM(QTDNOTASTIPO)`, não `COUNT(*)` das linhas
retornadas.

### 6. Regra de conferência com o resumo

Para validar, somar `QTDNOTASTIPO` de um tipo em todas as consultas 01–12 da
versão aprovada. O resultado deve ser igual ao total do mesmo tipo no resumo.

Por exemplo, o total de `ISENTO-40` deve incluir notas CST 40 que foram
classificadas nas consultas 01, 02, 03, 04, 06, 07, 08, 10, 11 ou 12, conforme
o conjunto tributário e a fonte do fornecedor. Não comparar o total por tipo
somando o número de linhas do resultado.

As consultas 13–16 são recortes analíticos de Simples Nacional. Elas não devem
ser somadas ao fechamento 01–12, pois podem reclassificar fornecedores que já
aparecem nas consultas gerais de Cadastro.

## Saída detalhada por nota

Além do resumo, usar `DETALHAMENTO_NOTAS_POR_CONSULTA.sql` na mesma sessão da
preparação da versão aprovada. Ela preserva a classificação por fornecedor e
adiciona, por nota, data, número, série, CST PIS/COFINS, valores de IPI, frete,
acessórios, descontos e acréscimos de `ESTOQUE_ANALITICO`, além de desconto,
frete, seguro, outros, IPI, ICMS-ST e PMVAST do XML.

## Origem e escopo

- Banco: `NOPONTO`.
- Esquema das tabelas: `DBA`.
- Consulta-base de referência: `RESUMO TIPO SEM AGRUPAMENTOS.sql`.
- Parâmetros de período: `:RA_DTINI` e `:RA_DTFIM`.
- Notas consideradas: compras (`OI.TIPOMOVIMENTO = 'C'`), operação de saldo de
  produto, movimento fiscal, não canceladas e operação inferior a 1000.

## Regras globais

| Regra | Interpretação na consulta |
| --- | --- |
| `EA.TIPOSITTRIB = 'F'` e CST 60 | `STNORMAL-60` |
| `EA.TIPOSITTRIB = 'A'` e CST 60 | `STFRONTEIRA-60` |
| `EAF.FLAGTRIBUTACAOXML = 'T'` | Tributação obtida do XML |
| `EAF.FLAGTRIBUTACAOXML <> 'T'` ou EAF ausente | Tributação obtida do cadastro |
| `CF.TIPOREGIMETRIBFEDERAL = 'S'` | Simples Nacional |
| `ATV.FLAGPRODUTORRURAL = 'T'` | Produtor Rural |

A chave de `ESTOQUE_ANALITICO_FISCAL` para `ESTOQUE_ANALITICO` é:
`IDEMPRESA`, `IDPLANILHA`, `NUMSEQUENCIA`.

Atividade do fornecedor:

```sql
SELECT CF.IDCLIFOR,
       CF.IDATIVIDADE,
       TA.DESCRTIPOATIVIDADE AS ATIVIDADE,
       ATV.FLAGPRODUTORRURAL AS PRODUTOR,
       CASE WHEN CF.TIPOREGIMETRIBFEDERAL = 'S' THEN 'S' ELSE 'N' END AS SIMPLESNACIONAL
FROM DBA.CLIENTE_FORNECEDOR CF
LEFT JOIN DBA.ATIVIDADE ATV ON ATV.IDATIVIDADE = CF.IDATIVIDADE
LEFT JOIN DBA.ATIVIDADE_TIPO_ATIVIDADE ATA
       ON ATA.IDATIVIDADE = CF.IDATIVIDADE
      AND ATA.FLAGPADRAO = 'T'
LEFT JOIN DBA.TIPO_ATIVIDADE TA ON TA.IDTIPOATIVIDADE = ATA.IDTIPOATIVIDADE;
```

## Tipos tributários tratados

| CST | Tipo |
| --- | --- |
| 00 | `TRIBUTADO-00` |
| 20 | `REDUCAO-20` |
| 40 | `ISENTO-40` |
| 41 | `NAOTRIBUTADO-41` |
| 50 | `SUSPENSO-50` |
| 51 | `DIFERIDO-51` |
| 60 / `F` | `STNORMAL-60` |
| 60 / `A` | `STFRONTEIRA-60` |
| 90 | `OUTROS-90` |

O CST é extraído com `MOD(EA.IDSITTRIB, 100)`, preservando a regra já usada na
consulta-base para códigos como 140, 240 etc.

## Saída esperada

Colunas principais, por fornecedor e classificação:

`IDCLIFOR`, `IDATIVIDADE`, `ATIVIDADE`, `PRODUTOR`, `TIPO`,
`QTDNOTASTIPO`, `XML`, `CAD`, `% XML`, `% CAD`.

No script de consultas individuais, `TIPO` é o tipo tributário efetivo
(`ISENTO-40`, `NAOTRIBUTADO-41`, `SUSPENSO-50`, etc.), e não o nome do grupo
da consulta. Assim, uma consulta cujo filtro-pai é CST 40/41/50/90 retorna uma
linha por tipo encontrado, com os respectivos totais de notas e fontes.

A consulta também traz:

- `QTDNOTAS_CLASSIFICADAS`: soma das notas retornadas pelas 16 classificações;
- `QTDNOTAS_BASE`: total de notas do universo-base;
- `DIFERENCA_PARA_BASE`: notas-base não cobertas pelas 16 regras.

`XML` e `CAD` contam notas que possuem pelo menos um item de cada fonte. Uma
nota com itens XML e Cadastro é contada em ambas as colunas, para explicitar o
uso misto. Por isso, em classificações mistas, `% XML + % CAD` pode ser maior
que 100%.

## As 16 classificações

1. Produtor Rural, somente Cadastro, um tipo, somente CST 40/41/50/90.
2. Produtor Rural, somente Cadastro, mais de um tipo, somente CST 40/41/50/90.
3. Não Produtor Rural, somente Cadastro, um tipo, somente CST 40/41/50/90.
4. Não Produtor Rural, somente Cadastro, mais de um tipo, somente CST 40/41/50/90.
5. Somente Cadastro, um tipo, fora de CST 40/41/50/90.
6. Somente Cadastro, mais de um tipo, combinando CST 40/41/50/90 com 00/20/51/60.
7. Somente XML, um tipo, somente CST 40/41/50/90.
8. Somente XML, mais de um tipo, somente CST 40/41/50/90.
9. Somente XML, um tipo, fora de CST 40/41/50/90.
10. Somente XML, mais de um tipo, combinando CST 40/41/50/90 com 00/20/51/60.
11. XML e Cadastro, um tipo, fora de CST 40/41/50/90.
12. XML e Cadastro, mais de um tipo, combinando CST 40/41/50/90 com 00/20/51/60.
13. Simples Nacional, somente Cadastro, um tipo, somente CST 00/20/51.
14. Simples Nacional, somente Cadastro, mais de um tipo, somente CST 00/20/51.
15. Não Simples Nacional, somente Cadastro, um tipo, somente CST 00/20/51.
16. Não Simples Nacional, somente Cadastro, mais de um tipo, somente CST 00/20/51.

## Estrutura técnica da SQL

1. `NOTAS_MOVIMENTO` delimita o universo de notas da consulta-base.
2. `ITENS_TRIBUTACAO` associa os itens ao EAF e normaliza CST, tipo e fonte.
3. `NOTA_FONTE` identifica se cada nota utilizou XML, Cadastro ou ambos.
4. `FORNECEDOR_NOTAS` e `FORNECEDOR_TRIBUTACAO` consolidam as métricas por
   fornecedor.
5. `FORNECEDORES` acrescenta atividade, produtor e Simples Nacional.
6. `RESULTADO` une as 16 regras usando `UNION ALL`.
7. `TOTAIS_16` e `TOTAL_BASE` formam o comparativo final.

## Pontos de atenção em futuras alterações

- O resumo-base classifica primeiro cada nota (`IDEMPRESA`, `IDPLANILHA`) e só
  depois totaliza. Para uma comparação direta, as 16 consultas devem aplicar
  os critérios de quantidade e combinação de tipos nessa mesma granularidade;
  somente então devem agrupar por fornecedor e tipo. Classificar o fornecedor
  com todos os itens do período muda o resultado: uma nota monotipo CST 40 e
  outra monotipo CST 41 seriam tratadas incorretamente como mais de um tipo.
- As classificações 6, 10 e 12 exigem presença de pelo menos um CST de cada
  grupo informado; atualmente não proíbem a existência de CSTs adicionais.
- A diferença para a base pode ser diferente de zero porque as 16 categorias
  são filtros de análise, não uma partição declarada de todas as combinações
  possíveis de CST, fonte e perfil de fornecedor.
- Antes de incluir novos CSTs, atualize tanto o `CASE` de `TIPO_TRIBUTACAO`
  quanto os indicadores de grupos de CST em `FORNECEDOR_TRIBUTACAO`.
