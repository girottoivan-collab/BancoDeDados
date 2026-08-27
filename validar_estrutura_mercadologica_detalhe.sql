select '##SYSCAT_REFERENCES_COLUMNS' from sysibm.sysdummy1@

select colname || '|' || typename || '|' || char(length)
from syscat.columns
where tabschema = 'SYSCAT'
  and tabname = 'REFERENCES'
order by colno@

select '##NEW_TABLE_COLUMNS' from sysibm.sysdummy1@

select
  tabname || '|' ||
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
  and tabname in ('ESTRUTURA_MERCADOLOGICA', 'ESTRUTURA_MERCADOLOGICA_NIVEIS', 'CONFIG_NIVEIS_ESTRUTURA_MERCADOLOGICA')
order by tabname, colno@

select '##DIVISAO_RELEVANT_COLUMNS' from sysibm.sysdummy1@

select
  tabname || '|' ||
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
  and colname in ('IDDIVISAO', 'IDNIVELESTRUTURA', 'IDESTRUTURA', 'DESCRDIVISAO')
order by colno@

select '##CONSTRAINT_COLUMNS' from sysibm.sysdummy1@

select
  k.tabname || '|' ||
  k.constname || '|' ||
  t.type || '|' ||
  digits(k.colseq) || '|' ||
  k.colname
from syscat.keycoluse k
join syscat.tabconst t
  on t.tabschema = k.tabschema
 and t.tabname = k.tabname
 and t.constname = k.constname
where k.tabschema = 'DBA'
  and k.tabname in ('ESTRUTURA_MERCADOLOGICA', 'ESTRUTURA_MERCADOLOGICA_NIVEIS', 'CONFIG_NIVEIS_ESTRUTURA_MERCADOLOGICA', 'DIVISAO')
order by k.tabname, k.constname, k.colseq@

select '##FK_RULES' from sysibm.sysdummy1@

select
  r.tabname || '|' ||
  r.constname || '|' ||
  r.reftabname || '|' ||
  r.refkeyname || '|' ||
  r.deleterule || '|' ||
  r.updaterule
from syscat.references r
where (r.tabschema = 'DBA'
       and r.tabname in ('ESTRUTURA_MERCADOLOGICA', 'ESTRUTURA_MERCADOLOGICA_NIVEIS', 'CONFIG_NIVEIS_ESTRUTURA_MERCADOLOGICA', 'DIVISAO'))
   or (r.reftabschema = 'DBA'
       and r.reftabname in ('ESTRUTURA_MERCADOLOGICA', 'ESTRUTURA_MERCADOLOGICA_NIVEIS', 'CONFIG_NIVEIS_ESTRUTURA_MERCADOLOGICA'))
order by r.tabname, r.constname@

select '##CHECK_CONSTRAINTS' from sysibm.sysdummy1@

select
  tabname || '|' || constname || '|' || varchar(text, 500)
from syscat.checks
where tabschema = 'DBA'
  and tabname in ('ESTRUTURA_MERCADOLOGICA', 'ESTRUTURA_MERCADOLOGICA_NIVEIS', 'CONFIG_NIVEIS_ESTRUTURA_MERCADOLOGICA', 'DIVISAO')
order by tabname, constname@

select '##CONFIG_ROWS' from sysibm.sysdummy1@

select
  varchar(IDNIVELESTRUTURA) || '|' ||
  strip(DESCRNIVEL) || '|' ||
  varchar(DTALTERACAO)
from DBA.CONFIG_NIVEIS_ESTRUTURA_MERCADOLOGICA
order by IDNIVELESTRUTURA@
