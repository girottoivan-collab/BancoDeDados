# Bases acessiveis

Arquivo de referencia das conexoes de banco identificadas no workspace/local Db2.

## Db2 catalogado localmente

| Alias | Database | Node | Host | Porta | Status |
| --- | --- | --- | --- | --- | --- |
| PRIVADO | PRIVADO | PRIVADO | 10.115.5.1 | 50003 | Catalogada e alcancavel; requer senha para autenticar |
| CISSERP | CISSERP | BDRAFA | 10.115.104.10 | 50001 | Catalogada |
| VIEIRA2 | VIEIRA2 | VIEIRA | 10.115.0.15 | 50159 | Catalogada |
| NOVAMIX | NOVAMIX | NOVAMIX | 10.115.104.20 | 50000 | Catalogada |
| SQLEXEC0 | PRIVADO | SQLEXEC0 | 10.250.4.65 | 40000 | Catalogada |
| EDUARDO | EDUARDO | AUTOEDU | 10.115.105.1 | 25000 | Catalogada |
| VLUZ | VLUZ | DB115 | 10.115.104.20 | 50045 | Catalogada |
| FERRARI | FERRARI | TSTFER | 10.250.0.4 | 50005 | Catalogada |

## SQLTools no workspace

| Nome | Driver | Host | Porta | Database | Observacao |
| --- | --- | --- | --- | --- | --- |
| PRIVADO | Db2 Driver for SQLTools | 10.115.5.1 | 50003 | PRIVADO | Adicionada como base principal para a arquitetura de taxas |
| PRIVADO_NEW_10.5 | Db2 Driver for SQLTools | 10.250.4.65 | 40000 | PRIVADO | Alternativa catalogada como `SQLEXEC0` no Db2 local |
| PRIVADO_NEW_11.5 | Db2 Driver for SQLTools | 10.250.4.65 | 50000 | PRIVADO | Alternativa cadastrada no workspace |

## Observacoes

- Credenciais nao foram registradas neste arquivo.
- A tentativa de conexao ao alias `PRIVADO` chegou ao servidor Db2 e retornou autenticacao pendente por senha ausente.
- Para consultar metadados reais das tabelas, conectar com usuario autorizado e executar consultas no catalogo `SYSCAT.COLUMNS`, `SYSCAT.TABCONST`, `SYSCAT.KEYCOLUSE` e `SYSCAT.REFERENCES`.
