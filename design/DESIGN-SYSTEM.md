# Design System — Orquestrador Local (macOS Native)

Este documento define as diretrizes visuais, tokens de estilo, componentes e regras de acessibilidade do **Orquestrador Local**, utilitário nativo macOS construído em Swift e SwiftUI.

---

## 1. Princípios de Design

1. **Autenticidade macOS**: Interface com respeito estrito às *Apple Human Interface Guidelines (HIG)*. Utilização de `NavigationSplitView`, `ToolbarItem`, `MenuBarExtra`, materiais translúcidos (`.ultraThinMaterial`) e tipografia de sistema.
2. **Clareza Operacional e Restrição**: O utilitário existe para fornecer visibilidade calma e controle previsível. Nenhuma ação destrutiva acidental, sem excesso de métricas não acionáveis, e sem gráficos supérfluos.
3. **Sem Emojis**: Todo elemento interativo e indicativo de estado utiliza desenho vetorial (SVG / SF Symbols) acompanhado de rótulos textuais explícitos e acessíveis.
4. **Respeito ao Modo Claro e Escuro**: Suporte dinâmico através de tokens semânticos (`Color.primary`, `Color.secondary`, `NSColor.windowBackgroundColor`, etc.) garantindo contraste WCAG AA/AAA em ambos os ambientes.
5. **Transparência de Dados**: Qualquer informação demonstrativa, simulada ou estimada é explicitamente sinalizada através do selo **CONCEITO / DADOS SINTÉTICOS**.

---

## 2. Paleta de Cores e Tokens Semânticos

A paleta herda as tonalidades nobres e sóbrias do CasaCapital, adaptando-as para pares dinâmicos de Claro/Escuro (`Light Appearance` e `Dark Appearance`).

### 2.1 Tabela de Tokens de Cor

| Nome do Token | Papel Semântico | Modo Claro (Hex) | Modo Escuro (Hex) | Equivalente SwiftUI / AppKit |
|---|---|---|---|---|
| `accentNavy` | Marca primária, cabeçalhos, botões de destaque | `#0f172a` | `#38bdf8` (ou `#e2e8f0` em texto) | `Color("accentNavy")` |
| `accentNavyStrong` | Estados ativos / hover intenso | `#020617` | `#0f172a` | `Color("accentNavyStrong")` |
| `stateSuccess` / `greenGrowth` | Estado "Pronto", execução saudável, verificação OK | `#059669` | `#34d399` | `Color.green` / `Color("stateSuccess")` |
| `stateSuccessBg` | Fundo de badges e alertas de sucesso | `#ecfdf5` | `#064e3b` (30% opacidade) | `Color("stateSuccessBg")` |
| `stateWarning` / `goldWarning` | Estado de atenção, parada bloqueada, verificação pendente | `#d97706` | `#fbbf24` | `Color.orange` / `Color("stateWarning")` |
| `stateWarningBg` | Fundo de alertas de aviso | `#fef3c7` | `#78350f` (30% opacidade) | `Color("stateWarningBg")` |
| `stateDanger` | Erro crítico, conflito de porta irrecuperável | `#dc2626` | `#f87171` | `Color.red` / `Color("stateDanger")` |
| `stateDangerBg` | Fundo de cards/badges de erro | `#fef2f2` | `#7f1d1d` (30% opacidade) | `Color("stateDangerBg")` |
| `stateNeutral` | Estado "Parado", inativo | `#64748b` | `#94a3b8` | `Color.secondary` / `Color("stateNeutral")` |
| `stateNeutralBg` | Fundo de badges inativas | `#f1f5f9` | `#1e293b` | `Color("stateNeutralBg")` |
| `stateExternal` | Gerenciado externamente por outro processo | `#0284c7` | `#38bdf8` | `Color.blue` / `Color("stateExternal")` |
| `stateExternalBg` | Fundo para badges de serviço externo | `#f0f9ff` | `#0c4a6e` (30% opacidade) | `Color("stateExternalBg")` |
| `appBg` | Fundo da janela principal | `#f8fafc` | `#0f172a` | `NSColor.windowBackgroundColor` |
| `cardSurface` | Fundo de cards, painéis e popover | `#ffffff` | `#1e293b` | `NSColor.controlBackgroundColor` |
| `cardSurfaceSecondary`| Superfície elevada / tabela | `#f1f5f9` | `#334155` | `NSColor.secondaryLabelColor` |
| `borderDefault` | Divisores e bordas de cards | `#e2e8f0` | `#334155` | `NSColor.separatorColor` |
| `borderStrong` | Bordas ativas / foco de teclado | `#cbd5e1` | `#475569` | `Color("borderStrong")` |
| `textPrimary` | Títulos, rótulos principais | `#0f172a` | `#f8fafc` | `Color.primary` |
| `textSecondary` | Subtítulos, metadados, unidades | `#64748b` | `#94a3b8` | `Color.secondary` |
| `textMuted` | Textos de rodapé, timestamps de baixa relevância | `#94a3b8` | `#64748b` | `Color.tertiaryLabel` |

