# Estado atual — Orquestrador Local

> Histórico e estado vigente — 2026-09-06: a execução Sonnet 4.6 → Haiku 4.5 foi interrompida por limite mensal, preservando código parcial. A retomada codex2 Terra concluiu trabalho independente adicional e registrou evidências em `evidencias/implementacao-terra-2026-09-06.md` e `evidencias/matriz-aceite-2026-09-06.md`. Estado vigente: **PARCIAL, sem aceite V1**; a revisão independente e gates humanos continuam pendentes.

Atualizado: 2026-09-15 (catálogo declarativo e controles preparados; pilotos reais continuam bloqueados por G1)

## Integração do projeto Grafico (2026-09-15)

- [x] Projeto `/Users/joaopaulo/Documents/Projetos/Pessoal/Projetos-SM/Grafico` cadastrado como perfil separado `SM_graficos (Grafico)`.
- [x] LaunchAgent dedicado `com.joaopaulo.sm-graficos.plist` criado em `~/Library/LaunchAgents`, com `RunAtLoad=false` e `KeepAlive=false`; não foi carregado nem iniciado automaticamente.
- [x] Endpoint de prontidão loopback definido em `http://127.0.0.1:3011/`, validando o marcador `<div id=`; abertura usa a mesma URL.
- [x] Build de produção do Grafico concluído e servido temporariamente para smoke test HTTP 200; o processo foi encerrado após a verificação.
- [x] Catálogo empacotado novamente no `.app`; o perfil será carregado ao reabrir o Orquestrador Local.
- [x] Backup pré-alteração em `/Users/joaopaulo/Documents/Backups/sm-orquestrador-grafico-20260915-051505` com `SHA256SUMS`.

## Implementação independente de 2026-09-15

- [x] Catálogo declarativo `Sources/OrquestradorLocal/Resources/services.yaml` para Segunda Mente, ComfyUI e mflux-studio.
- [x] Leitura e validação dos três LaunchAgents existentes, sem criar, substituir, descarregar ou desabilitar plists.
- [x] Registro automático no catálogo do aplicativo apenas quando o plist já existe e passa pela validação de propriedade, fingerprint e URLs loopback.
- [x] Ação `Reiniciar` adicionada ao fluxo normal de parada graciosa e início, preservando as barreiras de atividade.
- [x] Detalhe da interface passou a exibir endpoint/porta, caminho do LaunchAgent e diretório de trabalho.
- [x] Testes sintéticos e validação de contratos executados; nenhum piloto real foi iniciado, parado, reiniciado ou migrado.

## Integração adicionada — LocalTranscriber (2026-09-08)

- [x] Serviço `LocalTranscriber` aparece automaticamente no catálogo do app.
- [x] Registro dedicado: `com.joaopaulo.localtranscriber`, porta loopback `8766`.
- [x] Controles existentes de iniciar, verificar e abrir utilizam o contrato normal do Orquestrador.
- [x] `RunAtLoad=false`: a integração não inicia o transcritor automaticamente.
- [x] `.app` local recompilado, assinado ad-hoc e verificado.
- [x] Smoke operacional do LaunchAgent executado: iniciou, respondeu em `/api/health` e foi devolvido ao estado parado.
- [ ] Clique manual nos botões `Iniciar`/`Parar` pela janela continua pendente; o contrato de controle foi validado diretamente com o mesmo LaunchAgent.

## Situação geral

| Fase | Status | Observação |
|---|---|---|
| F0 — Descoberta | PARCIAL | Observação atual registrada; G0 aberto por duplicidade mflux |
| F1 — Fundação | PARCIAL | Pacote Swift, catálogo e fixture implementados/testados |
| F2 — Controle | PARCIAL | Ciclo LaunchAgent sintético passou; cobertura obrigatória incompleta |
| F3 — Interface | PARCIAL | UI, temas e capturas nativas; aceite a11y humano pendente |
| F4 — Pilotos reais | NÃO EXECUTADO | G1 não autorizado |
| F5 — Robustez | PARCIAL | Validações unitárias; matriz obrigatória incompleta |
| F6 — Entrega | PARCIAL | `.app` local assinado ad-hoc; T22/T23 pendentes |

