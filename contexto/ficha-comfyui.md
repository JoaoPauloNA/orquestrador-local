# Ficha F0 — ComfyUI (candidato a piloto)

Data: 2026-09-06 | Status: PRELIMINAR — inspeção de campo não executada

> Atualização F0 presente (2026-09-06, somente leitura): instalação encontrada em `~/ComfyUI`; `local.comfyui` está carregado, com Python da venv e `KeepAlive`/`RunAtLoad`. `system_stats` e `/queue` responderam 200 no loopback; no instante da leitura a fila tinha 0 em execução e 0 pendentes. Os endpoints observados não constituem ainda contrato de identidade suficiente para controle. Não houve alteração, parada ou reinício. Evidência: `evidencias/f0-atual-2026-09-06.md`.

> Esta ficha é baseada em dados mínimos do Vault. Nenhuma leitura presencial de processos, plists ou endpoints foi realizada. Todas as afirmações abaixo são hipóteses a confirmar ou refutar pela inspeção F0.

## Identidade (hipóteses — verificar em F0)

| Campo | Valor | Fonte | Status |
|---|---|---|---|
| Nome | ComfyUI | Vault | — |
| Diretório | NÃO CONFIRMADO | — | ❌ |
| Executável | NÃO CONFIRMADO | — | ❌ |
| Servidor HTTP | NÃO CONFIRMADO (padrão da aplicação é 8188; não verificado neste Mac) | Hipótese | ❌ |
| Versão | 0.34.0 | Vault (auditoria 2026-09-06) | Snapshot histórico |
| Propósito | Geração de imagens local via workflows | Vault | — |

## Supervisores / LaunchAgents (não verificado)

| Campo | Status |
|---|---|
| LaunchAgent presente? | NÃO VERIFICADO |
| Label | NÃO VERIFICADO |
| Plist | NÃO VERIFICADO |
| Processo direto (sem LaunchAgent)? | NÃO VERIFICADO |

**Pendências de inspeção F0 (somente leitura):**
- [ ] Localizar diretório de instalação do ComfyUI
- [ ] Verificar `~/Library/LaunchAgents/` para qualquer plist relacionado ao ComfyUI
- [ ] Executar `launchctl list | grep -i comfy` — registrar saída atual
- [ ] Se não houver LaunchAgent: documentar como o processo é iniciado (script manual, launchd, outro)
- [ ] Confirmar porta em uso (não assumir 8188 sem verificar)
- [ ] Verificar endpoint de prontidão e body de resposta com identidade da versão
- [ ] Verificar endpoint de fila (`/queue` ou equivalente)

**Risco crítico de gate:** se ComfyUI não usar LaunchAgent do usuário, o adaptador planejado para a V1 não se aplica. Nesse caso, o candidato não passa no gate F0 para este mecanismo de controle — registrar como bloqueio e propor alternativa ou reformular o escopo, sem expandir o adaptador automaticamente.

## Prontidão (hipóteses — confirmar em F0)

- Endpoint proposto: a confirmar (porta não verificada)
- Resposta de identidade: JSON com campos de versão/sistema — confirmar que identifica inequivocamente o ComfyUI e a versão 0.34.0
- Prazo proposto: 60–120 s (carga de modelos pode ser lenta; calibrar em F2)

## Atividade / fila (hipótese — confirmar em F0)

- ComfyUI tipicamente expõe `/queue` com campos `queue_running` e `queue_pending` — verificar se esta versão (0.34.0) expõe esse endpoint e qual é o formato exato
- Parada segura proposta: fila vazia em ambos os campos
- Se endpoint não existir ou retornar formato inesperado: atividade marcada como "desconhecida" — piloto exigirá confirmação explícita de ociosidade

## Parada (proposta — verificar em F0)

- Mecanismo preferido: via LaunchAgent (se existir) — retirar do domínio do usuário como no mflux-studio
- Se não houver LaunchAgent: mecanismo alternativo a propor após inspeção; não assumir que SIGTERM direto no PID é seguro sem verificar propriedade e descendentes
- Confirmar: encerramento gracioso preserva dados/modelos? Há workers ou processos filhos não gerenciados pelo pai?

## Dependências (não verificadas)

- Python (versão não confirmada)
- Modelos: localizados em diretório próprio — não remover no encerramento
- Ollama: coexiste no Mac; verificar se ComfyUI o usa como dependência em algum fluxo
- Outros serviços compartilhados: a mapear em F0

## Riscos específicos

1. **Sem LaunchAgent:** reprovar gate F0 para este candidato → reformular escopo sem expandir adaptador automaticamente.
2. **Tempo de carga de modelos:** prontidão lenta; timeout deve ser configurável por perfil.
3. **Memória compartilhada:** ComfyUI e mflux-studio competem pela memória unificada de 16 GiB; comportamento ao parar um com o outro ativo não foi estudado.
4. **Endpoint de fila não verificado:** se `/queue` não retornar formato esperado, atividade fica como "desconhecida".

## Aprovação

- [ ] Inspeção F0 executada e relatório recebido
- [ ] Ficha atualizada com evidências de campo
- [ ] Candidato aprovado ou reprovado para gate F0
- [ ] Aprovação explícita de João para controlar este piloto (gate G1, se aprovado em F0)
