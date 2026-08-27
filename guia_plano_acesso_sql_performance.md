# Guia de Estudos: Plano de Acesso SQL e Performance de Query

Este artigo explica conceitos importantes para analisar planos de acesso SQL, especialmente em ambientes como Db2, mas os principios tambem se aplicam a outros bancos relacionais.

O foco e entender como o banco acessa os dados, onde ele filtra, quanto ele le, quanto ele busca na tabela e qual o custo real das decisoes do otimizador.

## 1. O Que E Um Plano De Acesso

Um plano de acesso e a estrategia escolhida pelo otimizador do banco para executar uma consulta SQL.

Quando uma query e enviada ao banco, ela nao e executada simplesmente na ordem textual em que foi escrita. O otimizador avalia varias alternativas:

- ler a tabela inteira;
- usar um indice;
- combinar varios indices;
- fazer join por nested loop, hash join ou merge join;
- aplicar filtros antes ou depois;
- ordenar dados;
- buscar linhas na tabela base;
- usar estatisticas para estimar cardinalidade.

Exemplo:

```sql
SELECT *
FROM pedido
WHERE id_cliente = 10
  AND status = 'ABERTO';
```

O banco pode decidir:

```text
1. Usar indice em ID_CLIENTE
2. Buscar as linhas na tabela PEDIDO
3. Filtrar STATUS = 'ABERTO'
```

Ou:

```text
1. Usar indice composto em ID_CLIENTE, STATUS
2. Buscar apenas as linhas relevantes
```

A diferenca entre esses dois planos pode ser enorme.

A pergunta central ao ler um plano e:

```text
Em que momento o plano reduz a quantidade de linhas?
```

Quanto mais cedo o plano reduz linhas, maior a chance de ele ser eficiente.

## 2. Table Scan Direto Em Tabelas Gigantes

### 2.1 O Que E Table Scan

`TABLE SCAN` e quando o banco le diretamente a tabela, pagina por pagina, sem usar um indice como principal caminho de acesso.

Exemplo:

```sql
SELECT *
FROM cliente
WHERE cidade = 'SAO PAULO';
```

Se nao houver indice util em `cidade`, o banco pode precisar ler todas as linhas da tabela `cliente`.

Em plano simplificado:

```text
TABLE SCAN CLIENTE
  Predicate: CIDADE = 'SAO PAULO'
```

### 2.2 Por Que E Perigoso Em Tabelas Grandes

Em uma tabela pequena, um table scan pode ser barato. Em uma tabela gigante, ele pode ser extremamente caro.

Imagine uma tabela com 800 milhoes de linhas:

```text
Tabela: TRANSACAO
Linhas: 800.000.000
Filtro: ID_CLIENTE = 12345
Resultado esperado: 50 linhas
```

Se o banco faz table scan, ele pode ler uma massa enorme de dados para encontrar poucas linhas.

Impactos:

- alto consumo de I/O;
- alto consumo de CPU;
- maior tempo de resposta;
- maior pressao sobre buffer pool/cache;
- possivel degradacao para outras queries;
- maior chance de lock/latch contention;
- execucao imprevisivel em horarios de pico.

### 2.3 Quando Table Scan Pode Ser Bom

Nem todo table scan e ruim.

Ele pode ser adequado quando:

- a tabela e pequena;
- a consulta retorna grande parte da tabela;
- o indice e pouco seletivo;
- a leitura sequencial e mais barata que muitos acessos randomicos;
- a query precisa fazer processamento analitico em massa;
- ha paralelismo eficiente;
- a tabela esta em memoria/cache;
- a estatistica indica que o indice nao compensa.

Exemplo:

```sql
SELECT COUNT(*)
FROM pedido
WHERE status IN ('FATURADO', 'ENTREGUE');
```

Se 90% da tabela esta nesses status, usar indice talvez nao ajude.

### 2.4 Sinais De Alerta

Um table scan merece investigacao quando:

- a tabela tem milhoes ou bilhoes de linhas;
- o filtro deveria retornar poucas linhas;
- existe predicado aparentemente seletivo;
- a query e OLTP e precisa responder rapido;
- o plano mostra cardinalidade estimada muito maior ou menor que a real;
- ha funcao aplicada na coluna filtrada;
- ha conversao implicita;
- o banco ignora um indice que parecia util.

Exemplo problematico:

```sql
SELECT *
FROM pedido
WHERE YEAR(data_pedido) = 2026;
```

Mesmo com indice em `data_pedido`, a funcao `YEAR()` pode impedir o uso eficiente do indice.

Melhor:

```sql
SELECT *
FROM pedido
WHERE data_pedido >= '2026-01-01'
  AND data_pedido <  '2027-01-01';
```

## 3. FETCH Em Tabela

### 3.1 O Que E FETCH

Em planos de acesso, `FETCH` geralmente representa o acesso a tabela base apos o banco localizar candidatos por meio de um indice.

O indice aponta para as linhas, mas nem sempre contem todas as colunas necessarias.

Exemplo:

```sql
SELECT nome, email
FROM cliente
WHERE cpf = '12345678900';
```

Se existe indice apenas em `cpf`:

```text
IXSCAN IDX_CLIENTE_CPF
FETCH CLIENTE
```

O indice localiza a linha pelo CPF, mas o banco precisa buscar `nome` e `email` na tabela.

### 3.2 FETCH Nao E Erro

`FETCH` e uma operacao normal. O problema e o volume.

Buscar uma linha na tabela apos acessar um indice e barato.

Buscar milhoes de linhas por `FETCH` pode ser muito caro.

Exemplo:

```sql
SELECT *
FROM pedido
WHERE status = 'ABERTO';
```

Se `status = 'ABERTO'` retorna 40% da tabela, o plano pode fazer:

```text
IXSCAN IDX_PEDIDO_STATUS
FETCH PEDIDO
```

Isso pode gerar milhoes de acessos a tabela. Dependendo da organizacao fisica dos dados, pode ser pior que um table scan.

### 3.3 Indice Cobridor

Um indice e cobridor quando contem todas as colunas necessarias para resolver a consulta sem acessar a tabela base.

Exemplo:

```sql
SELECT id_cliente, status
FROM pedido
WHERE id_cliente = 10;
```

Indice:

```sql
CREATE INDEX ix_pedido_cliente_status
ON pedido (id_cliente, status);
```

Nesse caso, o banco pode resolver a query apenas pelo indice:

```text
IXSCAN IDX_PEDIDO_CLIENTE_STATUS
```

Sem `FETCH`.

Mas indice cobridor deve ser usado com cuidado. Incluir colunas demais aumenta:

- espaco em disco;
- custo de escrita;
- custo de manutencao;
- tamanho das paginas de indice;
- chance de piorar cache.

### 3.4 Quando FETCH E Preocupante

O `FETCH` merece atencao quando:

- vem depois de indice pouco seletivo;
- ocorre dentro de nested loop executado muitas vezes;
- busca muitas colunas;
- aparece apos `IXAND` com muitos candidatos;
- o predicado mais seletivo so e aplicado depois dele;
- ha milhoes de linhas estimadas ou reais passando pela operacao.

Regra pratica:

```text
Indice bom reduz muito antes do FETCH.
Indice fraco apenas transforma table scan em milhoes de buscas randomicas.
```

## 4. IXAND Em Ramo

### 4.1 O Que E IXAND

`IXAND` significa intersecao de indices. O banco usa dois ou mais indices e combina os resultados, mantendo apenas as linhas que aparecem em todos eles.

Exemplo:

```sql
SELECT *
FROM pedido
WHERE id_cliente = 10
  AND status = 'ABERTO';
```

Indices existentes:

```sql
CREATE INDEX ix_pedido_cliente ON pedido(id_cliente);
CREATE INDEX ix_pedido_status  ON pedido(status);
```

Plano possivel:

```text
IXSCAN IX_PEDIDO_CLIENTE
IXSCAN IX_PEDIDO_STATUS
IXAND
FETCH PEDIDO
```

O banco busca linhas por cliente, busca linhas por status, cruza as duas listas e depois acessa a tabela.

### 4.2 Quando IXAND E Bom

