select '##COLUMNS' from sysibm.sysdummy1@

select
  tabschema || '|' || tabname || '|' || char(colno) || '|' || colname || '|' ||
  typename || '|' || char(length) || '|' || char(scale) || '|' || nulls || '|' ||
  coalesce(default, '')
from syscat.columns
where tabschema = 'DBA'
  and tabname in ('ESTRUTURA_MERCADOLOGICA', 'ESTRUTURA_MERCADOLOGICA_NIVEIS', 'CONFIG_NIVEIS_ESTRUTURA_MERCADOLOGICA', 'DIVISAO')
order by tabname, colno@

select '##CONSTRAINTS' from sysibm.sysdummy1@

select
  tabschema || '|' || tabname || '|' || constname || '|' || type || '|' ||
  coalesce(enforced, '') || '|' || coalesce(enablequeryopt, '')
from syscat.tabconst
where tabschema = 'DBA'
  and tabname in ('ESTRUTURA_MERCADOLOGICA', 'ESTRUTURA_MERCADOLOGICA_NIVEIS', 'CONFIG_NIVEIS_ESTRUTURA_MERCADOLOGICA', 'DIVISAO')
order by tabname, type, constname@

select '##KEYS' from sysibm.sysdummy1@

select
  k.tabschema || '|' || k.tabname || '|' || k.constname || '|' ||
  char(k.colseq) || '|' || k.colname
from syscat.keycoluse k
where k.tabschema = 'DBA'
  and k.tabname in ('ESTRUTURA_MERCADOLOGICA', 'ESTRUTURA_MERCADOLOGICA_NIVEIS', 'CONFIG_NIVEIS_ESTRUTURA_MERCADOLOGICA', 'DIVISAO')
order by k.tabname, k.constname, k.colseq@

select '##REFERENCES' from sysibm.sysdummy1@

select
  r.tabschema || '|' || r.tabname || '|' || r.constname || '|' ||
  r.reftabschema || '|' || r.reftabname || '|' || r.refkeyname || '|' ||
  r.deleterule || '|' || r.updaterule
from syscat.references r
where (r.tabschema = 'DBA'
       and r.tabname in ('ESTRUTURA_MERCADOLOGICA', 'ESTRUTURA_MERCADOLOGICA_NIVEIS', 'CONFIG_NIVEIS_ESTRUTURA_MERCADOLOGICA'))
   or (r.reftabschema = 'DBA'
       and r.reftabname in ('ESTRUTURA_MERCADOLOGICA', 'ESTRUTURA_MERCADOLOGICA_NIVEIS', 'CONFIG_NIVEIS_ESTRUTURA_MERCADOLOGICA'))
order by r.tabname, r.constname@

select '##INDEXES' from sysibm.sysdummy1@

select
  i.tabschema || '|' || i.tabname || '|' || i.indschema || '|' || i.indname || '|' ||
  i.uniquerule || '|' || coalesce(i.colnames, '')
from syscat.indexes i
where i.tabschema = 'DBA'
  and i.tabname in ('ESTRUTURA_MERCADOLOGICA', 'ESTRUTURA_MERCADOLOGICA_NIVEIS', 'CONFIG_NIVEIS_ESTRUTURA_MERCADOLOGICA', 'DIVISAO')
order by i.tabname, i.indname@

select '##DIVISAO_LINK_COLUMN' from sysibm.sysdummy1@

select
  tabschema || '|' || tabname || '|' || char(colno) || '|' || colname || '|' ||
  typename || '|' || char(length) || '|' || char(scale) || '|' || nulls
from syscat.columns
where tabschema = 'DBA'
  and tabname = 'DIVISAO'
  and colname = 'IDNIVELESTRUTURA'
order by colno@

select '##COUNTS' from sysibm.sysdummy1@

select 'ESTRUTURA_MERCADOLOGICA|' || char(count(*)) from DBA.ESTRUTURA_MERCADOLOGICA@
select 'ESTRUTURA_MERCADOLOGICA_NIVEIS|' || char(count(*)) from DBA.ESTRUTURA_MERCADOLOGICA_NIVEIS@
select 'CONFIG_NIVEIS_ESTRUTURA_MERCADOLOGICA|' || char(count(*)) from DBA.CONFIG_NIVEIS_ESTRUTURA_MERCADOLOGICA@
select 'DIVISAO_COM_IDNIVELESTRUTURA|' || char(count(*)) from DBA.DIVISAO where IDNIVELESTRUTURA is not null@

select '##SAMPLES_ESTRUTURA' from sysibm.sysdummy1@
select * from DBA.ESTRUTURA_MERCADOLOGICA fetch first 20 rows only@

select '##SAMPLES_NIVEIS' from sysibm.sysdummy1@
select * from DBA.ESTRUTURA_MERCADOLOGICA_NIVEIS fetch first 50 rows only@

select '##SAMPLES_CONFIG' from sysibm.sysdummy1@
select * from DBA.CONFIG_NIVEIS_ESTRUTURA_MERCADOLOGICA fetch first 50 rows only@

select '##SAMPLES_DIVISAO_LINK' from sysibm.sysdummy1@
select IDNIVELESTRUTURA from DBA.DIVISAO where IDNIVELESTRUTURA is not null fetch first 20 rows only@
