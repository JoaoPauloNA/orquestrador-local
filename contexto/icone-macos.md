# Resolução e Empacotamento de Ícone macOS — Orquestrador Local

## Diagnóstico
O aplicativo continha o arquivo multirresolução `AppIcon.icns` (16x16 até 1024x1024 px) em `Contents/Resources/AppIcon.icns`, mas o `Info.plist` declarava apenas `CFBundleIconName: AppIcon` (chave destinada a Asset Catalogs), faltando `CFBundleIconFile: AppIcon`.
No macOS, o Finder, Launchpad e `NSWorkspace` utilizam prioritariamente `CFBundleIconFile` para associar o arquivo `.icns` do bundle ao aplicativo. Sem essa chave, o sistema exibia o ícone genérico de aplicativo.

## Correção Aplicada
1. Adição da chave `CFBundleIconFile: AppIcon` em `Sources/OrquestradorLocal/Resources/Info.plist` (garantindo que empacotamentos subsequentes via `scripts/package-app.sh` preservem a configuração).
2. Atualização cirúrgica de `dist/Orquestrador Local.app/Contents/Info.plist`.
3. Re-assinatura ad-hoc (`codesign --force --sign - --timestamp=none`) e validação estrita.
4. Registro de atualização no LaunchServices via `lsregister -f`.

## Duplicidade de Entradas no Launchpad / Spotlight
O Spotlight indexa duas instâncias do aplicativo com o mesmo `CFBundleIdentifier`:
- `dist/Orquestrador Local.app` (aplicativo corrente ativo).
- `work/ol-v1-r4/evidence/app-smoke/Orquestrador Local Round4.app` (cópia histórica preservada de fumaça da rodada 4).

Ambas são preservadas sem exclusão. O LaunchServices foi notificado especificamente para a versão corrente `dist/`.

## Limitações Conhecidas
- A resolução programática via `NSWorkspace.shared.icon(forFile:)` foi confirmada com sucesso (extração de 1024x1024 px com núcleo verde/dourado/navy).
- O cache visual do Launchpad/Dock é gerenciado pelo daemon do sistema macOS (`com.apple.dock` / QuickLook / LaunchServices daemon) e pode reter caches temporários até reinicialização ou atualização periódica do Finder. Não foram executados resets globais destrutivos (`killall Dock` ou deleção de banco de dados do Launchpad) conforme restrição operacional.


## Correção de evidência após retorno do usuário
A captura posterior a r1 ainda mostrou ícones genéricos na grade Apps. Finder foi confirmado visualmente com ícone correto. Registro específico foi atualizado e Dock recarregado em r2; grade Apps permanece NÃO VERIFICADA por timeout da automação. Ver work/ol-icon/r2/RESULTADO.md.