`IXAND` pode ser bom quando cada indice reduz bastante o conjunto.

Exemplo:

```text
Tabela PEDIDO: 100.000.000 linhas

ID_CLIENTE = 10
=> 2.000 linhas

STATUS = 'CANCELADO'
=> 500.000 linhas

Intersecao
=> 20 linhas
```

Nesse caso, usar dois indices pode ser vantajoso.

### 4.3 Quando IXAND E Ruim

`IXAND` pode ser ruim quando um ou mais ramos tem baixa seletividade.

Exemplo:

```text
STATUS = 'ABERTO'
=> 70.000.000 linhas
```

Cruzar uma lista enorme com outra lista pode consumir CPU, memoria e I/O sem ganho suficiente.

Plano suspeito:

```text
IXSCAN IX_STATUS       -- retorna linhas demais
IXSCAN IX_EMPRESA      -- retorna linhas demais
IXAND
FETCH TABELA
```

Aqui talvez um indice composto seja melhor.

### 4.4 IXAND Versus Indice Composto

Indice composto:

```sql
CREATE INDEX ix_pedido_cliente_status
ON pedido(id_cliente, status);
```

Pode ser melhor porque o banco navega diretamente para a combinacao desejada.

Em vez de:

```text
buscar cliente
buscar status
cruzar listas
buscar tabela
```

Ele faz:

```text
buscar cliente + status no mesmo indice
buscar tabela se necessario
```

Mas a ordem das colunas importa.

Para:

```sql
WHERE id_cliente = ?
  AND status = ?
```

um indice `(id_cliente, status)` pode funcionar muito bem.

Para:

```sql
WHERE status = ?
  AND data_pedido >= ?
```

talvez `(status, data_pedido)` seja melhor, dependendo da seletividade.

## 5. Predicados Do Plano

### 5.1 O Que Sao Predicados

Predicados sao as condicoes usadas para filtrar, unir ou restringir dados.

Eles aparecem em:

- `WHERE`;
- `JOIN ... ON`;
- `HAVING`;
- subqueries;
- constraints;
- views;
- CTEs.

Exemplo:

```sql
SELECT *
FROM pedido p
JOIN cliente c
  ON c.id_cliente = p.id_cliente
WHERE p.status = 'ABERTO'
  AND p.data_pedido >= '2026-01-01';
```

Predicados:

```text
c.id_cliente = p.id_cliente
p.status = 'ABERTO'
p.data_pedido >= '2026-01-01'
```

### 5.2 O Mais Importante: Onde O Predicado E Aplicado

Nao basta saber que o predicado existe. E preciso saber em que etapa ele e aplicado.

Um mesmo predicado pode ser:

- usado para acessar indice;
- aplicado durante varredura do indice;
- aplicado apos buscar linha na tabela;
- aplicado apos join;
- aplicado como filtro residual.

Quanto mais cedo for aplicado, melhor.

Exemplo eficiente:

```text
IXSCAN IDX_PEDIDO_STATUS_DATA
  Predicate: STATUS = 'ABERTO'
  Predicate: DATA_PEDIDO >= '2026-01-01'
FETCH PEDIDO
```

Exemplo menos eficiente:

```text
TABLE SCAN PEDIDO
FETCH/Filter
  Predicate: STATUS = 'ABERTO'
  Predicate: DATA_PEDIDO >= '2026-01-01'
```

### 5.3 Predicado De Indice

E o predicado que ajuda o banco a navegar no indice.

Exemplo:

```sql
WHERE id_cliente = 10
```

Com indice:

```sql
CREATE INDEX ix_cliente ON pedido(id_cliente);
```

O banco pode ir diretamente a faixa de chaves de `id_cliente = 10`.

### 5.4 Predicado Residual

E uma condicao aplicada depois que as linhas candidatas ja foram lidas.

Exemplo:

```sql
WHERE id_cliente = 10
  AND UPPER(status) = 'ABERTO';
```

O indice em `id_cliente` pode ser usado, mas `UPPER(status)` talvez seja aplicado depois.

