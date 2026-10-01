# Demanda 24 — CATSP: processamento para restituição

O diretório [24_CATSP_Processamento](24_CATSP_Processamento/README.md) concentra a demanda de levantamento de produtos por NCM e composição do saldo de estoque pelas notas de compra, para apoio à restituição de ICMS e ICMS-ST.

Artefatos principais:

- [Implantação completa](24_CATSP_Processamento/01_deploy_catsp_restituicao.sql): tabelas, índices, 208 NCMs e procedure única;
- [Consulta final](24_CATSP_Processamento/02_consulta_final_restituicao_catsp.sql): produtos, estoque, notas, quantidades e valores fiscais;
- [Mapa detalhado das regras](24_CATSP_Processamento/README.md): etapas 1 a 4, fontes, prioridades e resultado validado.
