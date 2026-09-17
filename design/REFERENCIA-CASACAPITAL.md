# Referência Visual e Estrutural — CasaCapital MVP vs. Orquestrador Local

Este documento documenta formalmente a análise das referências visuais e estruturais do projeto **CasaCapital MVP** (`/Users/joaopaulo/Documents/Projetos/Pessoal/CasaCapital/Aplicacao`), estabelecendo o que foi **ADOTADO** (aproveitado diretamente), **ADAPTADO** (ajustado para a realidade de uma aplicação nativa macOS Swift/SwiftUI) ou **NÃO USADO** (rejeitado por não aderência ao domínio ou plataforma).

---

## 1. Análise por Arquivo de Origem

### 1.1 `DESIGN.md` (Manual de Identidade Visual e UX do CasaCapital)
* **Tokens de Cor Base**:
  * Navy Capital (`#0f172a`), Dark Slate (`#020617`), Verde Crescimento (`#059669`), Dourado Casa (`#d97706`), Ardósia Neutra (`#0f172a`), Slate Suave (`#64748b`), Fundo App (`#f8fafc`), Fundo Superfície (`#ffffff`), Borda Padrão (`#e2e8f0`), Borda Forte (`#cbd5e1`).
  * **Classificação**: **ADAPTADO**. Os valores hexadecimais de base foram preservados para o modo claro, mas foram remapeados para uma estrutura semântica com suporte nativo a Modo Escuro (Dark Mode) em macOS, onde `#0f172a` vira texto primário no modo claro e superfície/contraste no escuro.
* **Tipografia (`Outfit` + `Plus Jakarta Sans`)**:
  * **Classificação**: **ADAPTADO**. Substituído pela fonte nativa do sistema macOS (**SF Pro / -apple-system**), eliminando qualquer dependência de runtime do Google Fonts e assegurando alinhamento com os padrões Apple Human Interface Guidelines (HIG).
* **BrandLogo (Casa + Colunas + Esfera)**:
  * **Classificação**: **NÃO USADO**. A marca do CasaCapital representa moradia, finanças e patrimônio familiar. O Orquestrador Local é um utilitário de engenharia e supervisão de processos de IA/serviços locais. Foi desenhada uma nova marca abstrata de nós e fluxo orquestrado.
* **Regras de Layout (`AppShell`)**:
  * **Classificação**: **ADAPTADO**. A estrutura de navegação lateral (sidebar) e área principal foi adotada como referência composicional para a janela de gerenciamento desktop do macOS (`NavigationSplitView`), enquanto o drawer mobile e bottom nav foram descartados em favor de um Menu-bar Popover nativo (`MenuBarExtra`).
* **Acessibilidade e Proibição de Emojis**:
  * **Classificação**: **ADOTADO**. Regra estrita mantida integralmente: proibição de emojis em botões, títulos, status e feedback. Ícones acompanhados de texto claro e atributos de acessibilidade (`accessibilityLabel`).
* **Aviso de Conteúdo Mockado (`DevMockNotice`)**:
  * **Classificação**: **ADOTADO**. A exigência de identificação explícita de dados não reais foi convertida no watermark e selo persistente **CONCEITO / DADOS SINTÉTICOS** em todas as telas e mockups.

---

### 1.2 `frontend/src/styles/index.css` (Tokens CSS e Componentes Base)
* **Cores Semânticas Adicionais**:
  * `--cc-danger` (`#ef4444`), `--cc-danger-bg` (`#fef2f2`), `--cc-success` (`#059669`), `--cc-success-bg` (`#ecfdf5`), `--cc-focus` (`rgb(5 150 105 / 20%)`).
  * **Classificação**: **ADOTADO**. As cores de estado crítico e confirmação foram integradas diretamente na máquina de estados visuais dos serviços.
* **Raios de Canto (Corner Radii)**:
  * `--cc-radius-sm`: `8px`, `--cc-radius`: `12px`, `--cc-radius-lg`: `20px`.
  * **Classificação**: **ADOTADO**. Os valores 8px (badges e botões secundários), 12px (cards e janelas menores) e 20px (cards destacados / popover) são compatíveis com a geometria de cantos suaves (continuous squircle) do macOS Sonoma / Sequoia.
* **Sombras (Shadows)**:
  * `--cc-shadow`: `0 10px 15px -3px rgba(15, 23, 42, 0.04), 0 4px 6px -4px rgba(15, 23, 42, 0.04)`.
  * `--cc-shadow-lg`: `0 20px 25px -5px rgba(15, 23, 42, 0.08), 0 8px 10px -6px rgba(15, 23, 42, 0.08)`.
  * **Classificação**: **ADAPTADO**. Utilizado como referência de profundidade sutil para elevações de cards, adaptado para usar sombras do AppKit/SwiftUI integradas ao sistema de iluminação de janelas macOS.
