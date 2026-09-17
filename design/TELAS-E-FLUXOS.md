# Telas, Fluxos e Composição — Orquestrador Local

Este documento detalha a arquitetura de informação, a estrutura de janelas, a composição de cada uma das 10 telas/estados do sistema e os fluxos de usuário do **Orquestrador Local**.

---

## 1. Composição de Janelas e Dimensões

O aplicativo opera sob um modelo duplo:
1. **Janela Principal de Gerenciamento (`MainWindow`)**: Baseada em `NavigationSplitView` no macOS com suporte a redimensionamento suave.
2. **Painel da Barra de Menus (`MenuBarExtraPopover`)**: Menu-bar popover compacto para monitoramento e ações rápidas.

### 1.1 Especificações Dimensionais

| Janela / Painel | Largura (Width) | Altura (Height) | Comportamento de Redimensionamento |
|---|---|---|---|
| **Janela Principal (Total)** | Padrão: `860pt` (Mín: `720pt`, Máx: `1440pt`) | Padrão: `580pt` (Mín: `480pt`, Máx: `900pt`) | Redimensionável com proporção livre |
| **Sidebar da Janela Principal** | Padrão: `240pt` (Mín: `220pt`, Máx: `280pt`) | `100%` da janela | Sidebar padrão NavigationSplitView do macOS |
| **Área Central / Catálogo** | Flexível (restante da largura) | `100%` da janela | Rolagem vertical fluida |
| **Painel de Detalhes** | Flexível / SplitView detail | `100%` da janela | Exibido no detalhe da NavigationSplitView |
| **Painel Menu-Bar (Popover)** | Fixo: `280pt` | Auto conforme serviços | Posicionamento ancorado ao ícone da bandeja |
| **Diálogos Modais (ex: Cadastro)**| Mín: `520pt` | Mín: `540pt` | Sheet modal centrado sobre a janela principal |

---

## 2. Detalhamento das Telas e Estados

### Tela 01: Catálogo Principal (`01-catalogo-principal.svg`)
* **Objetivo**: Visão executiva de todos os projetos/serviços locais registrados no orquestrador.
* **Componentes Principais**:
  - Barra de Ferramentas superior: Título "Orquestrador Local", subtítulo de contagem de prontos, botão "Adicionar Serviço" (Cmd+N), botão "Verificar todos" (Cmd+R).
  - Cartões de Serviço na sidebar:
    - Identificação do projeto (ex: `mflux-studio`, `ComfyUI`).
    - Badge de estado com ícone e cor semântica auditada (ex: `Pronto`, `Parado`).
    - Timestamp de verificação recente (ex: `Verificado há 12s`).
    - Mensagem de erro explícita se houver falha recente.
    - Indicador de estado de atividade operacional (ex: `Ocioso`, `Ocupado`, `Atividade não verificada`).
  - Tarja de rodapé ou metadado com dados sintéticos quando em demonstração.
* **Interações**:
  - Clique no card seleciona o projeto e abre o painel de detalhes.
  - Clique direto em "Iniciar" dispara o ciclo de supervisão.
  - Clique em "Abrir" lança a URL no Safari/navegador padrão.
* **Casos de Borda**: Mais de 10 serviços registrados (ativa scroll suave preservando o cabeçalho fixo).

---

### Tela 02: Painel Menu-Bar Popover (`02-menu-bar-panel.svg`)
* **Objetivo**: Acesso rápido a partir de qualquer espaço de trabalho sem trazer a janela principal para primeiro plano.
* **Componentes Principais**:
  - Cabeçalho do Popover: Logomarca compacta, título "Orquestrador Local", contador de serviços ativos (ex: `1 em execução · 1 parado`).
  - Lista de itens compacta: Nome do serviço, ponto luminoso de estado com label de acessibilidade, botão de ação rápida (Iniciar / Parar / Abrir).
  - Rodapé com separador sutil: Botão "Abrir Painel Completo" e "Sair" (`Cmd+Q`).
  - Watermark sintético em rodapé.
* **Interações**:
  - Clique fora fecha o popover automaticamente.
  - Tecla `Esc` fecha o popover.

---

