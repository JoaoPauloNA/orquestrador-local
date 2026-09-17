# Pacote de Design Visual — Orquestrador Local (macOS Native)

Bem-vindo ao pacote completo de design visual do **Orquestrador Local**, desenvolvido sob a identidade institucional e tokens derivados do CasaCapital, adaptados estritamente para o ecossistema nativo macOS (Swift/SwiftUI).

---

## 1. Índice Completo de Entregáveis

| Arquivo / Diretório | Descrição Sintética |
|---|---|
| [REFERENCIA-CASACAPITAL.md](file:///Users/joaopaulo/Documents/Projetos/Pessoal/OrquestradorLocal/design/REFERENCIA-CASACAPITAL.md) | Análise comparativa linha a linha dos 5 arquivos do CasaCapital: o que foi Adotado, Adaptado ou Descartado. |
| [DESIGN-SYSTEM.md](file:///Users/joaopaulo/Documents/Projetos/Pessoal/OrquestradorLocal/design/DESIGN-SYSTEM.md) | Especificação formal dos tokens de cor (Light/Dark), tipografia SF Pro, espaçamentos, raios de borda e estados. |
| [TELAS-E-FLUXOS.md](file:///Users/joaopaulo/Documents/Projetos/Pessoal/OrquestradorLocal/design/TELAS-E-FLUXOS.md) | Documentação dos fluxos operacionais, detalhamento das 10 telas e dimensões de janelas do macOS. |
| [SWIFTUI-HANDOFF.md](file:///Users/joaopaulo/Documents/Projetos/Pessoal/OrquestradorLocal/design/SWIFTUI-HANDOFF.md) | Guia de transição para engenharia: mapeamento SwiftUI, máquina de estados `@Observable`, Assets e acessibilidade. |
| [RELATORIO-AGY.md](file:///Users/joaopaulo/Documents/Projetos/Pessoal/OrquestradorLocal/design/RELATORIO-AGY.md) | Relatório formal de entrega em exatamente 10 tópicos numerados em português com resultados de inspeção. |
| [icons/app-icon.svg](file:///Users/joaopaulo/Documents/Projetos/Pessoal/OrquestradorLocal/design/icons/app-icon.svg) | Ícone master original da aplicação em SVG (squircle macOS com nexus de orquestração). |
| [icons/app-icon-preview.png](file:///Users/joaopaulo/Documents/Projetos/Pessoal/OrquestradorLocal/design/icons/app-icon-preview.png) | Preview de alta resolução (512×512 px) renderizado nativamente para visualização rápida. |
| [icons/menubar-mark.svg](file:///Users/joaopaulo/Documents/Projetos/Pessoal/OrquestradorLocal/design/icons/menubar-mark.svg) | Marca monocromática de menu-bar (18×18 pt), otimizada para o `MenuBarExtra` do macOS. |
| [icons/action-icons.svg](file:///Users/joaopaulo/Documents/Projetos/Pessoal/OrquestradorLocal/design/icons/action-icons.svg) | Grade visual completa de ícones de ação e badges de estado (24×24 pt, traço 1.75 pt). |
| [icons/icon-notes.md](file:///Users/joaopaulo/Documents/Projetos/Pessoal/OrquestradorLocal/design/icons/icon-notes.md) | Análise de nitidez em baixa resolução, mapeamento verificado para SF Symbols e notas de acessibilidade. |
| [mockups/01-catalogo-principal.svg](file:///Users/joaopaulo/Documents/Projetos/Pessoal/OrquestradorLocal/design/mockups/01-catalogo-principal.svg) | Tela 01: Janela principal com catálogo de cards de serviços, memória estimada e ações. |
| [mockups/02-menu-bar-panel.svg](file:///Users/joaopaulo/Documents/Projetos/Pessoal/OrquestradorLocal/design/mockups/02-menu-bar-panel.svg) | Tela 02: Popover compacto da barra de menus superior do macOS com ações rápidas. |
| [mockups/03-detalhes-projeto.svg](file:///Users/joaopaulo/Documents/Projetos/Pessoal/OrquestradorLocal/design/mockups/03-detalhes-projeto.svg) | Tela 03: Detalhes do projeto com endpoints, telemetria, medidor de memória e histórico de eventos. |
| [mockups/04-cadastro-guiado.svg](file:///Users/joaopaulo/Documents/Projetos/Pessoal/OrquestradorLocal/design/mockups/04-cadastro-guiado.svg) | Tela 04: Formulário modal guiado com seleção de perfil, diretório e validação em tempo real. |
| [mockups/05-catalogo-vazio.svg](file:///Users/joaopaulo/Documents/Projetos/Pessoal/OrquestradorLocal/design/mockups/05-catalogo-vazio.svg) | Tela 05: Estado amigável de catálogo vazio com orientação de onboarding e CTA de registro. |
| [mockups/06-estados-servico.svg](file:///Users/joaopaulo/Documents/Projetos/Pessoal/OrquestradorLocal/design/mockups/06-estados-servico.svg) | Tela 06: Matriz comparativa dos 7 estados de ciclo de vida com ações autorizadas em cada um. |
| [mockups/07-parada-bloqueada.svg](file:///Users/joaopaulo/Documents/Projetos/Pessoal/OrquestradorLocal/design/mockups/07-parada-bloqueada.svg) | Tela 07: Diálogo modal de proteção contra parada acidental durante inferência ou trabalho ativo. |
| [mockups/08-atividade-desconhecida.svg](file:///Users/joaopaulo/Documents/Projetos/Pessoal/OrquestradorLocal/design/mockups/08-atividade-desconhecida.svg) | Tela 08: Diálogo de segurança para confirmação manual de ociosidade quando não há telemetria. |
| [mockups/09-conflito-porta.svg](file:///Users/joaopaulo/Documents/Projetos/Pessoal/OrquestradorLocal/design/mockups/09-conflito-porta.svg) | Tela 09: Banner informativo de colisão de porta local sem botão de força bruta (kill). |
| [mockups/10-detalhe-erro.svg](file:///Users/joaopaulo/Documents/Projetos/Pessoal/OrquestradorLocal/design/mockups/10-detalhe-erro.svg) | Tela 10: Relatório estruturado de erro com diagnóstico em linguagem clara e sugestão de correção. |

---

## 2. Como Visualizar os Mockups (Sem Servidor Web)

Todos os artefatos visuais foram gerados em **formato vetorial aberto SVG padrão W3C**, não necessitando de nenhum servidor HTTP local, Node.js ou instalação de fontes adicionais para visualização.

### Opção 1: Quick Look no macOS Finder (Recomendado)
1. Abra a pasta `design/mockups/` ou `design/icons/` no **Finder**.
2. Selecione qualquer arquivo `.svg` ou `.png`.
3. Pressione a **Barra de Espaço** do teclado. O Quick Look nativo do macOS renderizará instantaneamente a imagem em alta resolução com nitidez vetorial.

### Opção 2: Navegador Web Nativo (Safari ou Chrome)
1. Dê um duplo-clique no arquivo `.svg` ou arraste-o diretamente para uma aba aberta do **Safari** ou **Google Chrome**.
2. O arquivo será renderizado instantaneamente com as fontes de sistema SF Pro aplicadas.

### Opção 3: Aplicativo Preview (Pré-Visualização)
- No Finder, clique com o botão direito sobre qualquer mockup e selecione `Abrir Com > Pré-Visualização (Preview)`.

---

## 3. Marca d'Água de Integridade

Todos os mockups e designs de tela incluem obrigatoriamente a legenda institucional técnica:
`CONCEITO / DADOS SINTÉTICOS`
Nenhuma métrica de hardware real ou dado de conta pessoal foi inventado ou capturado.