---

## 3. Tipografia

No CasaCapital, a tipografia dependia das fontes web `Outfit` (títulos) e `Plus Jakarta Sans` (corpo). No macOS, o Orquestrador Local adota a família **SF Pro** nativa do sistema operacional, eliminando downloads externos, melhorando o tempo de inicialização e garantindo renderização otimizada no motor de texto do CoreText/Metal.

### 3.1 Mapeamento Tipográfico

| Função Visual | Fonte CasaCapital | Estilo SwiftUI | Tamanho (pt) | Peso (Weight) | Espaçamento (Tracking) |
|---|---|---|---|---|---|
| **Título da Janela** | Outfit ExtraBold | `.title2` | 20pt | Bold (700) | `-0.015em` |
| **Título de Seção / Card** | Outfit Bold | `.headline` | 15pt | Semibold (600) | `-0.01em` |
| **Subtítulo / Metadado** | Plus Jakarta Sans | `.subheadline` | 13pt | Regular (400) | `0em` |
| **Corpo do Texto** | Plus Jakarta Sans | `.body` | 13pt | Regular (400) | `0em` |
| **Rótulo de Ação / Botão** | Plus Jakarta Sans Bold | `.callout` | 12pt | Medium (500) / Semibold | `0em` |
| **Badges de Estado** | Plus Jakarta Sans Bold | `.caption1` | 11pt | Bold (700) | `+0.02em` |
| **Métricas / Portas / PIDs** | Outfit Medium (Mono fallback) | `.system(.callout, design: .monospaced)` | 12pt | Medium (500) | `0em` |
| **Avisos Legais / Watermarks** | Outfit SemiBold | `.caption2` | 10pt | Heavy (800) | `+0.06em` (caps) |

---

## 4. Escala de Espaçamentos (Layout Grid)

O sistema segue a grade base de **4pt/8pt** padrão do ecossistema Apple:

| Token | Dimensão | Aplicação Prática |
|---|---|---|
| `space-xxs` | 2pt | Micro-espaçamento interno de badges e ícones compostos |
| `space-xs` | 4pt | Distância entre ícone e texto de botão compacto |
| `space-sm` | 8pt | Espaçamento entre campos de formulário e itens de lista densa |
| `space-md` | 12pt | Padding interno de cards secundários e botões normais |
| `space-lg` | 16pt | Padding padrão de cartões de projeto e margens laterais de painéis |
| `space-xl` | 20pt | Padding do painel do menu-bar popover e cabeçalho da janela principal |
| `space-2xl` | 24pt | Margens externas da janela e espaçamento entre seções de detalhes |
| `space-3xl` | 32pt | Espaçamento de áreas de estado vazio (`EmptyStateView`) |

---

