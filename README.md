# Orquestrador Local

## Segunda Mente

O catálogo registra **Segunda Mente** como o LaunchAgent
`com.joaopaulo.segunda-mente`. Ele serve o build de produção em
`http://127.0.0.1:3010/`, com prontidão em `/api/health` e modo `HYBRID`.

O comando gerenciado é `npm run start -- --hostname 127.0.0.1 --port 3010`.
Foi escolhida a execução de produção, e não `npm run dev`, para evitar o
watcher/compilador de desenvolvimento em um serviço persistente. O build deve
estar válido antes de iniciar; o painel preserva somente a variável não
sensível de modo de dados e não copia caminho do vault ao LaunchAgent.

Aplicativo macOS nativo (SwiftUI) para cadastrar e operar, com segurança, LaunchAgents do usuário já aprovados. A versão entregue controla apenas perfis validados: não executa comandos genéricos, não interpreta shell, não altera plists de pilotos e não encerra processos por nome ou porta.

## Catálogo declarativo de serviços

`Sources/OrquestradorLocal/Resources/services.yaml` concentra os três perfis
locais gerenciados: Segunda Mente, ComfyUI e mflux-studio. Na inicialização, o
aplicativo lê e valida os LaunchAgents já existentes; o catálogo não cria,
substitui, descarrega ou desabilita esses arquivos. Cada detalhe do serviço
exibe endpoint, porta, plist, diretório, PID, último erro e saída limitada.

O botão **Reiniciar** usa a mesma parada graciosa e as mesmas proteções de
atividade do botão **Parar**. O estado pronto só é atribuído depois de o
endpoint de prontidão responder com a identidade esperada.

## Abrir o aplicativo

Abra `dist/Orquestrador Local.app` pelo Finder. O pacote é assinado ad-hoc localmente; não há notarização nem distribuição pública. Não desative Gatekeeper ou SIP. Para gerar novamente, no diretório do projeto, execute `scripts/package-app.sh`.

## Uso

1. Escolha **Adicionar Serviço** e preencha somente um LaunchAgent já existente em `~/Library/LaunchAgents`.
2. O cadastro valida label, plist, executável, diretório, fingerprint e URLs loopback antes de persistir.
3. **Iniciar** e **Parar** usam `launchctl` com argumentos separados. Parar só é permitido para o supervisor e executável aprovados.
4. Trabalho ocupado bloqueia a parada. Atividade desconhecida ou não suportada exige a confirmação manual e, depois, o clique explícito em **Parar**; marcar a caixa não envia nenhum sinal.

Pilotos reais exigem a janela G1 e aceite humano descritos em `evidencias/matriz-aceite-2026-09-06.md`.
