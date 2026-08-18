# DB2 Page Size, Tamanho de Linha e Boas Praticas

## Objetivo

Este documento explica o conceito de `page size` no DB2 e como ele afeta a criacao e alteracao de tabelas, especialmente quando existem colunas textuais grandes como `VARCHAR(2000)`, logs, payloads, mensagens, XML ou JSON.

Use este material como apoio para decisoes de modelagem fisica e para evitar erros como:

```text
SQL0670N A instrucao falhou porque o tamanho da linha ou coluna da tabela
resultante excederia o limite de tamanho da linha ou coluna.
Nome do espaco de tabela: "USERSPACE1".
Tamanho da linha ou coluna resultante: "4244".
SQLSTATE=54010
```

## Resumo Executivo

No DB2, os dados de uma tabela sao armazenados em paginas dentro de um tablespace.

O `page size` define o tamanho dessas paginas. Em um tablespace com pagina de `4 KB`, o limite util para uma linha pode ficar proximo de `4005 bytes`, pois parte da pagina e usada por controles internos do DB2.

Quando a soma maxima das colunas de uma linha ultrapassa esse limite, o DB2 impede a criacao ou alteracao da tabela.

Em tabelas com campos textuais grandes, como logs e mensagens, prefira:

- `CLOB` para textos longos, payloads, logs, XML, JSON e corpos de mensagem.
- Tablespaces com page size maior, como `8K`, `16K` ou `32K`, quando houver necessidade real de manter colunas grandes inline.
- `VARCHAR` menor apenas quando houver regra de negocio clara para limitar o conteudo.

## Exemplo Real

Tabela original:

```sql
CREATE TABLE MESSENGER.MENSAGERIA_HISTORICO (
    IDMENSAGEMHISTORICO INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    IDMENSAGEM          INTEGER NOT NULL,
    IDSTATUS            INTEGER,
    KEYID               VARCHAR(200),
    DTENVIO             TIMESTAMP,
    DSLOG               VARCHAR(2000)
);
```

Alteracao desejada:

```sql
ALTER TABLE MESSENGER.MENSAGERIA_HISTORICO
ADD COLUMN DSMENSAGEMENVIADA VARCHAR(2000);
```

Erro apresentado:

```text
Limite permitido no tablespace USERSPACE1: 4005 bytes
Tamanho maximo resultante da linha:       4244 bytes
```

O problema nao esta necessariamente nos dados ja gravados. O problema esta na estrutura maxima possivel da linha.

## O Que E Page Size?

O banco nao grava registros diretamente soltos no disco. Ele organiza os dados em blocos fisicos chamados paginas.

```text
DISCO / STORAGE
┌──────────────────────────────────────────────┐
│ Tablespace USERSPACE1                        │
│                                              │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ │
│  │ Pagina │ │ Pagina │ │ Pagina │ │ Pagina │ │
│  │  4 KB  │ │  4 KB  │ │  4 KB  │ │  4 KB  │
│  └────────┘ └────────┘ └────────┘ └────────┘ │
└──────────────────────────────────────────────┘
```

Uma pagina e a menor unidade fisica que o DB2 usa para armazenar e ler dados de tabelas e indices.

Se o tablespace tem page size de `4K`, cada pagina possui aproximadamente:

```text
4 KB = 4096 bytes
```

Mas nem todos esses bytes ficam disponiveis para os dados da linha. O DB2 usa parte da pagina para controles internos, cabecalhos, metadados e estruturas auxiliares.

Por isso, em muitos cenarios, o limite util de uma linha em tablespace `4K` aparece como algo proximo de:

```text
4005 bytes
```

## Como Uma Linha Cabe Dentro Da Pagina

Uma tabela e composta por linhas. As linhas sao armazenadas dentro das paginas do tablespace.

```text
Pagina DB2 de 4 KB
┌──────────────────────────────────────────────┐
│ Cabecalho interno da pagina                  │
├──────────────────────────────────────────────┤
│ Linha 1                                      │
├──────────────────────────────────────────────┤
│ Linha 2                                      │
├──────────────────────────────────────────────┤
│ Linha 3                                      │
├──────────────────────────────────────────────┤
│ Espaco livre                                 │
└──────────────────────────────────────────────┘
```

