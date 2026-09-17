Data: 2026-09-08
Comando/fonte: `swift test`; `scripts/package-app.sh`; inspeção AX da janela real do app
Esperado: LocalTranscriber aparecer no catálogo com controles de iniciar, verificar e abrir, sem iniciar automaticamente.
Observado: Serviço exibido como `LocalTranscriber`, estado `PARADO`, prontidão `http://127.0.0.1:8766/api/health`; controles visíveis; LaunchAgent criado com `RunAtLoad=false`. O formato inicial com script Zsh falhou com código 127; foi corrigido para executar diretamente o Python do `.venv` com `-m uvicorn`. Smoke operacional iniciou o serviço, recebeu `{"ok":true}` e o serviço foi devolvido ao estado parado.
Testes: 40 testes Swift aprovados; pacote `.app` validado por `codesign --verify --deep --strict`; listener 8766 confirmado durante o smoke e ausente após o bootout.
Correção posterior: o serviço havia sido deixado parado, causando `ERR_CONNECTION_REFUSED`; foi carregado novamente pelo LaunchAgent e `/api/health` respondeu 200. Também foi adicionado `favicon.svg`, que passou a responder 200.
Classificação: IMPLEMENTADO; serviço atualmente em execução na porta 8766.