```text
IXSCAN IDX_ID_CLIENTE
FETCH PEDIDO
Residual Predicate: UPPER(STATUS) = 'ABERTO'
```

Predicados residuais podem ser caros se aplicados sobre muitas linhas.

## 6. Custo De Escrita

### 6.1 O Que E Custo De Escrita

Todo indice tem um preco.

Quando uma tabela possui indices, cada operacao de escrita precisa manter a tabela e os indices.

Operacoes afetadas:

- `INSERT`;
- `UPDATE`;
- `DELETE`;
- carga massiva;
- reorganizacao;
- replicacao/log;
- manutencao estatistica.

Exemplo:

```sql
CREATE INDEX ix_pedido_cliente ON pedido(id_cliente);
CREATE INDEX ix_pedido_status  ON pedido(status);
CREATE INDEX ix_pedido_data    ON pedido(data_pedido);
```

Um `INSERT` em `pedido` precisa inserir a linha na tabela e atualizar os tres indices.

### 6.2 Indice Acelera Leitura, Mas Cobra Na Escrita

Beneficios do indice:

- reduz leitura;
- melhora joins;
- evita sort;
- permite busca rapida;
- pode cobrir consultas.

Custos do indice:

- ocupa disco;
- aumenta log;
- torna inserts mais lentos;
- torna updates em colunas indexadas mais caros;
- torna deletes mais caros;
- pode causar page splits;
- exige estatisticas atualizadas;
- aumenta complexidade do otimizador.

### 6.3 Exemplo Pratico

Tabela `EVENTO_LOG` recebe 5 milhoes de inserts por dia.

Alguem cria 8 indices para melhorar relatorios ocasionais.

Consequencia:

```text
Cada insert agora atualiza:
1 tabela
+ 8 estruturas de indice
+ log de cada alteracao
```

A escrita pode degradar fortemente.

Nesse caso, talvez seja melhor:

- manter poucos indices essenciais;
- criar tabela agregada;
- usar particionamento;
- mover relatorios para replica;
- criar indice especifico apenas se o ganho justificar;
- separar OLTP de analitico.

### 6.4 Pergunta Correta Antes De Criar Indice

Antes de criar indice, pergunte:

```text
A consulta e frequente?
A consulta e critica?
O filtro e seletivo?
O indice tambem ajuda joins ou ordenacoes?
O indice substitui outro indice existente?
A tabela recebe muita escrita?
O indice sera usado por varias queries?
Existe estatistica confiavel?
```

Indice bom nao e so aquele que melhora uma query. E aquele que melhora o sistema sem cobrar caro demais em outro lugar.

## 7. Saida De Predicados Cheia De Espacos Por Causa De CLOB

### 7.1 O Problema Visual

Em ferramentas de explain, predicados podem ser armazenados como `CLOB`, ou seja, texto grande.

Ao consultar esse conteudo, a saida pode aparecer cheia de espacos, quebras ou alinhamentos estranhos.

Exemplo visual:

```text
PREDICATE_TEXT
-------------------------------------------------------------
"STATUS          =          'ABERTO'          AND
 DATA_PEDIDO     >=         '2026-01-01'"
```

Isso normalmente e apenas formatacao da saida.

### 7.2 Nao Confundir Formatacao Com Logica

Espacos extras no texto exibido nao significam necessariamente que a comparacao SQL usa esses espacos.

O predicado real pode ser simplesmente:

```sql
STATUS = 'ABERTO'
AND DATA_PEDIDO >= '2026-01-01'
```

O problema esta na representacao, nao no predicado em si.

### 7.3 Como Ler Melhor

Ao analisar esse tipo de saida:

- ignore espacos redundantes;
- procure operadores principais;
- identifique colunas;
- identifique constantes;
- identifique funcoes;
- identifique casts;
- veja se ha predicados aplicados cedo ou tarde.

O objetivo nao e ler o CLOB como texto bonito, mas entender a logica do filtro.

## 8. Filtros Que Aparecem Como SARG

### 8.1 O Que E SARG

`SARG` vem de "Search Argument".

Um predicado sargavel e aquele que pode ser usado pelo banco como argumento de busca eficiente, geralmente com indice.

