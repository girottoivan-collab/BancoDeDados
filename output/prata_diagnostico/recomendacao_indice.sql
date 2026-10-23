-- Proposta para homologacao. NAO executada no MEUPRATA.
-- A correcao imediata validada utiliza um indice existente;
-- este indice adicional nao e necessario para aplicar essa correcao.
CREATE INDEX DBA.IX_CR_EMP_VENC_ADM_ORIG
    ON DBA.CONTAS_RECEBER
       (IDEMPRESA, DTVENCIMENTO, IDADMINISTRADORA, ORIGEMMOVIMENTO);

-- Coletar estatisticas do novo indice apos a criacao.
RUNSTATS ON TABLE DBA.CONTAS_RECEBER
    FOR INDEXES DBA.IX_CR_EMP_VENC_ADM_ORIG;

-- Depois: gerar novo EXPLAIN sem guideline, testar diferentes
-- administradoras/intervalos, medir impacto em INSERT/UPDATE e espaco.
