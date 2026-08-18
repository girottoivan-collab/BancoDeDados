-- CISS-181212 - sugestoes de melhoria
-- Nao execute direto em producao sem janela e validacao previa.

-- 1) Primeira acao recomendada: atualizar estatisticas.
-- Ajustar politica conforme padrao do ambiente.

RUNSTATS ON TABLE DBA.NOTAS_ENTRADA_SAIDA
    WITH DISTRIBUTION
    AND DETAILED INDEXES ALL;

RUNSTATS ON TABLE DBA.PISCOFINS_MOVIMENTO
    WITH DISTRIBUTION
    AND DETAILED INDEXES ALL;

RUNSTATS ON TABLE DBA.NOTAS
    WITH DISTRIBUTION
    AND DETAILED INDEXES ALL;

RUNSTATS ON TABLE DBA.NOTAS_DEVOLUCAO
    WITH DISTRIBUTION
    AND DETAILED INDEXES ALL;

RUNSTATS ON TABLE DBA.NOTA_FISCAL_ELETRONICA
    WITH DISTRIBUTION
    AND DETAILED INDEXES ALL;

RUNSTATS ON TABLE DBA.NOTA_FISCAL_CONSUMIDOR_ELETRONICA
    WITH DISTRIBUTION
    AND DETAILED INDEXES ALL;

-- 2) Indice candidato para reduzir o conjunto inicial de notas por empresa/data/categoria.
-- Validar por EXPLAIN antes/depois e tempo real da consulta.

-- CREATE INDEX DBA.IDX_NES_EMP_DTEMIS_CAT_PLA_OPE
--     ON DBA.NOTAS_ENTRADA_SAIDA
--     (IDEMPRESA, DTEMISSAO, TIPOCATEGORIA, IDPLANILHA, IDOPERACAO);

-- 3) Indice candidato para reduzir lookups/fetches em PISCOFINS_MOVIMENTO.
-- A tabela e muito grande; validar espaco, tempo de criacao e impacto em escrita.

-- CREATE INDEX DBA.IDX_PM_EMP_PLA_PIS_COF_BASE_PROD
--     ON DBA.PISCOFINS_MOVIMENTO
--     (IDEMPRESA, IDPLANILHA, PERPIS, PERCOFINS, VALBASEPISCOFINS,
--      IDPRODUTO, IDSUBPRODUTO, NUMSEQUENCIA);

-- 4) Depois de qualquer RUNSTATS/indice, recoletar o plano:
--
-- SET CURRENT EXPLAIN MODE EXPLAIN;
-- <consulta original>
-- SET CURRENT EXPLAIN MODE NO;
