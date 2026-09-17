# Correção técnica Terra — 2026-09-06

Classificação: PARCIAL

- Contraste: `ServiceDetailView` passou a usar `OrqDangerText` sobre `OrqDangerBg`; `scripts/verify-contrast.py` confirmou 10/10 pares semânticos AA (erro: 7,60:1 claro, 5,28:1 escuro).
- Subprocessos: o adaptador drena stdout/stderr enquanto executa, limita cada retenção a 32 KiB em produção e limita duração a 8 s; os testes exercitaram saturação de 200 KiB por pipe, timeout de 250 ms e limite de 16 bytes.
- Catálogo: backup atômico/durável é escrito inclusive na primeira persistência e antes do primário; 2 testes corromperam o primário e recuperaram a versão validada sem apagar o arquivo corrompido.
- Fixture: teste de produto com label, plist, diretório e porta únicos iniciou o serviço através de `OrchestrationCoordinator`/`LaunchAgentAdapter`, confirmou pronto/ocioso, bloqueou ocupado e fez `bootout` gracioso. Artefatos próprios foram removidos.
- Recursos: `/usr/bin/time -l swift test --filter FixtureProductIntegrationTests`: intervalo 5,01 s, pico do processo testado 15,8 MB. Não substitui medição de repouso da aplicação empacotada.
- Pacote: build release, assinatura ad-hoc, `plutil` e `codesign --verify --deep --strict` passaram. Finder, VoiceOver, foco e sessão humana não foram executados.
