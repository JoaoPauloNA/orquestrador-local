# Ficha F0 — mflux-studio (candidato a piloto)

Data: 2026-09-06 | Status: PRELIMINAR — inspeção de campo não executada

> Atualização F0 presente (2026-09-06, somente leitura): ambos os plists existem e ambas as labels aparecem em `launchctl list`; `local.mflux-studio` manteve saída 126 e `com.joaopaulo.mflux-studio` teve PID observado. Ambos têm `KeepAlive` e `RunAtLoad`; a duplicidade está confirmada. O primeiro declara `/bin/bash`; o segundo, o Python da venv. A leitura limitada de `server.py` não identificou rota HTTP de prontidão ou fila. Logo, identidade de prontidão e atividade são **DESCONHECIDAS**; isso não autoriza parada. Evidência: `evidencias/f0-atual-2026-09-06.md`.

> Esta ficha é baseada em dados históricos do Vault. Nenhuma leitura presencial de plists, LaunchAgents ou processos foi realizada nesta sessão. Todas as observações abaixo devem ser confirmadas ou refutadas pela inspeção F0.

## Identidade (histórico — verificar em F0)

| Campo | Valor | Fonte | Status |
|---|---|---|---|
| Nome | mflux-studio | Vault | Histórico |
| Diretório | `/Users/joaopaulo/Documents/Projetos/Carreira/mflux-studio/` | Vault 2026-09-06 | A confirmar |
| Executável principal | `server.py` iniciado via Python/uvicorn | Vault (leitura de código) | A confirmar |
| Servidor HTTP | `http://127.0.0.1:8765` | Vault | A confirmar |
| Resposta HTTP | 200 registrada em 2026-09-04 | Nota de 2026-09-04 | Snapshot histórico; verificar estado atual |
| Propósito | Gerador local de imagens; motor de artefatos gráficos | Vault | — |

## Supervisores / LaunchAgents (snapshot histórico — dois momentos distintos)

> **Importante:** as duas observações abaixo pertencem a momentos diferentes e não devem ser tratadas como estado simultâneo atual.

| Data snapshot | Label | Plist | Observação registrada |
|---|---|---|---|
| 2026-09-04 | `com.joaopaulo.mflux-studio` | `~/Library/LaunchAgents/com.joaopaulo.mflux-studio.plist` | Processo ativo registrado |
| 2026-09-06 | `local.mflux-studio` | `~/Library/LaunchAgents/local.mflux-studio.plist` | Saída 126 registrada; causa não diagnosticada a partir deste código isolado |

**Situação atual:** possível duplicidade de supervisores; verificação presente pendente. Exit 126 indica falha de exec (permissão ou executável não encontrado), mas o diagnóstico exato requer leitura do plist e dos logs de launchd.

**Pendências de inspeção F0 (somente leitura):**
- [ ] Ler conteúdo de ambos os plists (`Program`, `ProgramArguments`, `KeepAlive`, `RunAtLoad`)
- [ ] Executar `launchctl list | grep mflux` — registrar saída atual
- [ ] Verificar se ambas as labels estão carregadas no domínio do usuário
- [ ] Identificar qual label inicia `server.py` com o diretório correto
- [ ] Verificar se há `KeepAlive` que ressuscite o processo após parada
- [ ] Registrar localização dos logs stdout/stderr referenciados nos plists

**Ação de migração (fora do escopo F0):** decidir qual label é canônica e como tratar a outra é uma decisão de migração que pertence à janela G1, com autorização explícita de João e backup dos plists antes de qualquer alteração.

## Prontidão (proposta — confirmar em F0)

- Endpoint proposto: `http://127.0.0.1:8765`
- Resposta de identidade esperada: a definir após inspeção — HTTP 200 genérico não é suficiente
- Confirmar: existe endpoint com resposta exclusiva do mflux-studio (ex.: header, body ou path específico)?
- Prazo proposto: 60–90 s (calibrar após spike F2)

## Atividade / trabalho em andamento (não verificado)

- API de fila/job: NÃO VERIFICADO — verificar se `server.py` expõe endpoint de jobs ou geração ativa
- Suíte `chart_engine` falhou na coleta em 2026-09-04 (`ModuleNotFoundError: rpds.rpds`); estado atual desconhecido
- Sem sinal de atividade confirmado → se não houver endpoint, o piloto exige confirmação explícita de ociosidade antes de qualquer parada

## Parada (proposta — verificar semântica em F0)

- Mecanismo proposto: retirar label canônica do domínio do usuário via `launchctl bootout user/$(id -u) <label>`
- Este comando é uma proposta a verificar com `man launchctl` no Mac alvo; semântica exata (ex.: diferença entre `bootout` e `remove`) requer confirmação
- Prazo proposto: 30 s (verificar com comportamento real do launchd no Mac alvo)
- Verificação de término: ausência da label em `launchctl list` + processo não mais presente
- Processo filho (Python/uvicorn): verificar se launchd encerra descendentes ou se o plist define `SessionCreate`

## Dependências (histórico)

- `.venv` local do projeto (Python)
- `mflux` 0.18.1 via `uv tool` (estado atual não reconfirmado)
- Docker: política de uso do usuário (fechar antes de geração pesada); não é dependência do mecanismo de controle
- Sem dependência de rede externa confirmada para operação básica

## Logs

- Origem provável: stdout/stderr referenciados no(s) plist(s) — localização a confirmar em F0
- Campos a suprimir no painel: argumentos de modelo, caminhos de artefatos privados, tokens

## Recuperação (proposta — não testada)

- Fazer backup dos plists antes de qualquer alteração (parte da janela G1)
- Restauração proposta: copiar plist de volta e recarregar com `launchctl bootstrap user/$(id -u) <plist>`
- Estes comandos são propostas; confirmar com `man launchctl` e testar em fixture sintético antes de usar em piloto real

## Aprovação

- [ ] Inspeção F0 executada e relatório recebido
- [ ] Ficha atualizada com evidências de campo
- [ ] Aprovação explícita de João para controlar este piloto (gate G1)
- Fingerprint dos arquivos aprovados: a registrar em G1
