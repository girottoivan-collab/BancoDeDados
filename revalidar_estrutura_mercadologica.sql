select '##CONEXAO' from sysibm.sysdummy1@
select
  current server,
  current schema,
  current user
from sysibm.sysdummy1@

select '##TABELAS_ENCONTRADAS' from sysibm.sysdummy1@
select
  tabschema,
  tabname,
  type,
  status
from syscat.tables
where tabname in (
  'ESTRUTURA_MERCADOLOGICA',
  'ESTRUTURA_MERCADOLOGICA_NIVEIS',
  'CONFIG_NIVEIS_ESTRUTURA_MERCADOLOGICA'
)
order by tabschema, tabname@

select '##COUNTS_DBA' from sysibm.sysdummy1@
select 'DBA.ESTRUTURA_MERCADOLOGICA', count(1) from DBA.ESTRUTURA_MERCADOLOGICA@
select 'DBA.ESTRUTURA_MERCADOLOGICA_NIVEIS', count(1) from DBA.ESTRUTURA_MERCADOLOGICA_NIVEIS@
select 'DBA.CONFIG_NIVEIS_ESTRUTURA_MERCADOLOGICA', count(1) from DBA.CONFIG_NIVEIS_ESTRUTURA_MERCADOLOGICA@

select '##SAMPLE_ESTRUTURA' from sysibm.sysdummy1@
select
  IDESTRUTURA,
  DESCRESTRUTURA,
  IDESTRUTURAPAI
from DBA.ESTRUTURA_MERCADOLOGICA
order by IDESTRUTURA
fetch first 50 rows only@

select '##SAMPLE_NIVEIS' from sysibm.sysdummy1@
select
  IDNIVELESTRUTURA,
  IDESTRUTURA
from DBA.ESTRUTURA_MERCADOLOGICA_NIVEIS
order by IDNIVELESTRUTURA, IDESTRUTURA
fetch first 50 rows only@

select '##SAMPLE_CONFIG' from sysibm.sysdummy1@
select
  IDNIVELESTRUTURA,
  DESCRNIVEL,
  DTALTERACAO
from DBA.CONFIG_NIVEIS_ESTRUTURA_MERCADOLOGICA
order by IDNIVELESTRUTURA@

select '##ARVORE_JOIN' from sysibm.sysdummy1@
select
  e.IDESTRUTURA,
  e.DESCRESTRUTURA,
  e.IDESTRUTURAPAI,
  n.IDNIVELESTRUTURA,
  c.DESCRNIVEL
from DBA.ESTRUTURA_MERCADOLOGICA e
left join DBA.ESTRUTURA_MERCADOLOGICA_NIVEIS n
  on n.IDESTRUTURA = e.IDESTRUTURA
left join DBA.CONFIG_NIVEIS_ESTRUTURA_MERCADOLOGICA c
  on c.IDNIVELESTRUTURA = n.IDNIVELESTRUTURA
order by e.IDESTRUTURA, n.IDNIVELESTRUTURA
fetch first 100 rows only@
