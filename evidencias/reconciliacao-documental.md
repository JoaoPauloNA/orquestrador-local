# Evidência — Reconciliação documental

Data: 2026-09-06  
Executor: orquestrador principal (conta principal de Claude)  
Escopo: correções nos arquivos de contexto do projeto (não é execução de F0 nem teste de produto)

## Verificações realizadas

### 1. Status de F0

- **Problema encontrado:** `INDEX.md` declarava "F0 concluída (gate G0 parcial)" — incoerente: F0 não pode estar concluída se G0 está parcial.
- **Correção:** substituído por "F0 PARCIAL; G0 ABERTO" em `INDEX.md` e confirmado em `ESTADO_ATUAL.md`.
- **Classificação:** IMPLEMENTADO

### 2. Referência a "repositório"

- **Problema encontrado:** `INDEX.md` usava "repositório" para um diretório sem Git inicializado.
- **Correção:** alterado para "checkout"; adicionada nota explícita de que Git não foi inicializado.
- **Classificação:** IMPLEMENTADO

### 3. Conflito de permissões de escrita

- **Problema encontrado:** `CLAUDE_ORQUESTRADOR.md` permitia escrita somente em `contexto/` e `evidencias/`, mas `ESTADO_ATUAL.md` (arquivo raiz) deveria ser atualizado por executores.
- **Correção:** `CLAUDE_ORQUESTRADOR.md` agora define escopos distintos por tipo de tarefa; a tabela em `ESTADO_ATUAL.md` registra quais arquivos cada tarefa pode editar.
- **Classificação:** IMPLEMENTADO

### 4. Evidências históricas na ficha mflux-studio

- **Problema encontrado:** exit 126 foi atribuído a "permissão/exec negado" como diagnóstico, mas o código isolado não diagnostica a causa. Além disso, as observações de 2026-09-04 e 2026-09-06 foram apresentadas no mesmo campo sem distinção de data.
- **Correção:** separadas em tabela com coluna de data; diagnóstico removido; adicionada nota de que a causa requer leitura do plist e dos logs.
- **Problema encontrado:** "desativar ou remover a concorrente" estava listado como pendência de F0 — é ação de migração pertencente a G1.
- **Correção:** movido explicitamente para "janela G1" com nota de autorização necessária.
- **Problema encontrado:** comando `launchctl bootstrap` listado como procedimento de recuperação — é proposta não testada.
- **Correção:** qualificado como proposta a confirmar com `man launchctl` e testar em fixture sintético.
- **Classificação:** IMPLEMENTADO

### 5. Arquitetura e alternativas

- **Problema encontrado:** ADR-001 descrevia "mflux-studio confirmado" e classificava Raycast com afirmação categórica sem evidência de teste.
- **Correção:** alterado para "candidato a piloto; a confirmar em F0"; razão de descarte do Raycast qualificada como hipótese.
- **Classificação:** IMPLEMENTADO

### 6. Ordenação de gates

- **Problema encontrado:** `ROADMAP.md` tinha diagrama com G1 e G2 posicionados como ramificações paralelas, sem G3, sem separação entre T01–T21 (G2) e T22–T23 (F6/G3).
- **Correção:** diagrama reescrito como sequência linear F0→G0→F1→F2→F3→G1→F4→F5→G2→F6→G3; tabela de gates atualizada com critérios distintos; nota registrando que a mesma ambiguidade existe no Vault e deve ser reconciliada futuramente.
- **Classificação:** IMPLEMENTADO

### 7. Verificação de links e existência de arquivos

| Link/referência | Existe? | Observação |
|---|---|---|
| `contexto/ficha-mflux-studio.md` | ✅ | Atualizado |
| `contexto/ficha-comfyui.md` | ✅ | Atualizado |
| `contexto/ADR-001-tecnologia.md` | ✅ | Atualizado |
| `contexto/PROMPT-F0-CODEX2.md` | ✅ | Criado nesta tarefa |
| `evidencias/` | ✅ | Diretório existe |
| `Sources/OrquestradorLocal/` | ✅ | Diretório existe; sem código Swift ainda |
| Vault `Orquestrador-Local-Plano.md` | ✅ | Lido como referência (não editado) |
| Vault `Handoff-Execucao.md` | ✅ | Lido como referência (não editado) |
| Vault `Aceite-V1.md` | ✅ | Lido como referência (não editado) |

### 8. Prompt de inspeção F0

- **Criado:** `contexto/PROMPT-F0-CODEX2.md` com tarefa completa em inglês
- **Inclui:** escopo de leitura por candidato, campos a coletar, formato de relatório em 10 tópicos
- **Comando sugerido:** incluído com nota de que flags devem ser verificadas com `codex --help` antes de usar
- **Status:** PRONTO — NÃO DESPACHADO

## Arquivos alterados nesta tarefa

1. `INDEX.md` — status, referência a "repositório", próximo passo
2. `ESTADO_ATUAL.md` — tabela de escopos, "stack confirmada" → proposta, G0 explicitado
3. `ROADMAP.md` — gates reordenados, G3 adicionado, split G2/F6 documentado
4. `CLAUDE_ORQUESTRADOR.md` — escopos por tarefa, subdelegação proibida, leitura estreita
5. `contexto/ficha-mflux-studio.md` — datas separadas, diagnóstico qualificado, migração → G1
6. `contexto/ficha-comfyui.md` — SIGTERM qualificado, porta como hipótese, risco de gate explicitado
7. `contexto/ADR-001-tecnologia.md` — candidatos qualificados, alternativas com ressalvas

## Arquivos criados nesta tarefa

8. `contexto/PROMPT-F0-CODEX2.md`
9. `evidencias/reconciliacao-documental.md` (este arquivo)

## O que não foi alterado

- Vault (somente leitura)
- `Sources/OrquestradorLocal/` (sem código)
- `evidencias/.gitkeep`
- Nenhum serviço iniciado ou parado
- Git não inicializado

## Pendências após esta tarefa

- [ ] Verificar flags reais do `codex --help` antes de despachar `PROMPT-F0-CODEX2.md`
- [ ] A mesma ambiguidade de gates G2/G3 existe no Vault e precisa de reconciliação futura autorizada
- [ ] Inspeção F0 presencial (codex2) ainda não executada — G0 permanece ABERTO

## Classificação final

**IMPLEMENTADO** — reconciliação documental concluída. F0 não executada; V1 não funcional.
