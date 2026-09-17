import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject var coordinator: OrchestrationCoordinator
    @State private var selectedServiceId: UUID?
    @State private var showRegistration = false

    var body: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            detailContent
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showRegistration = true
                } label: {
                    Label("Adicionar Serviço", systemImage: "plus")
                }
                .accessibilityLabel("Adicionar novo serviço ao catálogo")
                .help("Adicionar Serviço (⌘N)")
                .keyboardShortcut("n", modifiers: .command)
            }
            if !coordinator.services.contains(where: { $0.profile.label == OrchestrationCoordinator.localTranscriberLabel }) {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            do {
                                try await coordinator.registerLocalTranscriber()
                            } catch {
                                coordinator.reportCatalogError(error.localizedDescription)
                            }
                        }
                    } label: {
                        Label("Adicionar LocalTranscriber", systemImage: "waveform.and.mic")
                    }
                    .accessibilityLabel("Adicionar LocalTranscriber")
                    .help("Adicionar o serviço privado de transcrição local")
                }
            }
            ToolbarItem {
                Button {
                    Task { await coordinator.reconcileAll() }
                } label: {
                    Label("Verificar todos", systemImage: "arrow.clockwise")
                }
                .accessibilityLabel("Verificar estado de todos os serviços")
                .help("Verificar estado (⌘R)")
                .keyboardShortcut("r", modifiers: .command)
            }
        }
        .sheet(isPresented: $showRegistration) {
            RegistrationView()
                .environmentObject(coordinator)
        }
        .alert("Erro no catálogo", isPresented: .constant(coordinator.catalogError != nil)) {
            Button("OK") {}
        } message: {
            Text(coordinator.catalogError ?? "")
        }
    }

    // MARK: - Sidebar

    private var sidebarContent: some View {
        Group {
            if coordinator.services.isEmpty {
                EmptyStateView { showRegistration = true }
            } else {
                List(coordinator.services, selection: $selectedServiceId) { runtime in
                    ServiceCardView(
                        runtime: runtime,
                        isSelected: selectedServiceId == runtime.id
                    )
                    .tag(runtime.id)
                    .padding(.vertical, 2)
                }
                .listStyle(.sidebar)
                .navigationTitle("Orquestrador Local")
                .navigationSubtitle(subtitle)
            }
        }
    }

    private var subtitle: String {
        let ready = coordinator.services.filter { $0.lifecycleState == .ready }.count
        if ready == 0 { return "Nenhum serviço pronto" }
        if ready == 1 { return "1 serviço pronto" }
        return "\(ready) serviços prontos"
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailContent: some View {
        if let id = selectedServiceId,
           let runtime = coordinator.services.first(where: { $0.id == id }) {
            ServiceDetailView(runtime: runtime)
                .environmentObject(coordinator)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text("Selecione um serviço")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