Exemplo sargavel:

```sql
WHERE id_cliente = 10
```

Com indice em `id_cliente`, o banco pode procurar diretamente as chaves relevantes.

### 8.2 Exemplos De Predicados Sargaveis

```sql
WHERE id_cliente = ?
```

```sql
WHERE data_pedido >= ?
```

```sql
WHERE data_pedido BETWEEN ? AND ?
```

```sql
WHERE status IN ('ABERTO', 'PENDENTE')
```

```sql
WHERE codigo >= 100
  AND codigo < 200
```

Esses predicados permitem busca por igualdade, faixa ou lista.

### 8.3 Exemplos Nao Sargaveis

Funcao aplicada na coluna:

```sql
WHERE YEAR(data_pedido) = 2026
```

Expressao na coluna:

```sql
WHERE valor_total * 1.1 > 1000
```

Conversao na coluna:

```sql
WHERE CHAR(id_cliente) = '10'
```

Uso inadequado de wildcard:

```sql
WHERE nome LIKE '%SILVA'
```

Nesses casos, o banco pode ter dificuldade de usar indice eficientemente.

### 8.4 Como Reescrever Para SARG

Ruim:

```sql
WHERE YEAR(data_pedido) = 2026
```

Melhor:

```sql
WHERE data_pedido >= '2026-01-01'
  AND data_pedido <  '2027-01-01'
```

Ruim:

```sql
WHERE UPPER(email) = 'A@B.COM'
```

Possiveis solucoes:

```sql
WHERE email = 'a@b.com'
```

Ou criar coluna normalizada/indexada, dependendo do banco e do modelo:

```text
email_normalizado
```

Ruim:

```sql
WHERE COALESCE(status, 'A') = 'A'
```

Possivel reescrita:

```sql
WHERE status = 'A'
   OR status IS NULL
```

Mas a melhor reescrita depende do banco, indice, estatisticas e distribuicao dos dados.

### 8.5 SARG Nao E Garantia De Plano Bom

Um predicado pode ser SARG e ainda assim nao ser seletivo.

Exemplo:

```sql
WHERE flag_ativo = 'S'
```

Se 99% das linhas tem `flag_ativo = 'S'`, o predicado e sargavel, mas nao ajuda muito.

Por isso, sempre combine:

```text
SARG + seletividade + indice adequado + estatisticas confiaveis
```

## 9. Lookup Repetido Sem Boa Seletividade Adicional

### 9.1 O Que E Lookup Repetido

Lookup repetido acontece quando o banco pega muitas linhas de uma etapa e, para cada uma, faz busca em outra tabela ou indice.

Isso e comum em `Nested Loop Join`.

Exemplo:

```sql
SELECT *
FROM pedido p
JOIN item_pedido i
  ON i.id_pedido = p.id_pedido
WHERE p.status = 'ABERTO';
```

Plano conceitual:

```text
Buscar pedidos abertos
Para cada pedido:
  buscar itens do pedido
```

Se existem poucos pedidos abertos, otimo.

Se existem milhoes, perigoso.

### 9.2 O Problema Da Baixa Seletividade

O lookup repetido e ruim quando a busca interna nao reduz muito.

Exemplo:

```text
Pedidos abertos: 500.000
Itens por pedido: 15
Resultado intermediario: 7.500.000 linhas
```

Se depois ainda houver filtros, sorts ou fetches, o custo cresce muito.

### 9.3 Sinais De Alerta

Investigue quando o plano mostra:

- nested loop com muitas linhas externas;
- busca interna repetida milhares ou milhoes de vezes;
- indice interno pouco seletivo;
- `FETCH` dentro do loop;
- cardinalidade subestimada;
- filtro importante aplicado depois do join;
- lookup em tabela grande sem chave seletiva;
- muitos acessos randomicos.

### 9.4 Exemplo Ruim

```sql
SELECT *
FROM venda v
JOIN cliente c
  ON c.cidade = v.cidade
WHERE v.data_venda >= '2026-01-01';
```

Se `cidade` nao e seletivo, cada venda pode encontrar muitos clientes da mesma cidade.

