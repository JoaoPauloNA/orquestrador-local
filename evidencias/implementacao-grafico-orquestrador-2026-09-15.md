# Evidência — integração do projeto Grafico ao Orquestrador Local

Data: 2026-09-15 (America/Cuiaba)

## Escopo

O projeto `/Users/joaopaulo/Documents/Projetos/Pessoal/Projetos-SM/Grafico` foi cadastrado como um serviço independente do painel Home, usando a porta loopback `3011`.

## Alterações

- Catálogo: `Sources/OrquestradorLocal/Resources/services.yaml`, seção `grafico`.
- LaunchAgent: `/Users/joaopaulo/Library/LaunchAgents/com.joaopaulo.sm-graficos.plist`.
- Teste do catálogo: `Tests/OrquestradorLocalTests/ManagedServiceCatalogTests.swift`.
- Artefato: `/Users/joaopaulo/Documents/Projetos/Pessoal/OrquestradorLocal/dist/Orquestrador Local.app`.

O plist executa `npm run preview -- --host 127.0.0.1 --port 3011`, aponta para o diretório do projeto e mantém `RunAtLoad=false`/`KeepAlive=false`. O serviço não foi carregado no launchd durante esta rodada; `launchctl print` confirmou que o label não está carregado.

## Verificações

- `npm run build`: passou; sincronizou 27 workflows e 227 execuções e gerou `dist/`.
- `npm run preview -- --host 127.0.0.1 --port 3011`: passou; `curl` retornou HTTP 200 e `<div id="root"></div>`.
- `plutil -lint /Users/joaopaulo/Library/LaunchAgents/com.joaopaulo.sm-graficos.plist`: passou.
- `swift test`: passou, 47 testes, 0 falhas.
- `./scripts/package-app.sh`: passou; assinatura ad-hoc validada.

## Preservação

Backup pré-alteração do Grafico: `/Users/joaopaulo/Documents/Backups/sm-orquestrador-grafico-20260915-051505`, com hashes em `SHA256SUMS`. Nenhum processo não relacionado foi encerrado e nenhum LaunchAgent preexistente foi alterado.

## Estado

`OK` para cadastro declarativo, contrato do LaunchAgent e smoke test do build. O controle visual pelos botões do app depende de reabrir o `.app` empacotado para carregar o catálogo atualizado; nenhum piloto real foi iniciado nesta rodada.

## Correção de prontidão (revalidação)

A primeira execução deixou o estado visual em `iniciando` apesar de o processo e a porta estarem saudáveis. A causa foi o marcador configurado com aspas escapadas (`<div id=\"root\">`), que o parser flat preservava literalmente. O catálogo foi corrigido para usar o marcador não ambíguo `<div id=`; o teste do catálogo agora verifica esse valor.

## Revalidação pelo app real

Após reiniciar o `.app` empacotado, a janela do Orquestrador exibiu `SM_graficos (Grafico), estado PRONTO`, com atividade não monitorada e cota N/D. O LaunchAgent permaneceu carregado e saudável, com PID gerenciado e a porta `127.0.0.1:3011` respondendo HTTP 200.

Também foi corrigida a atualização de perfis declarativos persistidos: ao iniciar, o Orquestrador agora compara e atualiza campos do catálogo (mantendo o mesmo ID) quando o `services.yaml` muda. Isso evita que uma identidade de prontidão antiga mantenha um serviço saudável em `INICIANDO`.

A suíte passou novamente com 48 testes e 0 falhas; o `.app` foi empacotado e assinado novamente.

## Benchmark local ScreenPipe (revalidação)

- Os dados foram integrados ao pacote local `/Users/joaopaulo/Meu Drive/Projetos (1)/DadosTeste`, preservando os artefatos originais.
- A tela inicial do Grafico agora é `Benchmark de modelos locais`; a tela `Projetos` ficou reservada para DevFlow/TTS.
- Quatro modelos aparecem como carregados: Qwen3 8B variant, Phi-4 Mini, Bonsai 8B 1-bit e Bonsai 27B 1-bit.
- A página mostra cards, qualidade, tempo médio, casos executados, segurança e gráficos comparativos; `007-ScreenPipe-Comparativo-Final` abre o ranking final.
- `npm run build`: passou e sincronizou 27 workflows, 227 execuções e 4 modelos locais.
- Smoke visual no navegador local: heading `Benchmark de modelos locais`, os quatro cards e os gráficos `Qualidade por modelo`/`Tempo médio de resposta` foram encontrados no DOM renderizado.
- O serviço foi reiniciado após o build e continua em `127.0.0.1:3011`.

Backup pré-alteração desta rodada: `/Users/joaopaulo/Documents/Backups/sm-graficos-screenpipe-20260915-053756`.