* **Botões (`.btn`, `.btn-primary`, `.btn-secondary`, `.btn-danger`)**:
  * **Classificação**: **ADAPTADO**. Mapeados para botões SwiftUI com `.buttonStyle(.borderedProminent)`, `.buttonStyle(.bordered)` e variações com cores semânticas (`.tint`), respeitando a altura tátil padrão e atalhos de teclado nativos.

---

### 1.3 `frontend/src/layouts/AppShell.jsx` e `AppShell.css` (Navegação e Estrutura)
* **Sidebar Desktop Fixa (260px)**:
  * **Classificação**: **ADAPTADO**. No macOS SwiftUI, a barra lateral passa a ser uma `List` nativa dentro de uma `NavigationSplitView` com largura padrão de 220–260px, recolhível pelo usuário via atalho padrão do sistema (`Cmd+Opt+S`).
* **Cabeçalho com Marca + Badge de Status**:
  * **Classificação**: **ADOTADO**. O cabeçalho com o ícone do utilitário, nome da aplicação e badge de status ("Painel Local" / "Modo Simulado") segue o padrão de alinhamento do CasaCapital.
* **Navegação Categorizada**:
  * **Classificação**: **ADAPTADO**. Categorias financeiras foram descartadas. No Orquestrador Local, a barra lateral agrupa: *Catálogo de Serviços*, *Alertas Ativos* e *Configurações*.
* **Área de Usuário / Logout**:
  * **Classificação**: **NÃO USADO**. O Orquestrador Local é um utilitário local de usuário único rodando no macOS. Não há conceito de login/logout ou sessões de usuário na nuvem. A ação de saída é o comando nativo **Sair do Aplicativo** (`Cmd+Q`).
* **Bottom Navigation Bar e Drawer Mobile (<= 900px)**:
  * **Classificação**: **NÃO USADO**. Orquestrador Local é exclusivamente um utilitário desktop macOS. Não há versão web responsiva para smartphone.

---

### 1.4 `frontend/src/components/icons/AppIcons.jsx` (Linguagem de Ícones SVG)
* **Estilo Visual e Traço**:
  * `stroke="currentColor"`, `strokeWidth={1.75}`, `strokeLinecap="round"`, `strokeLinejoin="round"`, `viewBox="0 0 24 24"`.
  * **Classificação**: **ADOTADO**. O estilo linear, consistente, com espessura de traço uniforme e terminações arredondadas foi adotado integralmente nos ícones originais em SVG.
* **Ícones de Utilidade Básica**:
  * `IconCheck`, `IconAlertCircle`, `IconSpinner`, `IconRefresh`, `IconInfo`, `IconServer`, `IconSettings`.
  * **Classificação**: **ADAPTADO**. Utilizados como base para estados de prontidão, alertas, carregamento e metadados de processo, com mapeamento direto para símbolos correspondentes do SF Symbols no ecossistema Apple.
* **Ícones Financeiros / Pessoais**:
  * `IconBank`, `IconExpense`, `IconIncome`, `IconCard`, `IconFamily`, `IconPluggy`, `categoryIconMap` (10 categorias de despesas).
  * **Classificação**: **NÃO USADO**. Totalmente estranhos ao domínio de orquestração de processos e serviços locais.

---

## 2. Síntese Comparativa

| Dimensão | CasaCapital MVP | Orquestrador Local | Status |
|---|---|---|---|
| **Ambiente de Destino** | Web responsiva (React + Vite + CSS) | Desktop nativo macOS (Swift / SwiftUI) | **ADAPTADO** |
| **Paleta Primária** | Navy `#0f172a` / Dourado `#d97706` / Verde `#059669` | Navy `#0f172a` / Dourado `#d97706` / Verde `#059669` | **ADOTADO** |
| **Modo Escuro** | Não documentado no MVP web | Suporte obrigatório de 1ª classe via Cores Semânticas | **ADAPTADO** |
| **Tipografia** | Outfit (títulos) + Plus Jakarta Sans (corpo) | SF Pro (Display, Text, Rounded para dados, Mono para portas/pids) | **ADAPTADO** |
| **Raio de Cantos** | 8px / 12px / 20px | 8px / 12px / 20px (SwiftUI Continuous Corners) | **ADOTADO** |
| **Ícones** | SVGs customizados com traço 1.75px | SVGs vetoriais dedicados + Mapeamento formal SF Symbols | **ADAPTADO** |
| **Uso de Emojis** | Proibido expressamente | Proibido expressamente | **ADOTADO** |
| **Identidade de Marca** | Casa + Colunas + Esfera | Nó de Orquestração com loop de supervisão (sem casa) | **NOVA MARCA** |
| **Navegação** | Sidebar fixa desktop + Bottom nav mobile | Split View nativa macOS + Menu-bar Popover | **ADAPTADO** |
| **Ações Centrais** | Lançar receita/despesa, sincronizar banco | **Iniciar**, **Parar**, **Abrir**, **Detalhes** | **NOVO ESCOPO** |
| **Selo de Simulação** | `DevMockNotice` | Selo e Watermark **CONCEITO / DADOS SINTÉTICOS** | **ADOTADO** |
