# Implementação Segunda Mente + Orquestrador — 2026-09-15

Data: 2026-09-15
Comando/fonte: inspeção local, `npm run test:selectors`, `npm run build`, `npm run typecheck`, `swift test`, `swift test --filter ManagedServiceCatalogTests`, `curl` no endpoint local de preços e navegador no build de produção.
Esperado: preparar preços/tokens do DevFlow no dashboard e registrar os três serviços em configuração declarativa sem expor segredos ou alterar pilotos reais.
Observado: dashboard `/benchmarks/usage` carregou 227 execuções, seis gráficos, cards e drill-down; endpoint `/api/pricing/refresh` atualizou cinco aliases pelo catálogo público do OpenRouter; `services.yaml` foi empacotado e os três plists existentes passaram pela validação de contrato.
Classificação: IMPLEMENTADO para a fatia independente; PARCIAL para a migração operacional dos pilotos.
Artefatos: `config/model-pricing-aliases.json`, `data/generated/openrouter-model-prices.json`, `src/integrations/usage/usage-service.ts`, `src/app/benchmarks/usage/page.tsx`, `Sources/OrquestradorLocal/Resources/services.yaml`.

## Backup

`/Users/joaopaulo/Documents/Backups/sm-orquestrador-20260915-045355` foi criado antes das alterações, com SHA-256 e sem arquivos `.env`, chaves ou dependências.

## Evidências

- SM: `npm run test:selectors` — OK; `npm run build` — OK; `npm run typecheck` — OK.
- OpenRouter: resposta HTTP 200 de `https://openrouter.ai/api/v1/models`; cache gravado com `fetched_at`, origem, preços de entrada/saída/cache e status por alias.
- Cálculo: teste independente confirmou `uncached_input = max(input - cached, 0)` e que cached não é contado duas vezes.
- Navegador: build de produção respondeu em loopback e exibiu tokens por workflow/modelo/agente, custos por workflow/modelo/agente, atualização de preços e drill-down.
- Orquestrador: `swift test` — 46 testes OK; contratos dos três LaunchAgents existentes passaram; nenhum serviço real foi iniciado, parado ou reiniciado.

## Limitações e rollback

G0/G1/G2/G3 continuam abertos. Os dois LaunchAgents históricos do mflux e o auto-start do ComfyUI não foram desabilitados, porque a documentação do projeto exige janela G1 e aceite humano antes da migração. O rollback da implementação é restaurar o backup acima e remover apenas os arquivos novos desta rodada; os plists originais permanecem intactos.
