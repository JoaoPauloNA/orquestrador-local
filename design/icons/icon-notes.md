# Avaliação de Legibilidade e Mapeamento de Ícones — Orquestrador Local

Este documento registra os testes de legibilidade visual, a verificação de compatibilidade com o catálogo **SF Symbols** do macOS e as limitações de exportação gráfica.

---

## 1. Avaliação de Legibilidade do Menu-Bar Mark (18×18 px)

O ícone da barra de menus (`menubar-mark.svg`) foi submetido a inspeção dimensional em escala real (18×18 pt / 36×36 px em display Retina @2x):

| Critério de Inspeção | Parâmetro Avaliado | Resultado | Observações Técnicas |
|---|---|---|---|
| **Alinhamento na Grade de Pixels** | Bordas e traços inteiros | **APROVADO** | O círculo externo e os nós internos utilizam coordenadas inteiras ou semi-inteiras para evitar borrões de antialiasing. |
| **Espessura do Traço** | Traço mínimo de 1.75px | **APROVADO** | Mantém contraste nítido tanto em fundos escuros (Dark Menu Bar) quanto em fundos claros (Light Menu Bar). |
| **Distingüibilidade da Abertura** | Espaço de 3.5px no quadrante superior | **APROVADO** | A descontinuidade do anel e o satélite orbital superior direito são claramente perceptíveis à distância de operação (50–70 cm da tela). |
| **Comportamento como Template** | `NSImage.isTemplate = true` | **APROVADO** | O desenho usa exclusivamente `stroke="currentColor"` e `fill="currentColor"`, permitindo que o macOS alterne automaticamente entre branco e grafite escuro conforme o papel de parede. |

---

## 2. Mapeamento e Verificação de SF Symbols

A tabela a seguir documenta a correspondência direta entre a linguagem SVG e a biblioteca nativa **SF Symbols** (disponíveis a partir do macOS 12 Monterey até macOS 15 Sequoia):

| Ação / Estado | Nome do SVG | SF Symbol Canônico | Disponibilidade macOS | Modo de Renderização | Rótulo VoiceOver (Acessibilidade) |
|---|---|---|---|---|---|
| **Iniciar** | `icon-play` | `play.fill` | macOS 11.0+ | Monocromático | "Iniciar serviço" |
| **Parar** | `icon-stop` | `stop.fill` | macOS 11.0+ | Monocromático (Danger) | "Parar serviço com segurança" |
| **Abrir** | `icon-external`| `arrow.up.forward.square` | macOS 11.0+ | Monocromático | "Abrir interface no navegador" |
| **Detalhes** | `icon-info` | `info.circle` | macOS 11.0+ | Monocromático | "Ver detalhes e métricas do serviço" |
| **Pronto** | `state-ready` | `checkmark.circle.fill` | macOS 11.0+ | Multicolor / Hierárquico | "Estado: Pronto. Respondendo localmente" |
| **Iniciando** | `state-starting`| `arrow.triangle.2.circlepath` | macOS 11.0+ | Monocromático (Dourado) | "Estado: Iniciando. Aguardando prontidão" |
| **Parando** | `state-stopping`| `circle.dotted` | macOS 12.0+ | Monocromático (Dourado) | "Estado: Parando. Encerrando processo" |
| **Parado** | `state-stopped` | `stop.circle` | macOS 11.0+ | Hierárquico (Muted) | "Estado: Parado" |
| **Erro** | `state-error` | `exclamationmark.triangle.fill` | macOS 11.0+ | Multicolor (Vermelho) | "Estado: Erro de execução detectado" |
| **Externo** | `state-external`| `arrow.forward.square` | macOS 11.0+ | Hierárquico (Azul) | "Estado: Gerenciado externamente" |
| **Desconhecido**| `state-unknown` | `questionmark.circle` | macOS 11.0+ | Hierárquico (Cinza) | "Estado: Atividade desconhecida" |

---

## 3. Avaliação do App Icon (`app-icon.svg`)

* **Diferenciação do CasaCapital**: O ícone do CasaCapital utiliza a silhueta explícita de uma casa com duas barras verticais verdes e uma esfera dourada. O ícone do Orquestrador Local **não utiliza formato de casa**, substituindo-o por um núcleo hexagonal de contenção com arcos concêntricos de supervisão (dourado e verde) e satélites de processo sobre uma base contínua squircle (`rx="104"`).
* **Profundidade e Sombras**: Utiliza sistema de sombreamento duplo compatível com a iluminação neutra dos ícones nativos do macOS Sonoma/Sequoia.
* **Escalabilidade**: Testado em resoluções de 512×512 pt (visualização master), 128×128 pt (Finder e Launchpad) e 32×32 pt (visualização em lista). O anel externo dourado e o núcleo verde permanecem legíveis mesmo em tamanhos reduzidos.

---

## 4. Limitações e Recomendações

1. **Ausência de Emojis**: O aplicativo adota estritamente SVGs vetoriais e SF Symbols. Não deve ser introduzido nenhum glifo Unicode de emoji em títulos, alertas ou botões.
2. **Ambiente de Build do Xcode**: Ao importar para o `Assets.xcassets`, o `app-icon.svg` deve ser exportado nos tamanhos nominais de ícones macOS (16, 32, 64, 128, 256, 512 e 1024 px @1x/@2x) utilizando a ferramenta `actool` ou exportação direta via script de automação.