Plano conceitual:

```text
Para cada venda de 2026:
  procurar clientes da mesma cidade
```

Isso pode explodir.

### 9.5 Como Melhorar

Possiveis solucoes:

- melhorar filtro do lado externo;
- criar indice composto no lado interno;
- adicionar predicado seletivo no join;
- atualizar estatisticas;
- evitar conversoes implicitas;
- revisar cardinalidade estimada;
- usar chave real de relacionamento;
- evitar join por coluna pouco seletiva;
- permitir outro metodo de join, como hash join, quando adequado.

Exemplo melhor:

```sql
SELECT *
FROM venda v
JOIN cliente c
  ON c.id_cliente = v.id_cliente
WHERE v.data_venda >= '2026-01-01';
```

Com indices:

```sql
CREATE INDEX ix_venda_data_cliente
ON venda(data_venda, id_cliente);

CREATE INDEX ix_cliente_id
ON cliente(id_cliente);
```

## 10. Como Analisar Um Plano Na Pratica

### 10.1 Perguntas Principais

Ao abrir um plano, pergunte:

```text
Qual e a tabela principal acessada primeiro?
O plano usa indice ou table scan?
Quantas linhas sao estimadas em cada etapa?
Onde os filtros sao aplicados?
Ha FETCH depois de indice?
Ha IXAND?
Ha nested loop com muitas iteracoes?
Ha sort caro?
Ha join com baixa seletividade?
As estatisticas estao atualizadas?
A cardinalidade estimada parece realista?
```

### 10.2 Ordem De Investigacao

Uma boa sequencia de analise:

1. Identifique tabelas grandes.
2. Veja se ha table scan nelas.
3. Veja os indices usados.
4. Veja predicados aplicados em cada operacao.
5. Compare cardinalidade estimada com volume esperado.
6. Procure `FETCH` em alto volume.
7. Procure `IXAND` com ramos pouco seletivos.
8. Procure nested loops com lookup repetido.
9. Verifique sorts e agrupamentos.
10. Avalie se um novo indice vale o custo de escrita.

## 11. Checklist De Diagnostico

Use este checklist ao revisar uma query lenta:

```text
[ ] Existe table scan em tabela grande?
[ ] O filtro esperado e seletivo?
[ ] O indice usado combina com os predicados?
[ ] O predicado aparece como SARG?
[ ] Ha funcao ou cast na coluna filtrada?
[ ] Ha conversao implicita?
[ ] O FETCH acontece para muitas linhas?
[ ] O indice poderia cobrir a consulta?
[ ] O IXAND esta cruzando listas grandes?
[ ] Um indice composto substituiria melhor multiplos indices?
[ ] Ha nested loop com lookup repetido?
[ ] O lado externo do loop retorna linhas demais?
[ ] O lado interno tem indice seletivo?
[ ] Os predicados importantes sao aplicados cedo?
[ ] As estatisticas estao atualizadas?
[ ] A cardinalidade estimada faz sentido?
[ ] Um novo indice prejudicaria muito a escrita?
```

## 12. Resumo Final

`TABLE SCAN` em tabela gigante e perigoso quando a consulta deveria retornar poucas linhas.

`FETCH` e normal apos uso de indice, mas fica caro quando acontece em grande volume.

`IXAND` combina indices, mas so costuma valer a pena quando os ramos sao seletivos.

Predicados precisam ser analisados pelo local onde sao aplicados, nao apenas por existirem na query.

`SARG` indica que o predicado pode ser usado como argumento de busca, mas nao garante boa seletividade.

CLOB com espacos em saida de explain geralmente e ruido de formatacao.

Lookup repetido sem seletividade adicional e um dos padroes mais perigosos, porque multiplica acessos e pode transformar uma consulta aparentemente simples em uma operacao massiva.

A ideia central de performance SQL e simples:

```text
Filtrar cedo.
Ler pouco.
Buscar pouco.
Ordenar pouco.
Repetir pouco.
Indexar com criterio.
```

Bons planos reduzem o volume rapidamente. Planos ruins carregam muita linha por muito tempo e so filtram tarde.
