select '##DIVISAO_COLUMNS_MATCH' from sysibm.sysdummy1@

select
  digits(colno) || '|' ||
  colname || '|' ||
  typename || '|' ||
  varchar(length) || '|' ||
  varchar(scale) || '|' ||
  nulls || '|' ||
  identity || '|' ||
  generated || '|' ||
  coalesce(varchar(default, 80), '')
from syscat.columns
where tabschema = 'DBA'
  and tabname = 'DIVISAO'
  and colname in ('IDDIVISAO', 'DESCRDIVISAO', 'IDNIVELESTRUTURA', 'IDESTRUTURAPAI')
order by colno@

select '##FK_RULES_WITH_COLUMNS' from sysibm.sysdummy1@

select
  r.tabname || '|' ||
  r.constname || '|' ||
  strip(r.fk_colnames) || '|' ||
  r.reftabname || '|' ||
  strip(r.pk_colnames) || '|' ||
  r.deleterule || '|' ||
  r.updaterule
from syscat.references r
where (r.tabschema = 'DBA'
       and r.tabname in ('ESTRUTURA_MERCADOLOGICA', 'ESTRUTURA_MERCADOLOGICA_NIVEIS', 'CONFIG_NIVEIS_ESTRUTURA_MERCADOLOGICA', 'DIVISAO'))
   or (r.reftabschema = 'DBA'
       and r.reftabname in ('ESTRUTURA_MERCADOLOGICA', 'ESTRUTURA_MERCADOLOGICA_NIVEIS', 'CONFIG_NIVEIS_ESTRUTURA_MERCADOLOGICA'))
order by r.tabname, r.constname@
