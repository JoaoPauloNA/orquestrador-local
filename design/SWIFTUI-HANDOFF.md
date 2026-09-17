# Especificação de Handoff para Engenharia SwiftUI

Este documento serve como a ponte técnica entre o design visual e a futura implementação em código nativo Swift/SwiftUI do **Orquestrador Local**, orientando os desenvolvedores nas fases F1 (Fundação), F2 (Controle) e F3 (Interface).

---

## 1. Mapeamento de Componentes de Design → SwiftUI

| Elemento Visual | Componente / Modificador SwiftUI Equivalente | Observações Técnicas |
|---|---|---|
| **Janela Principal** | `WindowGroup("Orquestrador Local", id: "main-window")` | Configurado com estilo `.windowStyle(.hiddenTitleBar)` ou `.unifiedCompact`. |
| **Navegação Split** | `NavigationSplitView(sidebar: { ... }, detail: { ... })` | Largura da sidebar fixada com `.navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)`. |
| **Utilitário Menu-Bar** | `MenuBarExtra("Orquestrador", image: "OrqMenuBar")` | Utilizar estilo de janela `.menuBarExtraStyle(.window)`. Permite interatividade rica. |
| **Cartão de Serviço** | `VStack(alignment: .leading)` com `.background(Color(nsColor: .controlBackgroundColor))` | Cantos com `.clipShape(RoundedRectangle(cornerRadius: 10))` e borda sutil `.stroke(Color.separator, lineWidth: 1)`. |
| **Badge de Estado** | `HStack(spacing: 4) { Image(...); Text(...) }` | Estilizado com `.font(.caption2.bold())`, `.padding(.horizontal, 8)`, `.padding(.vertical, 4)`, `.background(Capsule().fill(bgColor))`. Cores separadas para texto (AA) e ícone. |
| **Atividade Operacional** | `HStack { Image(...); Text(...) }` | Exibe estado de atividade: `Ocioso`, `Ocupado` ou `Atividade não verificada`. Ausência de sinal nunca é tratada como ocioso. |
| **Botões de Ação** | `Button("Iniciar", systemImage: "play.fill")` | Estilizados com `.buttonStyle(.borderedProminent)` (ações primárias) e `.buttonStyle(.bordered)` (secundárias). |
| **Banner de Erro / Alerta** | `HStack { Image(...); Text(...) }` | Fundo semântico (`OrqDangerBg`/`OrqGoldBg`) com texto de alto contraste (`OrqDangerText`/`OrqGoldText`). |
| **Sheet Modal (Cadastro)** | `.sheet(isPresented: $showRegistration) { RegistrationView() }` | Modal nativo com validação `ProfileValidator` e atalhos de teclado (Cmd+Return para salvar, Esc para cancelar). |

---

## 2. Máquina de Estados e Arquitetura Reativa

O estado de cada serviço é gerenciado pela máquina de estados estrita:

### 2.1 Enum Canônico de Ciclo de Vida
```swift
import SwiftUI

public enum ServiceLifecycleState: String, CaseIterable, Identifiable, Sendable, Codable {
    case stopped    = "PARADO"
    case starting   = "INICIANDO"
    case ready      = "PRONTO"
    case stopping   = "PARANDO"
    case error      = "ERRO"
    case external   = "EXTERNO"
    case unknown    = "DESCONHECIDO"

    public var id: String { rawValue }

    public var sfSymbol: String {
        switch self {
        case .stopped:  return "circle"
        case .starting: return "progress.indicator"
        case .ready:    return "checkmark.circle.fill"
        case .stopping: return "progress.indicator"
        case .error:    return "xmark.circle.fill"
        case .external: return "arrow.up.right.circle"
        case .unknown:  return "questionmark.circle"
        }
    }
}
```

### 2.2 Transições Autorizadas da Máquina de Estados
```
            ┌─────────────── [ INICIAR ] ───────────────┐
            │                                           ▼
       [ PARADO ] ───────────────────────────────► [ INICIANDO ]
            ▲                                           │
            │                                           ├─ (Health 200) ──► [ PRONTO ]
            │                                           │                      │
            │                                           └─ (Timeout/Fail) ──┐  │
            │                                                               │  │ [ PARAR ]
            │                                                               ▼  ▼
       [ PARANDO ] ◄──────────────────────────────────────────────────── [ ERRO ]
            │                                                               ▲
            └────────────── (Processo encerrou com sucesso) ────────────────┘
```
- **Regra F1/F2**: A transição para `PRONTO` só ocorre quando o endpoint de prontidão retornar código 200 e payload ou header correspondente ao fingerprint do projeto.

