import SwiftUI

struct MenuBarPopoverView: View {
    @EnvironmentObject var coordinator: OrchestrationCoordinator
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Orquestrador Local")
                    .font(.headline)
                Spacer()
                Text(readySummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            if coordinator.services.isEmpty {
                Text("Nenhum serviço cadastrado")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(12)
            } else {
                ForEach(coordinator.services) { runtime in
                    menuBarRow(runtime)
                }
            }

            Divider()

            // Footer actions
            HStack {
                Button("Painel") {
                    openWindow(id: "main-window")
                }
                .buttonStyle(.plain)
                .font(.subheadline)
                .accessibilityLabel("Abrir painel principal")

                Spacer()

                Button("Verificar") {
                    Task { await coordinator.reconcileAll() }
                }
                .buttonStyle(.plain)
                .font(.subheadline)
                .accessibilityLabel("Verificar estado de todos os serviços")

                Spacer()

                Button("Sair") {
                    // Quit does NOT stop services — they continue under their supervisors
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.subheadline)
                .foregroundStyle(Color("OrqDangerText"))
                .accessibilityLabel("Sair do Orquestrador Local — os serviços continuarão rodando")
                .help("Sair não para os serviços. Eles continuam sob seus supervisores.")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 280)
    }

    private func menuBarRow(_ runtime: ServiceRuntime) -> some View {
        HStack(spacing: 8) {
            Image(systemName: runtime.lifecycleState.sfSymbol)
                .font(.caption)
                .foregroundStyle(stateColor(runtime.lifecycleState))
                .frame(width: 16)
                .accessibilityHidden(true)
            Text(runtime.profile.name)
                .font(.subheadline)
                .lineLimit(1)
            Spacer()
            Text(runtime.lifecycleState.label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(runtime.profile.name): \(runtime.lifecycleState.label)")
    }

    private var readySummary: String {
        let ready = coordinator.services.filter { $0.lifecycleState == .ready }.count
        let total = coordinator.services.count
        return "\(ready)/\(total) prontos"
    }

    private func stateColor(_ state: ServiceLifecycleState) -> Color {
        switch state {
        case .ready:    return Color("OrqGreenAccent")
        case .starting, .stopping: return Color("OrqGoldAccent")
        case .stopped:  return Color("OrqMuted")
        case .error:    return Color("OrqDanger")
        case .external: return Color("OrqExternal")
        case .unknown:  return Color("OrqMuted")
        }
    }
}
