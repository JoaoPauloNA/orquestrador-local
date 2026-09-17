# Matriz de aceite T01–T23 — 2026-09-06

Classificações permitidas: PASSOU, FALHOU, NÃO EXECUTADO. Uma cobertura parcial não vira aprovação.

| Teste | Status | Evidência/limite |
|---|---|---|
| T01 | PASSOU | 11 testes de `ProfileValidatorTests` cobrem perfil válido e rejeições. |
| T02 | PASSOU | `CatalogStoreTests`: primeira gravação, corrupção posterior e recuperação do backup mais recente (2 testes). |
| T03 | PASSOU | 8 testes de máquina de estados, sem pronto antes da prontidão. |
| T04 | NÃO EXECUTADO | Cobertura parcial: lock por serviço existe e fixture pelo coordenador validou uma ação real, mas não duas instâncias concorrentes. |
| T05 | PASSOU | `LaunchAgentAdapterTests` executa helper que excede 250 ms e confirma retorno limitado, sem bloquear chamador. |
| T06 | NÃO EXECUTADO | Cobertura parcial: fixture real via `OrchestrationCoordinator` atingiu prontidão; abertura via `NSWorkspace` não foi acionada para não abrir navegador. |
| T07 | NÃO EXECUTADO | Cobertura parcial: fixture própria foi descarregada graciosamente pelo produto; preservação de processo externo ainda não foi exercitada. |
| T08 | PASSOU | Fixture real alternou o endpoint para ocupado; o coordenador manteve o job e bloqueou a parada. |
| T09 | NÃO EXECUTADO | Timeout de parada real sem encerrar o fixture ainda não foi exercitado. |
| T10 | NÃO EXECUTADO | Não houve cenário de porta externa concorrente. |
| T11 | NÃO EXECUTADO | Reabertura com serviço em execução não foi exercitada. |
| T12 | NÃO EXECUTADO | Troca real de PID/executável não foi exercitada. |
| T13 | PASSOU | Injeção/metacaracteres, label e caminhos inválidos rejeitados; sem shell. |
| T14 | PASSOU | Evento sanitizado/buffer limitado e pipes stdout/stderr saturados (200 KB cada) drenados com retenção máxima de 512 bytes. |
| T15 | NÃO EXECUTADO | Capturas nativas clara/escura feitas, mas VoiceOver/foco completo não foi aceito manualmente. |
| T16 | NÃO EXECUTADO | Cobertura parcial: medição escopada da fixture pelo produto foi 5,01 s total e 15,8 MB pico; orçamento de app em repouso ainda não medido. |
| T17 | NÃO EXECUTADO | Pilotos reais não foram iniciados (G1 aberto). |
| T18 | NÃO EXECUTADO | Pilotos reais não foram parados (G1 aberto). |
| T19 | NÃO EXECUTADO | Independência dos pilotos não foi exercitada. |
| T20 | NÃO EXECUTADO | Repouso/retomada e desaparecimento não foram exercitados. |
| T21 | NÃO EXECUTADO | Backup/restauração de startup não foi exercitado. |
| T22 | NÃO EXECUTADO | Pacote, `Info.plist` e assinatura ad-hoc foram verificados; abertura final manual pelo Finder sem terminal permanece humana. |
| T23 | NÃO EXECUTADO | Exige três sessões reais e aceite explícito de João. |

Comandos executados: `swift test` (25/25), `scripts/run-fixture-integration.sh` (1 ciclo PASSOU), `scripts/verify-contrast.py` (10/10 pares AA), `scripts/package-app.sh` e `codesign --verify --deep --strict` (PASSOU).
