# Implementação codex2 Terra — evidência técnica

Data: 2026-09-06. Classificação: PARCIAL, com fundação/controle sintético/UI/pacote implementados; sem aceite V1.

## Alterações e verificações

- Corrigidos os tokens realmente usados para texto de estado: `OrqMuted` claro, `OrqDangerText` escuro e `OrqExternalText` escuro. `scripts/verify-contrast.py` mede 10 pares reais; todos atingiram ao menos 4,5:1.
- A UI mantém atividade e ciclo de vida separados. Para `unknown`/`notSupported`, a confirmação começa desmarcada e o botão Parar fica desabilitado até a confirmação e clique próprio; `busy` bloqueia a parada.
- Fixture em loopback usa um LaunchAgent temporário com label exclusivo, porta 19765 e diretório temporário. O primeiro ensaio revelou que `launchd` não pode ler o fixture sob Documents (TCC); o runner agora copia apenas o fixture sintético para o diretório temporário próprio. O ciclo start/prontidão/fila idle+busy/bootout passou e o plist temporário foi removido.
- Capturas renderizadas nativas: `visuais/janela-pequena-clara.png`, `visuais/janela-pequena-escura.png` e `visuais/janela-compacta-escura.png`. Inspeção visual: sem sobreposição, corte de rótulos ou espaçamento ícone/texto defeituoso na tela vazia. A captura compacta preservou o tamanho restaurado pelo macOS; não é prova de redimensionamento manual a 720×480.
- Pacote: `dist/Orquestrador Local.app`, assinado ad-hoc localmente e verificado com `codesign --verify --deep --strict`. Sem notarização.
