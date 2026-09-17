# Orquestrador Local — Índice operacional

**Fonte de verdade técnica:** este checkout e sua pasta `contexto/`.  
**Fonte de visão e plano:** Vault → `Projetos/Pessoal/Orquestrador-Local/`  
**Dono:** João · **Início:** 2026-09-06 · **Alvo:** macOS M5, Swift/SwiftUI (proposta; spike F1/F2)

> Este diretório não é um repositório Git. Não chamar de "repositório" até que Git seja inicializado explicitamente.

## Arquivos deste checkout

| Arquivo | Pergunta que responde |
|---|---|
| `ESTADO_ATUAL.md` | O que está feito, em andamento ou bloqueado agora? |
| `ROADMAP.md` | Qual sequência de fases e gates? |
| `CLAUDE_ORQUESTRADOR.md` | Como um executor deve operar neste projeto? |
| `contexto/ficha-mflux-studio.md` | Ficha preliminar do candidato a piloto mflux-studio |
| `contexto/ficha-comfyui.md` | Ficha preliminar do candidato a piloto ComfyUI |
| `contexto/ADR-001-tecnologia.md` | Por que Swift/SwiftUI + LaunchAgents? (proposta) |
| `contexto/PROMPT-F0-CODEX2.md` | Prompt pronto para inspeção F0 via codex2 |
| `evidencias/` | Saídas de testes, medições e registros de aceite |

## Fase atual

**F0 PARCIAL; G0 ABERTO.** A observação F0 atual e a implementação sintética estão registradas em `evidencias/`.  
mflux-studio mantém dois supervisores observados; ComfyUI tem LaunchAgent e endpoints loopback observados.  
**Próximo passo:** João revisa os contratos e libera G1 somente para mutações controladas de pilotos.

## Regra de atualização

Registrar data, ação, resultado e classificação (`IMPLEMENTADO`, `PARCIAL`, `BLOQUEADO`, `NÃO VERIFICADO`). Não declarar fase concluída sem evidência verificável. Documentação não prova implementação.