Quando uma linha possui muitas colunas ou colunas grandes, ela consome mais espaco dentro da pagina.

```text
Pagina DB2 de 4 KB
┌──────────────────────────────────────────────┐
│ Cabecalho interno                            │
├──────────────────────────────────────────────┤
│ Linha com muitas colunas VARCHAR grandes     │
│ ████████████████████████████████████████████ │
│ ████████████████████████████████████████████ │
│ ████████████████████████████████████████████ │
└──────────────────────────────────────────────┘
```

Se a linha maxima ultrapassar o limite suportado pela pagina, o DB2 bloqueia o comando.

## Por Que O DB2 Considera O Tamanho Maximo?

O DB2 valida a definicao fisica da tabela considerando o pior caso permitido pela estrutura.

Mesmo que os dados atuais sejam pequenos:

```text
DSLOG = 'OK'
DSMENSAGEMENVIADA = 'Enviado'
```

A definicao da tabela permite que esses campos ocupem muito mais:

```text
DSLOG               ate 2000 bytes
DSMENSAGEMENVIADA   ate 2000 bytes
KEYID               ate 200 bytes
Demais colunas      bytes adicionais
Overhead DB2        bytes adicionais
```

Comparacao visual:

```text
Dados reais hoje:
┌──────────────┐
│ linha pequena│
└──────────────┘

Possibilidade permitida pela estrutura:
┌──────────────────────────────────────────────┐
│ linha no tamanho maximo declarado             │
└──────────────────────────────────────────────┘
```

Portanto, o erro ocorre pela capacidade maxima definida no modelo fisico, nao apenas pelo conteudo atual.

## Analise Do Caso MENSAGERIA_HISTORICO

Estrutura final desejada:

```text
Linha da tabela MENSAGERIA_HISTORICO

┌───────────────────────┬───────────────┐
│ Coluna                │ Tamanho aprox. │
├───────────────────────┼───────────────┤
│ IDMENSAGEMHISTORICO   │ 4 bytes        │
│ IDMENSAGEM            │ 4 bytes        │
│ IDSTATUS              │ 4 bytes        │
│ KEYID                 │ ate 200 bytes  │
│ DTENVIO               │ bytes internos │
│ DSLOG                 │ ate 2000 bytes │
│ DSMENSAGEMENVIADA     │ ate 2000 bytes │
│ Overhead DB2          │ bytes extras   │
└───────────────────────┴───────────────┘
```

Representacao do erro:

```text
Limite da pagina USERSPACE1: 4005 bytes
┌──────────────────────────────────────────────┐
│ IDMENSAGEMHISTORICO                          │
│ IDMENSAGEM                                   │
│ IDSTATUS                                     │
│ KEYID ate 200                                │
│ DTENVIO                                      │
│ DSLOG ate 2000                               │
│ DSMENSAGEMENVIADA ate 2000                   │
│ Overhead interno DB2                         │
└──────────────────────────────────────────────┘
                         ↑
                         Passou do limite: 4244 bytes
```

O DB2 precisa garantir que uma linha completa caiba no tablespace. Como a linha maxima resultante seria de `4244 bytes`, mas o limite informado e `4005 bytes`, o `ALTER TABLE` falha.

## Relacao Entre Page Size, Tablespace e Bufferpool

No DB2, o `page size` e uma caracteristica do tablespace.

```text
TABLESPACE USERSPACE1
┌────────────────────────────┐
│ Page size: 4 KB            │
│ Tabelas armazenadas aqui   │
│ Limite de linha menor      │
└────────────────────────────┘

TABLESPACE TS_8K
┌────────────────────────────┐
│ Page size: 8 KB            │
│ Suporta linhas maiores     │
└────────────────────────────┘

TABLESPACE TS_16K
┌────────────────────────────┐
│ Page size: 16 KB           │
│ Suporta linhas ainda maiores│
└────────────────────────────┘
```

O bufferpool tambem precisa ser compativel com o page size do tablespace.