## 5. Raios de Canto (Corner Radii)

Em alinhamento com os tokens `--cc-radius-*` do CasaCapital e a estética *Continuous Squircle* do macOS:

| Token | Raio | Uso no macOS |
|---|---|---|
| `radius-sm` | 6px–8px | Badges de status, botões pequenos, inputs de texto |
| `radius-md` | 10px–12px | Cards de serviço do catálogo, botões de ação principal, popovers |
| `radius-lg` | 16px–20px | Painel do Menu-bar (`MenuBarExtra`), janelas de diálogo modal |

---

## 6. Sombras e Profundidade (Elevation)

No macOS, a profundidade física das janelas é controlada pelo sistema operacional. Os componentes internos aplicam sombras sutis apenas para separar cartões sobre superfícies neutras:

| Nível de Elevação | Especificação CSS / SwiftUI | Aplicação |
|---|---|---|
| **Plano (Flat)** | Nenhuma sombra; borda sutil de 1px `borderDefault` | Cards dentro de lista rolante, formulários |
| **Elevado (Card)** | `x: 0, y: 2, blur: 6, opacity: 0.04` | Hover de cards de projeto, cartões interativos |
| **Flutuante (Popover / MenuBar)** | `x: 0, y: 8, blur: 24, opacity: 0.12` | Popover da barra de menus, diálogos de confirmação |

---

## 7. Matriz de Estados de Serviço

Cada serviço no catálogo possui um estado exclusivo e não ambíguo. O design impõe consistência absoluta entre cor, ícone vetorial e texto descritivo.

| Estado | Cor de Destaque | Fundo do Badge | Símbolo Visual | Rótulo Textual Obrigatório | Descrição Operacional |
|---|---|---|---|---|---|
| **Pronto** | `#059669` (Verde) | `#ecfdf5` | Checkmark circular (`✓`) | `Pronto` | Serviço ativo, respondendo ao healthcheck local na porta configurada. |
| **Iniciando** | `#d97706` (Dourado) | `#fef3c7` | Círculo pontilhado / Spinner (`◌`) | `Iniciando...` | Processo lançado; aguardando resposta positiva do endpoint de prontidão. |
| **Parando** | `#d97706` (Dourado) | `#fef3c7` | Círculo pontilhado de redução (`◌`) | `Parando...` | Sinal de encerramento enviado; aguardando desocupação de porta/PID. |
| **Parado** | `#64748b` (Slate) | `#f1f5f9` | Quadrado de parada (`■`) | `Parado` | Processo não está em execução; portas livres. |
| **Erro** | `#dc2626` (Vermelho) | `#fef2f2` | Triângulo com exclamação / X (`✗`) | `Erro de Execução` | Falha ao iniciar, timeout de healthcheck ou terminação inesperada. |
| **Externo** | `#0284c7` (Azul) | `#f0f9ff` | Seta direcional externa (`↗`) | `Gerenciado Externamente` | Serviço detectado em execução, porém lançado fora do Orquestrador Local. |
| **Desconhecido** | `#94a3b8` (Muted) | `#f8fafc` | Ponto de interrogação / Tilde (`~`) | `Atividade Desconhecida` | Serviço ativo, porém sem telemetria de requisições ou logs acessíveis. |

---

## 8. Regras de Ações e Hierarquia de Botões

As ações do usuário são restritas aos quatro verbos autorizados:

1. **Iniciar**:
   - *Aparência*: Botão primário (`.borderedProminent`), fundo `accentNavy` (`#0f172a`), texto branco, ícone `Play` (triângulo à direita).
   - *Comportamento*: Habilitado apenas quando o estado for `Parado` ou `Erro`.
2. **Parar**:
   - *Aparência*: Botão secundário de contenção (`.bordered`), borda sutil, texto `accentNavy` ou `stateDanger` (quando seguro), ícone `Stop` (quadrado).
   - *Comportamento*: Habilitado quando `Pronto`. Se houver trabalho ativo detectado, bloqueia com explicação e não permite forçar encerramento.