---

## 3. Configuração do Catálogo de Ativos (`Assets.xcassets`)

As cores semânticas devem ser cadastradas com suporte a Light e Dark Appearance:

```
Assets.xcassets/
├── AccentColor.colorset
├── OrqNavy.colorset          (Light: #0f172a, Dark: #f1f5f9)
├── OrqNavyStrong.colorset    (Light: #020617, Dark: #ffffff)
├── OrqGreen.colorset         (Light: #059669, Dark: #10b981)
├── OrqGold.colorset          (Light: #d97706, Dark: #f59e0b)
├── OrqDanger.colorset        (Light: #ef4444, Dark: #f87171)
├── OrqMuted.colorset         (Light: #64748b, Dark: #94a3b8)
├── AppIcon.appiconset        (Renderizado a partir de design/icons/app-icon.svg)
└── OrqMenuBar.imageset       (Vetor PDF/SVG template a partir de design/icons/menubar-mark.svg)
```

### 3.1 Configuração de Imagem Template para MenuBar
No arquivo `Contents.json` de `OrqMenuBar.imageset`:
```json
{
  "images" : [
    {
      "filename" : "menubar-mark.svg",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "template-rendering-intent" : "template"
  }
}
```

---

## 4. Configuração de MenuBarExtra

Para garantir que o popover permaneça leve e nativo:

```swift
@main
struct OrquestradorLocalApp: App {
    @State private var coordinator = OrchestrationCoordinator()

    var body: some Scene {
        // Janela Principal do Gerenciador
        WindowGroup("Orquestrador Local", id: "main-window") {
            MainWindowView()
                .environment(coordinator)
                .frame(minWidth: 720, minHeight: 480)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 860, height: 580)

        // Utilitário de Menu-Bar
        MenuBarExtra {
            MenuBarPopoverView()
                .environment(coordinator)
        } label: {
            Image("OrqMenuBar")
                .accessibilityLabel("Orquestrador Local Menu Bar")
        }
        .menuBarExtraStyle(.window)
    }
}
```

---

## 5. Implementação de Acessibilidade (VoiceOver)

O HIG exige que controles visuais sem texto adjacente sejam plenamente acessíveis por tecnologia assistiva:

```swift
// Exemplo de botão compacto de parada com acessibilidade completa
Button(role: .destructive) {
    service.requestStop()
} label: {
    Image(systemName: "stop.fill")
        .frame(width: 18, height: 18)
}
.accessibilityLabel("Parar serviço \(service.name)")
.accessibilityHint("Emite comando de encerramento suave para o supervisor")
.help("Parar serviço \(service.name)")

// Exemplo de badge com leitura semântica
HStack(spacing: 4) {
    Image(systemName: service.state.sfSymbol)
    Text(service.state.rawValue)
}
.accessibilityElement(children: .combine)
.accessibilityLabel("Status do serviço \(service.name): \(service.state.rawValue).")
.accessibilityValue("Última verificação há \(service.secondsSinceLastCheck) segundos.")
```

---

## 6. Pontos em Aberto para o Spike F1/F2

Estes itens de arquitetura devem ser validados experimentalmente no início da fase de implementação:

1. **Target Mínimo do macOS**:
   - Proposta atual: macOS 14.0 (Sonoma) para usufruir de `MenuBarExtra` maduro e `@Observable`.
   - Verificar se o Mac de desenvolvimento do operador roda Sonoma ou Sequoia.
2. **Sandbox e Execução de Processos**:
   - O aplicativo precisará interagir com `launchctl` (`/bin/launchctl`).
   - Aplicativos em Sandbox restrita não podem chamar `launchctl` diretamente sem entitlements específicos.
   - Na V1 (distribuição pessoal sem App Store), a compilação com `App Sandbox = NO` e assinatura Ad-Hoc/Developer ID é o caminho recomendado. Confirmar viabilidade no spike F1.
3. **Semântica de Comandos do launchd**:
   - Comparar comportamento entre `launchctl bootout gui/$(id -u)/<label>` vs `launchctl stop <label>`.
   - Validar se processos descendentes criados por Python/uvicorn são encerrados por herança de sessão ou se exigem tratamento específico.
4. **Verificação de Atividade sem Endpoint Dedicado**:
   - Para serviços como ComfyUI que podem não expor endpoint HTTP REST de fila, validar se uma sonda de socket local TCP (checagem de tráfego de rede) é viável ou se o diálogo de confirmação (Tela 08) deve ser o padrão operacional seguro.