**G0/G1/G2/G3:** ABERTOS. Nenhum gate fechado.

## O que existe neste checkout

- [x] Estrutura de diretórios criada (`contexto/`, `evidencias/`)
- [x] Arquivos de contexto: INDEX, ESTADO_ATUAL, ROADMAP, CLAUDE_ORQUESTRADOR
- [x] Ficha preliminar de mflux-studio (dados históricos do Vault; inspeção de campo pendente)
- [x] Ficha preliminar de ComfyUI (dados mínimos; inspeção pendente)
- [x] ADR-001 (proposta de tecnologia; spike de validação pendente)
- [x] PROMPT-F0-CODEX2.md (prompt pronto, não despachado)
- [x] Pacote de design visual (design/) — entrega preservada; alegação anterior de revisão sem não-conformidades foi reconciliada com evidência técnica posterior
- [x] Código Swift — implementação parcial compilada/testada
- [x] Serviço sintético — ciclo real isolado executado e limpo
- [ ] Testes T01–T23 — matriz atualizada; T02, T05 e T08 receberam evidência independente adicional, mas gates seguem abertos
- [ ] Git inicializado — não feito

## Bloqueios ativos

### B-01: Possível duplicidade de supervisores no mflux-studio
Auditoria de 2026-09-06 registrou dois plists relacionados ao mflux-studio:
`local.mflux-studio.plist` e `com.joaopaulo.mflux-studio.plist`.
O estado atual de cada um não foi verificado nesta sessão.  
**Ação F0:** ler ambos os plists e executar `launchctl list` para confirmar estado presente.  
**Ação de migração (se necessária):** autorizada somente em janela G1 separada, com aprovação de João.

### B-02: Ficha ComfyUI incompleta
Nenhuma nota dedicada no Vault. Localização, supervisor, label, porta e sinal de atividade não confirmados.  
**Ação F0:** localizar diretório e verificar mecanismo de execução.  
**Risco:** se ComfyUI não usar LaunchAgent, o adaptador da V1 pode não se aplicar → reprovar gate F0 para este candidato.

### B-03: G0 aguarda conclusão de B-01 e B-02

## Decisões e propostas em aberto

| Decisão | Status |
|---|---|
| Checkout em `~/Documents/Projetos/Pessoal/OrquestradorLocal/` | Criado |
| Stack Swift/SwiftUI + LaunchAgents | Proposta para spike F1/F2; não confirmada |
| mflux-studio como candidato a piloto | Candidato; aguarda G0 |
| ComfyUI como candidato a piloto | Candidato; aguarda G0 |
| Git — inicializar | Não feito; exige instrução explícita |

## Escopos de escrita autorizados por tarefa

| Tarefa | Arquivos que pode editar |
|---|---|
| Reconciliação documental (esta) | Quatro arquivos raiz + três arquivos `contexto/` + dois arquivos novos |
| Inspeção F0 — codex2 | Nenhum; somente retornar relatório |
| Pós-inspeção — operador | `contexto/ficha-*.md`, `ESTADO_ATUAL.md`, com base no relatório recebido |
| F1 execução | Arquivos Swift em `Sources/`; atualizar `ESTADO_ATUAL.md` ao encerrar |

## Benchmark local no Grafico (2026-09-15)

- [x] Tela exclusiva `Benchmark de modelos locais` definida como tela inicial.
- [x] ScreenPipe removido da listagem genérica de Projetos; DevFlow e TTS permanecem nessa área.
- [x] Quatro modelos locais e o comparativo final usam os dados já presentes em `DadosTeste`.
- [x] Cards, métricas e gráficos de qualidade/latência/segurança validados no navegador local após rebuild e restart do serviço.