3. **Abrir**:
   - *Aparência*: Botão de ação direta (`.bordered`), ícone `ExternalLink` (quadrado com seta 45°).
   - *Comportamento*: Abre a interface web do serviço local no navegador padrão (`http://127.0.0.1:<porta>`). Ativo somente se `Pronto`.
4. **Detalhes**:
   - *Aparência*: Botão terciário / ghost (`.buttonStyle(.plain)` com hover), ícone `Info` (círculo com 'i').
   - *Comportamento*: Seleciona o serviço para exibir o painel detalhado com histórico, logs resumidos e métricas estimadas.

**Ações Proibidas no Sistema**: `Forçar Encerramento (Kill -9)`, `Parar Todos`, `Limpar Diretório`, `Instalar Dependências`.

---

## 9. Diretrizes de Acessibilidade (A11y)

### 9.1 Relação de Contraste (WCAG 2.1 AA/AAA)
- **Texto Principal (`#0f172a`) sobre Fundo App (`#f8fafc`)**: Taxa **17.06:1** (Supera requisito AAA de 7:1).
- **Texto Principal Modo Escuro (`#f8fafc`) sobre Superfície Escura (`#1e293b`)**: Taxa **13.98:1** (Supera AAA).
- **Acentos não são texto normal**: `#059669` sobre branco mede **3,77:1** e `#d97706` sobre branco mede **3,19:1**; portanto são reservados a ícones, bordas e áreas decorativas. Texto usa tokens semânticos auditados sobre o fundo efetivo.
- **Erro no painel**: `OrqDangerText` é usado sobre `OrqDangerBg` — claro `#991b1b/#fef2f2` (**7.60:1**) e escuro `#fca5a5/#7f1d1d` (**5.28:1**). O token `OrqDanger` (#dc2626 / #f87171) é validado sobre card (**4.62:1 / 5.29:1**), formulário (**4.83:1 / 5.29:1**) e popover (**4.83:1 / 5.29:1**).
- **Badges de estado**: verde `#047857/#ecfdf5` (**5.21:1**) e dourado `#92400e/#fef3c7` (**6.37:1**) para texto claro; escuro verde `#34d399/#064e3b` (**5.06:1**) e dourado `#fbbf24/#78350f` (**5.43:1**), todos verificados pelo script de contraste.
- **Texto Muted (`#475569`) sobre Fundo Neutro (`#f1f5f9`)**: Taxa **6.92:1** (Supera requisito AA).

### 9.2 Navegação por Teclado e Foco
- Todos os cartões de serviço são acessíveis via navegação padrão de lista do macOS (setas `Cima` / `Baixo`).
- Atalhos universais:
  - `Cmd+N`: Adicionar novo serviço ao catálogo.
  - `Cmd+R`: Revalidar status / healthcheck de todos os serviços.
  - `Cmd+Return`: Iniciar serviço selecionado (ou salvar no formulário de cadastro).
  - `Cmd+O`: Abrir interface web do serviço selecionado no navegador padrão.
  - `Cmd+.`: Parar serviço selecionado (quando permitido e não ocupado).
  - `Esc`: Cancelar / fechar modal de cadastro.
- O anel de foco segue o padrão visual do macOS (`FocusRingStyle`), com borda ativa em `Color.accentColor`.

### 9.3 VoiceOver
- Nenhum controle é somente ícone. Todo botão, badge ou elemento informativo sem texto adjacente possui `.accessibilityLabel("...")` explícito.
- Os estados contêm rótulo composto acessível via VoiceOver: ex. *"mflux-studio, estado: pronto"*, com `.accessibilityValue` refletindo o último erro ou o estado de atividade ("Ocioso", "Ocupado", "Atividade não verificada").
- Elementos meramente decorativos utilizam `.accessibilityHidden(true)`.