### Tela 03: Detalhes do Projeto (`03-detalhes-projeto.svg`)
* **Objetivo**: Diagnóstico aprofundado de um serviço específico.
* **Componentes Principais**:
  - Cabeçalho com nome, caminho no disco (`~/Projetos/mflux-studio`), supervisor associado (`LaunchAgent: local.mflux-studio.plist`).
  - Bloco de Prontidão: Endpoint de healthcheck (`http://127.0.0.1:8080/health`), status HTTP 200 OK, tempo de resposta (42ms).
  - Status de Atividade: "Ocioso", "Ocupado (fila de jobs)" ou "Atividade não verificada" (com salvaguarda explícita de que ausência de observação não implica ocioso).
  - Histórico Recente de Eventos (máximo 5 eventos): data/hora, tipo de transição de estado, mensagem descritiva.
  - Ações contextuais: Iniciar (Cmd+Return), Parar (com confirmação checkbox desmarcada se atividade desconhecida), Abrir (Cmd+O), Verificar (Cmd+R).

---

### Tela 04: Cadastro Guiado de Serviço (`04-cadastro-guiado.svg`)
* **Objetivo**: Registro seguro de um novo serviço sem necessidade de shell livre, com validação rígida via `ProfileValidator`.
* **Componentes Principais**:
  - Seções agrupadas: Identificação (Nome, Descrição), LaunchAgent (domínio gui/user, Label, Plist, Executável, Diretório de trabalho), Endpoints loopback 127.0.0.1 (Prontidão, Prova de identidade, Marcador esperado, Atividade opcional, Abrir) e Tempos Limite (Prontidão e Parada).
  - Validação em tempo real: checagem de caminhos absolutos existentes, loopback estrito, sem injeção de shell ou path traversal.
  - Exibição de mensagem de erro com ícone de alerta e token `OrqDangerText`.
  - Botões de rodapé: "Cancelar" (Esc) e "Salvar" (Cmd+Return), com desativação automática enquanto campos obrigatórios estiverem vazios.

---

### Tela 05: Catálogo Vazio (`05-catalogo-vazio.svg`)
* **Objetivo**: Boas-vindas na primeira inicialização, orientando o usuário a dar o primeiro passo sem sensação de erro.
* **Componentes Principais**:
  - Ilustração vetorial limpa com estilo do design system (círculos concêntricos e símbolo de adição).
  - Título acolhedor: "Nenhum serviço configurado".
  - Texto de apoio: "O Orquestrador Local gerencia seus serviços de IA e servidores locais com controle de inicialização, observação de saúde e encerramento seguro."
  - Botão de ação primária destacado: "Cadastrar Primeiro Serviço" (ícone + texto).
  - Botão secundário de apoio: "Consultar Documentação".
  - Tarja com dados sintéticos informando modo de demonstração disponível.

---

### Tela 06: Matriz de Estados de Serviço (`06-estados-servico.svg`)
* **Objetivo**: Exibição padronizada dos 7 estados operacionais que um serviço pode assumir, permitindo validação visual instantânea da coerência cromática e tipográfica.
* **Estados Representados em Grade**:
  1. **Iniciando**: Dourado `#d97706`, ícone spinner/loading, descrição de aguardo de porta.
  2. **Pronto**: Verde `#059669`, ícone checkmark, descrição de resposta HTTP 200 OK.
  3. **Parando**: Dourado `#d97706`, ícone de drenagem, descrição de envio de SIGTERM.
  4. **Parado**: Slate neutro `#64748b`, ícone quadrado, portas liberadas.
  5. **Erro**: Vermelho `#dc2626`, ícone de alerta, código de saída ou falha de bind.
  6. **Externo**: Azul `#0284c7`, ícone de processo desanexado, supervisão ativa somente-leitura.
  7. **Desconhecido**: Cinza suave `#94a3b8`, ícone tilde/interrogação, ausência de telemetria.

---

### Tela 07: Parada Bloqueada por Trabalho Ativo (`07-parada-bloqueada.svg`)
* **Objetivo**: Proteger o usuário contra perda de dados ou interrupção acidental de tarefas de computação em andamento (ex: geração de imagem no mflux-studio ou inferência no ComfyUI).
* **Componentes Principais**:
  - Banner ou Diálogo modal não destrutivo com faixa de alerta em Dourado (`#d97706`).
  - Título explicativo: "Não é possível parar 'mflux-studio' agora".
  - Detalhe da atividade: "O serviço está processando um lote de inferência (Tarefa #4829, passo 18/25). Interromper agora causará perda do progresso não salvo."
  - Botão primário: "Aguardar Conclusão" (foco padrão).
  - Botão de apoio: "Abrir Interface para Acompanhar".
  - **Restrição de Projeto**: Nenhum botão "Forçar Parada" é exibido.

---