```text
DISCO                         MEMORIA
Tablespace                    Bufferpool
┌────────┐                    ┌────────┐
│ Page 1 │ ────────────────▶  │ Page 1 │
└────────┘                    └────────┘
┌────────┐                    ┌────────┐
│ Page 2 │ ────────────────▶  │ Page 2 │
└────────┘                    └────────┘
```

Relacao esperada:

```text
Tablespace 4K  usa Bufferpool 4K
Tablespace 8K  usa Bufferpool 8K
Tablespace 16K usa Bufferpool 16K
Tablespace 32K usa Bufferpool 32K
```

## Comparativo De Page Size

```text
┌───────────┬──────────────────────────────┬─────────────────────────────┐
│ Page size │ Uso recomendado              │ Observacao                  │
├───────────┼──────────────────────────────┼─────────────────────────────┤
│ 4 KB      │ Tabelas estreitas             │ Bom para linhas pequenas    │
│ 8 KB      │ Tabelas moderadamente largas  │ Bom equilibrio              │
│ 16 KB     │ Tabelas largas                │ Mais margem para VARCHAR    │
│ 32 KB     │ Tabelas muito largas          │ Usar com criterio           │
└───────────┴──────────────────────────────┴─────────────────────────────┘
```

Page size menor:

```text
Pagina 4K
┌──────┬──────┬──────┬──────┐
│linha │linha │linha │linha │
└──────┴──────┴──────┴──────┘
```

Vantagens:

- Menos desperdicio para linhas pequenas.
- Boa eficiencia para tabelas transacionais estreitas.
- Menor leitura desnecessaria por pagina.

Page size maior:

```text
Pagina 16K
┌──────────────────────────────────────────────┐
│ linha grande                                 │
├──────────────────────────────────────────────┤
│ linha grande                                 │
└──────────────────────────────────────────────┘
```

Vantagens:

- Suporta linhas maiores.
- Melhor para tabelas com varios `VARCHAR` grandes.
- Pode ser adequado para historicos, auditorias, logs e mensagens.

Pontos de atencao:

- Pode carregar mais dados do que o necessario em memoria.
- Pode desperdiçar espaco se as linhas forem pequenas.
- Exige bufferpool compativel.
- Nao deve ser usado como solucao automatica para todo problema de modelagem.

## Boas Praticas Para Colunas Textuais Grandes

### 1. Use CLOB para texto longo

Campos que armazenam log, payload, corpo de mensagem, XML, JSON ou textos extensos devem ser avaliados como `CLOB`.

Exemplo:

```sql
ALTER TABLE MESSENGER.MENSAGERIA_HISTORICO
ADD COLUMN DSMENSAGEMENVIADA CLOB(10K);
```

Modelo visual:

```text
Linha principal
┌──────────────────────────────────────┐
│ IDs, status, key, data               │
│ referencia para texto grande         │
└──────────────────────────────────────┘
                   │
                   ▼
Texto grande armazenado como LOB
┌──────────────────────────────────────┐
│ conteudo de DSMENSAGEMENVIADA        │
└──────────────────────────────────────┘
```

Use `CLOB` principalmente quando:

- O campo nao sera usado em filtros frequentes.
- O campo armazena conteudo de auditoria ou diagnostico.
- O campo representa mensagem enviada, mensagem recebida, retorno de API ou payload.
- O tamanho pode crescer com o tempo.

### 2. Nao use VARCHAR grande por padrao

Evite definir `VARCHAR(2000)`, `VARCHAR(4000)` ou tamanhos similares apenas por seguranca.

Antes de usar um `VARCHAR` grande, valide:

- O campo sera frequentemente filtrado?
- O campo participara de indice?
- O tamanho maximo tem justificativa funcional?
- A tabela ja possui outras colunas grandes?
- O tablespace suporta a linha maxima resultante?

### 3. Separe dados operacionais de dados volumosos

Em tabelas de historico, nem todos os campos possuem o mesmo perfil de uso.

Dados operacionais:

```text
┌──────────────────────────────┐
│ IDMENSAGEMHISTORICO          │
│ IDMENSAGEM                   │
│ IDSTATUS                     │
│ KEYID                        │
│ DTENVIO                      │
└──────────────────────────────┘
```

