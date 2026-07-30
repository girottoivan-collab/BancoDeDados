# Metodo de conexao Db2 no Windows

Este arquivo registra o metodo que funcionou para conectar em bases Db2 catalogadas localmente neste workspace.

## Metodo recomendado

No Windows, usar o `db2cmd` para inicializar o ambiente de linha de comando do Db2 antes de executar comandos `db2`.

Exemplo de conexao:

```powershell
db2cmd /c /w /i db2 connect to <ALIAS_BANCO> user <USUARIO> using <SENHA>
```

Exemplo de execucao de script SQL com delimitador `;`:

```powershell
db2cmd /c /w /i db2 -tvf caminho\do\script.sql
```

Exemplo de execucao de consulta direta:

```powershell
db2cmd /c /w /i db2 -x "select current date from sysibm.sysdummy1"
```

## Catalogar nova base

Quando a base ainda nao existir no diretorio local do Db2, catalogar primeiro o node e depois o database:

```powershell
db2cmd /c /w /i db2 catalog tcpip node <NOME_NODE> remote <HOST> server <PORTA>
db2cmd /c /w /i db2 catalog database <DATABASE> as <ALIAS_BANCO> at node <NOME_NODE> authentication server
db2cmd /c /w /i db2 terminate
```

Depois conectar usando o alias catalogado:

```powershell
db2cmd /c /w /i db2 connect to <ALIAS_BANCO> user <USUARIO> using <SENHA>
```

## Validacoes uteis

Listar nodes catalogados:

```powershell
db2cmd /c /w /i db2 list node directory
```

Listar bancos catalogados:

```powershell
db2cmd /c /w /i db2 list database directory
```

Consultar colunas reais no catalogo Db2:

```powershell
db2cmd /c /w /i db2 -x "select tabname, colname, typename from syscat.columns where tabschema = 'DBA' and tabname = '<TABELA>' order by colno"
```

## Observacoes

- Executar `db2.exe` diretamente no PowerShell pode retornar `DB21061E Ambiente de linha de comando nao inicializado`.
- Quando isso ocorrer, repetir o comando via `db2cmd /c /w /i`.
- Para scripts com varios comandos e `CONNECT`, preferir arquivo `.sql` executado por `db2 -tvf`.
- Nao registrar senhas neste arquivo; usar placeholders ou o cadastro SQLTools quando a senha precisar ficar disponivel no workspace.
