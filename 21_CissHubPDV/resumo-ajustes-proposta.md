# Resumo dos ajustes propostos - Integração PDV via PostgreSQL

Baseado no documento `stbd-56-report.pdf` (revisão de 20/08/2026).

## Síntese

A proposta mantém o desenho de sincronização incremental por **NSU** (número sequencial de atualização), usando `INSERT ... ON CONFLICT ... DO UPDATE ... WHERE` para evitar atualizações sem mudança real. Porém, recomenda **não colocar a solução em produção no formato atual**, pois há riscos de perda silenciosa de dados e lacunas funcionais. Os ajustes sugeridos preservam o modelo geral, mas reforçam sua correção, desempenho, operação e governança.

## Ajustes prioritários para produção (P0)

- Corrigir o risco de perda de registros causado por a ordem de `nextval()` não acompanhar a ordem de `COMMIT` em transações concorrentes. Para escritor único, usar lock consultivo transacional; se houver paralelismo, publicar apenas uma janela segura de NSUs por lote.
- Definir e implementar a propagação de exclusões. Sugere-se exclusão lógica com NSU ou uma tabela de tombstones/log de exclusões, para que o PDV remova dados que deixaram de existir na origem.
- Criar um caminho de carga inicial: backfill controlado dos NSUs ou, preferencialmente, endpoint de snapshot/carga completa seguido do incremental.
- Criar índice B-tree em `IDNSU` em todas as tabelas sincronizadas (ou índice composto, como `(idempresa, idnsu)`, se a API filtrar por empresa/loja).
- Garantir que triggers de NSU não possam ser desabilitadas silenciosamente (`ENABLE ALWAYS`) e monitorar linhas com `IDNSU = 0`.
- Ajustar a API para usar parâmetros tipados, `ORDER BY IDNSU`, `LIMIT` e paginação. O PDV deve avançar o watermark apenas após aplicar os registros recebidos.
- Separar credenciais: papel de escrita para o Sync e papel somente leitura para a API; não usar o superusuário `postgres`. Exigir TLS com validação do servidor (`sslmode=verify-full`).
- Fechar as definições de concorrência, exclusões, granularidade do watermark e filtro por empresa antes de escolher a implementação final.

## Ajustes antes da expansão para a base instalada (P1)

- Incluir um **epoch/identificador de instância** no contrato da API. Quando o banco for recriado ou restaurado, o PDV detecta a mudança, zera seu watermark e executa carga completa.
- Medir volumetria pelo maior perfil de cliente: PDVs, frequência de polling, tamanho das tabelas e taxa de alterações. Validar também que o PDV suporta NSU de 64 bits ponta a ponta.
- Criar teste permanente de idempotência: uma segunda carga idêntica deve gerar zero novos NSUs.
- Substituir as 43 funções de trigger duplicadas por uma função genérica, mantendo sequences, triggers e índices por tabela. Criar script automatizado que valide a conformidade das 43 tabelas no deploy e em produção.
- Instituir versionamento de banco, ordem de aplicação, rollback e compatibilidade entre versão do hub e versão do PDV/API.
- Ajustar `fillfactor`, autovacuum e timeouts por tabela/papel; prever manutenção de bloat após backfill.
- Implementar reconciliação periódica entre DB2, hub PostgreSQL e PDV, além de ressincronização total remota e alertas para PDVs com watermark estagnado.

## Melhorias recomendadas (P2)

- Criar endpoint de "o que mudou" para que o PDV consulte apenas tabelas alteradas, reduzindo o polling de 43 tabelas.
- Avaliar uma outbox/tabela única de eventos como evolução do modelo. Ela pode centralizar exclusões, criar cursor global, melhorar a consistência entre tabelas relacionadas e reduzir o impacto dos índices de NSU nas tabelas de negócio.
- Renomear o conceito de "versionamento de registros" para algo como "controle de alterações incrementais", pois o modelo guarda apenas o estado atual, e não o histórico.

## Pontos que precisam de decisão do time

1. Se o Sync terá um único escritor ou cargas paralelas.
2. Como exclusões no DB2 serão detectadas e propagadas.
3. Se o PDV manterá um NSU por tabela ou um cursor global.
4. Se a API entrega dados por empresa/loja ou toda a base do cliente.
5. Volumetria real por perfil de cliente.
6. Suporte a inteiro de 64 bits, inclusive no banco e na serialização do PDV.
7. Existência de PK/índice único compatível em todas as tabelas.
8. Implementação completa das funções e triggers de NSU.

## Conclusão

O parecer não propõe abandonar a integração PostgreSQL/NSU. Ele propõe endurecer o desenho antes do rollout para evitar divergências invisíveis no PDV, especialmente preço, promoção e vínculos desatualizados. A prioridade é garantir entrega ordenada e completa, carga inicial, exclusões, consulta paginada/indexada e operação segura em uma frota de hubs por cliente.