Dados textuais grandes:

```text
┌──────────────────────────────┐
│ DSLOG                        │
│ DSMENSAGEMENVIADA            │
└──────────────────────────────┘
```

Quando o volume textual for alto, considere:

- Colunas `CLOB`.
- Tabela filha para payload/log.
- Retencao diferenciada para logs antigos.
- Compressao, quando aplicavel e homologada.

### 4. Use tablespace maior quando a linha larga for intencional

Quando a necessidade de linhas largas for real e tecnicamente justificada, crie ou use um tablespace com page size maior.

Exemplo conceitual:

```sql
CREATE BUFFERPOOL BP8K SIZE 1000 PAGESIZE 8K;

CREATE TABLESPACE TS_MESSENGER_8K
    PAGESIZE 8K
    MANAGED BY AUTOMATIC STORAGE
    BUFFERPOOL BP8K;
```

Depois, a tabela deve ser criada ou movida para esse tablespace, respeitando constraints, indices, permissoes e dependencias.

## Recomendacao Para O Caso MENSAGERIA_HISTORICO

Para a tabela `MESSENGER.MENSAGERIA_HISTORICO`, a recomendacao arquitetural e tratar `DSMENSAGEMENVIADA` como texto grande.

Recomendado:

```sql
ALTER TABLE MESSENGER.MENSAGERIA_HISTORICO
ADD COLUMN DSMENSAGEMENVIADA CLOB(10K);
```

Se `DSLOG` tambem for um texto longo de diagnostico, avaliar evolucao para:

```sql
DSLOG CLOB(10K)
DSMENSAGEMENVIADA CLOB(10K)
```

Caso exista exigencia para manter ambos como `VARCHAR(2000)`, avaliar a criacao de tablespace com page size maior, como `8K` ou `16K`.

## Checklist Para Revisao De DDL

Antes de aprovar uma alteracao em tabela DB2, valide:

- A tabela possui colunas `VARCHAR` grandes?
- A soma maxima das colunas pode ultrapassar o page size do tablespace?
- Campos grandes sao realmente pesquisaveis ou apenas armazenados?
- `CLOB` seria mais adequado para o dominio do dado?
- O tablespace atual e compativel com a largura esperada da linha?
- Existe bufferpool compativel com o page size desejado?
- A alteracao afeta indices, constraints, procedures, views ou aplicacoes consumidoras?
- Existe plano de migracao e rollback?

## Diretriz Do Time

Para tabelas DB2:

- Use `VARCHAR` para atributos textuais curtos e de uso operacional.
- Use `CLOB` para logs, payloads, mensagens, XML, JSON e textos longos.
- Nao aumente o page size como primeira resposta para toda coluna grande.
- Avalie o desenho logico antes da solucao fisica.
- Em tabelas historicas, separe campos de busca dos campos de conteudo volumoso.
- Documente a justificativa quando uma tabela exigir tablespace com page size maior que `4K`.

## Decisao Rapida

```text
Campo textual curto e usado em filtro?
└── Sim: VARCHAR com tamanho justificado

Campo textual longo, log, payload ou corpo de mensagem?
└── Sim: CLOB

Tabela precisa manter varias colunas grandes inline?
└── Sim: avaliar tablespace 8K, 16K ou 32K

Erro SQL0670N por limite de linha?
└── Revisar modelagem de VARCHAR grandes antes de apenas aumentar page size
```

## Conclusao

`Page size` e o tamanho da pagina fisica usada pelo DB2 para armazenar dados no tablespace. Esse tamanho limita a largura maxima de uma linha.

No caso analisado, a tabela esta em um tablespace cujo limite util informado foi `4005 bytes`. Ao adicionar outro `VARCHAR(2000)`, a linha maxima passou para `4244 bytes`, causando o erro `SQL0670N`.

A solucao arquitetural preferencial para historico de mensageria e usar `CLOB` para conteudos grandes, como `DSLOG` e `DSMENSAGEMENVIADA`. O aumento do page size deve ser considerado quando houver necessidade tecnica clara de manter linhas largas dentro da propria pagina.