### Tela 08: Atividade Desconhecida (`08-atividade-desconhecida.svg`)
* **Objetivo**: Esclarecer honestamente que o serviço está no ar, mas a aplicação não tem como saber se há requisições ou cálculos ativos.
* **Componentes Principais**:
  - Painel de advertência amigável em tom neutro/âmbar.
  - Mensagem textual explícita: "Não foi possível confirmar se há tarefas ativas em execução neste serviço, pois ele não expõe métricas de atividade em tempo real."
  - Checklist visual de confirmação do operador: "Verifique visualmente se a interface web concluiu as tarefas antes de solicitar a parada."
  - Checkbox de confirmação explícita: "[ ] Confirmo que o serviço está ocioso e pode ser encerrado com segurança."
  - Ação "Parar Serviço" só habilita após a checagem manual.

---

### Tela 09: Conflito de Porta (`09-conflito-porta.svg`)
* **Objetivo**: Informar que a porta necessária já está ocupada por outro processo antes de falhar a inicialização.
* **Componentes Principais**:
  - Banner de erro informativo com fundo `#fef2f2` e borda `#fca5a5`.
  - Mensagem clara: "Falha ao iniciar: A porta local 8080 já está em uso."
  - Detalhamento informativo:
    - Porta em conflito: `8080`
    - Processo ocupante detectado: `python3 (PID 49102, usuário: joaopaulo)`
  - Orientação ao usuário: "Encerre o processo ocupante ou altere a porta configurada deste projeto nas Configurações."
  - **Restrição Crítica**: Nenhum botão de "Matar Processo" (Kill) é fornecido para evitar encerrar serviços alheios de forma perigosa.

---

### Tela 10: Detalhe de Erro (`10-detalhe-erro.svg`)
* **Objetivo**: Diagnóstico acionável de falhas de inicialização ou execução em linguagem compreensível.
* **Componentes Principais**:
  - Cartão de diagnóstico de falha com cabeçalho em vermelho `#dc2626`.
  - Resumo da falha: "O serviço terminou inesperadamente 4 segundos após iniciar."
  - Timestamp exato: `2026-09-06 às 10:01:14 BRT`.
  - Caixa de saída de erro (código mono, sintético): `Error: ModuleNotFoundError: No module named 'mflux_backend'`.
  - Bloco de Ação Sugerida em linguagem clara: "Verifique se o ambiente virtual do Python está configurado e com as dependências instaladas no diretório do projeto."
  - Botão de ação: "Reverificar Ambiente" ou "Ver Detalhes".

---

## 3. Fluxos do Usuário

### Fluxo A: Primeiro Uso (Onboarding)
1. Usuário abre o Orquestrador Local.
2. É recebido pela **Tela 05 (Catálogo Vazio)**.
3. Clica em "Cadastrar Primeiro Serviço".
4. Abre a **Tela 04 (Cadastro Guiado)**.
5. Seleciona o perfil, aponta para a pasta e confirma a porta livre.
6. Clica em "Concluir Cadastro".
7. Retorna à **Tela 01 (Catálogo Principal)** com o card cadastrado no estado `Parado`.

### Fluxo B: Uso Diário (Ciclo Iniciar → Pronto → Abrir → Parar)
1. No catálogo ou no Menu-bar, clica em **Iniciar**.
2. Estado transiciona para **Iniciando** (spinner dourado, checando healthcheck a cada 500ms).
3. Healthcheck retorna 200 OK: estado transiciona para **Pronto** (badge verde).
4. Botão **Abrir** é habilitado. Usuário clica e o Safari abre a página local.
5. Ao concluir o trabalho no Safari, o usuário clica em **Parar**.
6. O orquestrador verifica atividade ativa. Estando ocioso, envia sinal de parada suave.
7. Estado transiciona para **Parando** e em seguida para **Parado** (cinza neutro).

### Fluxo C: Recuperação de Erro
1. Usuário clica em **Iniciar** em um serviço com arquivo ausente.
2. Estado transiciona para **Erro** (badge vermelho).
3. Um aviso discreto surge no topo e o botão **Detalhes** fica em evidência.
4. Usuário clica em **Detalhes**, visualizando a **Tela 10 (Detalhe de Erro)**.
5. Corrige a causa indicada e clica em "Reverificar".
6. O estado retorna para **Parado**, apto para nova tentativa.

### Fluxo D: Detecção de Serviço Externo
1. O usuário já tem o ComfyUI rodando via terminal próprio.
2. O Orquestrador Local identifica que a porta 8188 está aberta e respondendo ao endpoint do ComfyUI.
3. Exibe o card com o badge **Gerenciado Externamente** (azul).
4. Os botões "Iniciar" e "Parar" ficam desabilitados ou exibem aviso explicativo, permitindo apenas **Abrir** e **Detalhes**.
