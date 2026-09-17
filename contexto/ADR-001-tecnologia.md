# ADR-001 — Swift/SwiftUI + LaunchAgents do usuário

Data: 2026-09-06 | Status: PROPOSTA A VALIDAR — spike F1/F2

## Decisão proposta

Implementar o Orquestrador Local como aplicativo nativo Swift/SwiftUI com menu bar (`MenuBarExtra`), janela de painel, catálogo local e adaptador de LaunchAgents do domínio do usuário. Esta é uma proposta de tecnologia, não uma decisão aprovada. A validade da abordagem será confirmada no spike de F1/F2.

## Contexto

- Alvo: Mac Apple Silicon M5, uso pessoal, sem App Store na V1.
- Requisito: operar sem terminal no uso cotidiano.
- mflux-studio é candidato a piloto; seu mecanismo de execução inclui LaunchAgents (a confirmar em F0 qual label é canônica).
- ComfyUI é candidato a piloto; mecanismo de execução ainda não confirmado.
- Sem necessidade de IA embarcada, API paga ou servidor remoto na V1.

## Alternativas consideradas

| Alternativa | Hipótese de descarte | Qualificação |
|---|---|---|
| Raycast scripts | Possivelmente não mantém estado persistente entre ações independentes; integração com LaunchAgents requer verificação | Hipótese; não testado extensivamente |
| App Electron/web | Runtime mais pesado; dependência de Node; fora do ecossistema nativo macOS | Avaliação qualitativa |
| Script shell + cron | Sem interface visual, sem feedback de estado em tempo real | Fora do escopo declarado |
| Docker Compose | Pilotos atuais não confirmados como containers; escopo futuro conforme plano | Adiado explicitamente no plano |

> As razões de descarte acima são hipóteses de trabalho, não avaliações exaustivas. Se o spike F1/F2 revelar limitações graves na abordagem Swift/LaunchAgents, revisar esta ADR antes de prosseguir.

## Consequências esperadas (a confirmar no spike)

- Requer Xcode no Mac do desenvolvedor; `.app` deve abrir pelo Finder sem dependência de terminal.
- `MenuBarExtra` e `Foundation.Process` são APIs públicas da Apple; confirmar comportamento no macOS alvo.
- Chamadas a `launchctl` via `Foundation.Process` com argumentos separados (sem construir strings para `sh -c`).
- Compatibilidade de permissões, sandbox e assinatura local a validar no spike F1.

## Candidatos a piloto (não aprovados ainda)

- **mflux-studio:** candidato; supervisores a confirmar em F0.
- **ComfyUI:** candidato; mecanismo de execução não confirmado; pode não usar LaunchAgent → risco de reprovação em F0.

Ambos permanecem candidatos até o gate G0. Integração real só ocorre em F4, após G1.

## Pontos em aberto (validar em F1/F2)

- [ ] Versão mínima de macOS (alvo inicial: macOS 14 Sonoma — não testado)
- [ ] Assinatura local e abertura pelo Finder sem desativar Gatekeeper ou SIP
- [ ] Permissões necessárias para observar e controlar LaunchAgents do usuário
- [ ] Comportamento de `launchctl` nas versões do macOS alvo (confirmar com `man launchctl` local)
- [ ] Se ComfyUI não usar LaunchAgent: avaliar adaptador alternativo ou ajustar escopo de V1
