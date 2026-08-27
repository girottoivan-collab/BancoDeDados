select '##DIVISAO_COUNTS' from sysibm.sysdummy1@
select count(1) from DBA.DIVISAO@
select count(1) from DBA.DIVISAO where IDNIVELESTRUTURA is not null@
select count(1) from DBA.DIVISAO where IDESTRUTURAPAI is not null@

select '##DIVISAO_LINKS' from sysibm.sysdummy1@
select
  d.IDDIVISAO,
  d.DESCRDIVISAO,
  d.IDNIVELESTRUTURA,
  c.DESCRNIVEL,
  d.IDESTRUTURAPAI,
  e.DESCRESTRUTURA
from DBA.DIVISAO d
left join DBA.CONFIG_NIVEIS_ESTRUTURA_MERCADOLOGICA c
  on c.IDNIVELESTRUTURA = d.IDNIVELESTRUTURA
left join DBA.ESTRUTURA_MERCADOLOGICA e
  on e.IDESTRUTURA = d.IDESTRUTURAPAI
where d.IDNIVELESTRUTURA is not null
   or d.IDESTRUTURAPAI is not null
order by d.IDDIVISAO
fetch first 50 rows only@

select '##FK_RULES_WITH_COLUMNS' from sysibm.sysdummy1@
select
  r.tabname,
  r.constname,
  strip(r.fk_colnames) as fk_colnames,
  r.reftabname,
  strip(r.pk_colnames) as pk_colnames,
  r.deleterule,
  r.updaterule
from syscat.references r
where (r.tabschema = 'DBA'
       and r.tabname in ('ESTRUTURA_MERCADOLOGICA', 'ESTRUTURA_MERCADOLOGICA_NIVEIS', 'CONFIG_NIVEIS_ESTRUTURA_MERCADOLOGICA', 'DIVISAO'))
   or (r.reftabschema = 'DBA'
       and r.reftabname in ('ESTRUTURA_MERCADOLOGICA', 'ESTRUTURA_MERCADOLOGICA_NIVEIS', 'CONFIG_NIVEIS_ESTRUTURA_MERCADOLOGICA'))
order by r.tabname, r.constname@
