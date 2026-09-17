# Evidência — Correções finais e delegação de design

Data: 2026-09-06  
Executor: orquestrador principal (Sonnet 4.6)  
Escopo: Parte A (correções CLAUDE_ORQUESTRADOR.md + PROMPT-F0-CODEX2.md) + Parte B (delegação ao Agy) + Parte C (revisão dos deliverables)

---

## Parte A — Correções finais de documentação

### A-1: CLAUDE_ORQUESTRADOR.md
- Tarefa histórica "Correções finais e delegação de design" adicionada como EM EXECUÇÃO
- Escopo de escrita por tipo de tarefa em tabela (orquestrador / codex2 / pós-inspeção / design / implementação)
- Seção da inspeção F0 (codex2) expandida com campos de leitura proibida e escrita = nenhuma
- Regras gerais: regra 2 agora inclui exceção explícita para executor de inspeção F0
- Subdelegação: regra 6 adicionada (exige instrução explícita por tarefa)
- Permissões F1–F6: seção adicionada marcando-as como condicionais e futuras
- Classificação: IMPLEMENTADO

### A-2: PROMPT-F0-CODEX2.md
- `ps aux` substituído por `ps -eo pid,ppid,%cpu,rss,comm` (bounded, sem args completos)
- Leitura de ROADMAP.md adicionada à seção "Context to read"
- `http://127.0.0.1:8188/queue` adicionado com campos delimitados (counts apenas)
- `/Users/joaopaulo/ComfyUI` adicionado como localização candidata do ComfyUI
- Proibição de delegação a outros agentes adicionada explicitamente
- Nota de "permission failure = UNKNOWN" adicionada e consistente com ownership/readiness/activity
- Classificação: IMPLEMENTADO

---

## Parte B — Delegação de design ao Agy

### Dispatcher
- Executor: Agy (`/opt/homebrew/bin/agy`), model `gemini-3.8-flash-medium`
- Flags verificadas: `--print`, `--model`, `--add-dir`, `--print-timeout`
- Lançado como processo de background (PID 7750)
- Diretórios adicionados: `OrquestradorLocal/` + `CasaCapital/Aplicacao/` (somente leitura)
- Assignment: `contexto/ASSIGNMENT-AGY-DESIGN.md`

### Deliverables entregues por Agy (21 arquivos, todos em design/)
| Arquivo | Status |
|---|---|
| design/README.md | ✅ entregue |
| design/REFERENCIA-CASACAPITAL.md | ✅ entregue |
| design/DESIGN-SYSTEM.md | ✅ entregue |
| design/TELAS-E-FLUXOS.md | ✅ entregue |
| design/SWIFTUI-HANDOFF.md | ✅ entregue |
| design/RELATORIO-AGY.md | ✅ entregue |
| design/icons/app-icon.svg | ✅ entregue |
| design/icons/app-icon-preview.png | ✅ entregue |
| design/icons/menubar-mark.svg | ✅ entregue |
| design/icons/action-icons.svg | ✅ entregue |
| design/icons/icon-notes.md | ✅ entregue |
| design/mockups/01-catalogo-principal.svg | ✅ entregue |
| design/mockups/02-menu-bar-panel.svg | ✅ entregue |
| design/mockups/03-detalhes-projeto.svg | ✅ entregue |
| design/mockups/04-cadastro-guiado.svg | ✅ entregue |
| design/mockups/05-catalogo-vazio.svg | ✅ entregue |
| design/mockups/06-estados-servico.svg | ✅ entregue |
| design/mockups/07-parada-bloqueada.svg | ✅ entregue |
| design/mockups/08-atividade-desconhecida.svg | ✅ entregue |
| design/mockups/09-conflito-porta.svg | ✅ entregue |
| design/mockups/10-detalhe-erro.svg | ✅ entregue |

---

## Parte C — Revisão e validação

### Verificações realizadas pelo orquestrador

| Verificação | Método | Resultado |
|---|---|---|
| Marca d'água em todos os mockups | `grep -c "CONCEITO / DADOS SINTÉTICOS"` | 10/10 presentes |
| Font-family nativo macOS | Inspeção cabeçalho SVG | `-apple-system, BlinkMacSystemFont, 'SF Pro Text'` confirmado |
| App icon sem metáfora imobiliária | Inspeção SVG | Gradiente navy abstrato; sem casa, colunas, esfera |
| Escopo de escrita | `find -newer ASSIGNMENT-AGY-DESIGN.md -not -path */design/*` | Apenas diretório `contexto/` (mtime do dir alterado pela criação de ASSIGNMENT, não por Agy) |
| Nenhum arquivo novo em contexto/ | `ls -lt contexto/` | 5 arquivos, mais recente = ASSIGNMENT (criado pelo orquestrador, não Agy) |
| XML/SVG válido | Relatório Agy (xml.etree.ElementTree) | 13/13 aprovados |
| WCAG contraste | Relatório Agy (cálculo analítico) | Navy/Background 15.8:1 AAA; Muted/Background 4.8:1 AA |

### Não conformidades encontradas
Nenhuma. Contrato respeitado integralmente.

### Limitações declaradas (herdadas do Agy — aceitáveis)
- VoiceOver em runtime SwiftUI: não testado (app Swift ainda não existe — fases F1–F3)
- Testes em dispositivo físico: não executados (pré-implementação)

---

## Status final desta fatia

**IMPLEMENTADO** — Parte A (correções), Parte B (design delegado e entregue), Parte C (revisão concluída sem não-conformidades).

## O que não foi alterado nesta tarefa
- Vault (não editado)
- Sources/ (sem código)
- CasaCapital/ (somente leitura)
- LaunchAgents (não tocados)
- Git não inicializado
- codex2 não despachado (G0 permanece ABERTO)
