# CLAUDE_ORQUESTRADOR — instruções para executores

Atualizado: 2026-09-06 | Fase: F0→F6 TRABALHO INDEPENDENTE AUTORIZADO (codex2)

---

## Autorização vigente (2026-09-06) — retomada de implementação codex2

A instrução direta do operador para esta retomada substitui as restrições históricas de executor,
documentação somente, despacho por fase e descoberta codex2 somente leitura.

- **Executor:** codex2 (implementador, não revisor); não chamar Claude, outro LLM ou subagente.
- **Base:** preservar e completar a implementação parcial deixada pela execução interrompida por limite mensal.
- **Escopo de escrita:** `Sources/`, `Tests/`, configuração do pacote/projeto, `Resources/`, fixtures e scripts próprios, `dist/`, `design/`, `contexto/`, `evidencias/` e os documentos operacionais da raiz.
- **Objetivo:** concluir todo trabalho independentemente acionável, incluindo F0 somente leitura, fundação, controle, interface, testes sintéticos e pacote local.
- **Pilotos reais:** inventário somente leitura permitido; iniciar/parar/reiniciar, migrar ou editar LaunchAgents existentes continua condicionado à janela humana G1.
- **Gates:** esta autorização não fecha G0/G1/G2/G3. T23, três sessões reais e aceite explícito continuam humanos; skips obrigatórios não contam como aprovação.
- **Proibições mantidas:** editar runner/controle/assignments/relatórios de execução, Git init/commit/tag/push/release, editar Vault/CasaCapital/Athena, sudo, dados/credenciais, instalações globais, listeners externos, force-kill ou kill por nome/porta.
- **Relatório final:** stdout do executor, salvo externamente em `execucoes/2026-09-06-codex2-terra/RELATORIO-IMPLEMENTACAO.md`.

Plano desta retomada: (1) reconciliar autorização; (2) executar F0 presente sem mutações;
(3) auditar e corrigir o código parcial; (4) validar com fixtures isoladas, testes e inspeção
visual clara/escura/janela pequena; (5) empacotar `.app`; (6) registrar matriz T01–T23,
gates e limitações reais. O revisor independente será iniciado depois pelo runner, não por este executor.

## Autorização anterior — encerrada por limite mensal

A autorização Sonnet 4.6 e a revisão Haiku planejada terminaram sem relatório técnico válido,
conforme `evidencias/interrupcao-claude-2026-09-06.md`. Elas são histórico e não restringem
a retomada vigente acima.

---

## Histórico de tarefas executadas

### Reconciliação documental (2026-09-06) — CONCLUÍDA
Executor: orquestrador principal.  
Arquivos editados: quatro raiz + três `contexto/` + dois novos (`PROMPT-F0-CODEX2.md`, `evidencias/reconciliacao-documental.md`).  
Evidência: `evidencias/reconciliacao-documental.md`.

### Correções finais e delegação de design (2026-09-06) — CONCLUÍDA
Executor: orquestrador principal (Sonnet 4.6).  
Escopo autorizado:
- Editar quatro arquivos raiz e todos os arquivos `contexto/` e `evidencias/`
- Corrigir `PROMPT-F0-CODEX2.md` conforme spec
- Criar `design/` e delegar ao Agy (delegação explicitamente autorizada somente para esta fatia de design)
- Criar `evidencias/correcoes-finais-e-design.md` ✅ criado

**Proibido nesta tarefa:** editar Vault, CasaCapital, `Sources/`, iniciar Git, executar serviços, despachar codex2, delegar a agentes além do Agy para design.

---

## Escopos de escrita por tipo de tarefa

| Tipo de tarefa | Arquivos que pode editar | Regra especial |
|---|---|---|
| Orquestrador / reconciliação | Todos os quatro raiz + `contexto/` + `evidencias/` | — |
| Inspeção F0 (codex2) | **Nenhum** — apenas retornar relatório | Ver seção abaixo |
| Pós-inspeção (operador) | `contexto/ficha-*.md`, `ESTADO_ATUAL.md` | Após receber relatório do codex2 |
| Design (Agy) | Somente `design/` dentro deste checkout | Não editar contexto nem Sources |
| Implementação Fx (executor futuro) | `Sources/` e atualizar `ESTADO_ATUAL.md` ao encerrar | Condicional: somente após gate autorizado |

---

## Escopo da inspeção F0 (codex2 — PREPARADA, NÃO DESPACHADA)

O executor codex2, quando receber `contexto/PROMPT-F0-CODEX2.md`, opera com escopo estritamente restrito:

**Leitura permitida:** arquivos de contexto listados no prompt; plists em `~/Library/LaunchAgents/` (apenas campos explicitados, nunca variáveis de ambiente ou argumentos sensíveis); output de `launchctl list` para labels conhecidas; `man launchctl`; requisições GET somente leitura a endpoints de prontidão e atividade em loopback identificados.

**Leitura proibida:** credenciais, conteúdo de `.env`, stores de autenticação, logs completos, argumentos de processo contendo segredos, conteúdo de documentos privados, variáveis de ambiente dos processos.

**Escrita:** nenhuma. O agente de inspeção não edita arquivos do projeto, do Vault nem de nenhum outro diretório.

**Ações proibidas:** reparar ambiente, parar/iniciar serviços, instalar dependências, fazer commits, subdelegar a outros agentes.

**Recebimento do relatório:** o operador (João) ou o orquestrador revisa e registra as conclusões nos arquivos autorizados. Receber o relatório não fecha automaticamente G0 — o operador valida antes de fechar o gate.

---

## Regras gerais de operação (qualquer executor)

1. **Ler antes de agir.** Ler `INDEX.md` e `ESTADO_ATUAL.md` antes de qualquer ação.
2. **Atualizar após agir.** Registrar data, arquivos alterados, resultado e classificação antes de encerrar. **Exceção:** o executor de inspeção F0 (codex2) não atualiza nenhum arquivo — apenas retorna o relatório.
3. **Relatar em 10 tópicos.** Formato: O que foi feito / Arquivos alterados / Arquivos analisados / O que não foi alterado / Testes executados / Resultado dos testes / Pendências / Riscos / Status final / Próximo passo.
4. **WIP=1.** Um executor por fatia. Não editar os mesmos arquivos em paralelo.
5. **Sem ações não autorizadas.** Não iniciar/parar serviços reais, não editar LaunchAgents, não fazer commits sem pedido explícito.
6. **Sem subdelegação não autorizada.** Subdelegação exige instrução explícita do operador por tarefa. Registrar intenção não é autorização.

---

## Permissões históricas de implementação por fase (superadas nesta retomada)

Estas condições descrevem o fluxo anterior e não se aplicam à autorização codex2 vigente. No fluxo anterior, cada fase requeria:
- Gate anterior fechado com evidência verificável
- Instrução explícita do operador nomeando a fase e os arquivos autorizados
- Leitura deste arquivo e de `ESTADO_ATUAL.md` antes de agir

---

## Formato de evidência (`evidencias/`)

```
Data: AAAA-MM-DD
Comando/fonte: <exato>
Esperado: <o que devia acontecer>
Observado: <o que aconteceu>
Classificação: IMPLEMENTADO | PARCIAL | BLOQUEADO | NÃO VERIFICADO
Artefato: <nome do arquivo em evidencias/ se houver>
```

## Escalonamento

Se bloqueado após 3 tentativas: reportar a João com causa, tentativas e próximo passo sugerido. Não contornar bloqueio de permissão ampliando escopo.
