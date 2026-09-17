import SwiftUI

/// Detail panel. Stop confirmation for unknown activity uses a checkbox
/// that starts UNCHECKED; the Stop button remains disabled until checked.
/// Changing the checkbox state NEVER triggers SIGTERM or any service action.
struct ServiceDetailView: View {
    @ObservedObject var runtime: ServiceRuntime
    @EnvironmentObject var coordinator: OrchestrationCoordinator

    @State private var unknownActivityConfirmed = false
    @State private var showRemoveConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                actionsSection
                unknownActivityStopSection
                activitySection
                quotaSection
                processSection
                eventsSection
            }
            .padding(16)
        }
        .navigationTitle(runtime.profile.name)
        .onChange(of: runtime.id) { _, _ in
            unknownActivityConfirmed = false
        }
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    showRemoveConfirmation = true
                } label: {
                    Label("Remover cadastro", systemImage: "trash")
                }
                .accessibilityLabel("Remover \(runtime.profile.name) do catálogo")
                .help("Remove apenas o cadastro — o serviço continua rodando")
            }
        }
        .alert("Remover \(runtime.profile.name)?", isPresented: $showRemoveConfirmation) {
            Button("Cancelar", role: .cancel) {}
            Button("Remover Cadastro", role: .destructive) {
                Task { try? await coordinator.remove(id: runtime.id) }
            }
        } message: {
            Text("Remove apenas o cadastro do painel. O serviço continuará rodando conforme seu supervisor.")
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                StateBadgeView(state: runtime.lifecycleState)
                Spacer()
                if runtime.isActionInProgress {
                    ProgressView().controlSize(.small)
                }
            }

            if !runtime.profile.description.isEmpty {
                Text(runtime.profile.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 4) {
                Image(systemName: "network")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(runtime.profile.readinessURL.absoluteString)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Text("LaunchAgent: \(runtime.profile.plistPath)")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Text("Diretório: \(runtime.profile.workingDirectory)")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            if let err = runtime.lastError {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(Color("OrqDanger"))
                        .accessibilityHidden(true)
                    Text(err)
                        .font(.caption)
                        // This is normal-size explanatory text on DangerBg, not
                        // an accent/icon.  Use the dedicated AA text token.
                        .foregroundStyle(Color("OrqDangerText"))
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color("OrqDangerBg"))
                        .stroke(Color("OrqDanger").opacity(0.3), lineWidth: 1)
                )
            }
        }
    }

    private var actionsSection: some View {
        HStack(spacing: 8) {
            // Start
            Button {
                Task { await coordinator.startService(runtime.id) }
            } label: {
                Label("Iniciar", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!runtime.lifecycleState.startEnabled || runtime.isActionInProgress)
            .accessibilityLabel("Iniciar \(runtime.profile.name)")
            .accessibilityHint("Solicita início ao supervisor e aguarda prontidão")
            .help("Iniciar serviço")
            .keyboardShortcut(.return, modifiers: .command)

            // For normal activity-supported services such as ComfyUI, retain simple Stop control here.
            if !runtime.activityState.requiresManualIdleConfirmation {
                stopButton
            }

            Button {
                Task {
                    await coordinator.restartService(
                        runtime.id,
                        userConfirmedIdle: unknownActivityConfirmed
                    )
                    unknownActivityConfirmed = false
                }
            } label: {
                Label("Reiniciar", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.bordered)
            .disabled(runtime.isActionInProgress || (!runtime.lifecycleState.startEnabled && runtime.lifecycleState != .ready))
            .accessibilityLabel("Reiniciar (runtime.profile.name)")
            .accessibilityHint("Para graciosamente e inicia novamente pelo supervisor")
            .help("Reiniciar serviço")

            // Open
            Button {
                coordinator.openService(runtime.id)
            } label: {
                Label("Abrir", systemImage: "arrow.up.right.square")
            }
            .buttonStyle(.bordered)
            .disabled(!runtime.lifecycleState.openEnabled)
            .accessibilityLabel("Abrir interface de \(runtime.profile.name)")
            .help("Abrir interface no navegador padrão")
            .keyboardShortcut("o", modifiers: .command)

            // Refresh
            Button {
                Task { await coordinator.reconcileAll(refreshQuota: true) }
            } label: {
                Label("Verificar", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(runtime.isActionInProgress)
            .accessibilityLabel("Verificar estado de \(runtime.profile.name)")
            .help("Verificar estado imediatamente")
            .keyboardShortcut("r", modifiers: .command)
        }
    }

    private var stopButton: some View {
        let isBusy = runtime.activityState.isBusy
        let canStop = runtime.lifecycleState.stopEnabled && !runtime.isActionInProgress

        return Button(role: .destructive) {
            Task {
                await coordinator.stopService(runtime.id, userConfirmedIdle: false)
                unknownActivityConfirmed = false
            }
        } label: {
            Label("Parar", systemImage: "stop.fill")
        }
        .buttonStyle(.bordered)
        .disabled(!canStop || isBusy)
        .accessibilityLabel("Parar \(runtime.profile.name)")
        .accessibilityHint(
            isBusy ? "Bloqueado — serviço ocupado" : "Encerra o serviço graciosamente"
        )
        .help(isBusy ? "Parada bloqueada: serviço com trabalho ativo" : "Parar serviço")
        .keyboardShortcut(".", modifiers: .command)
    }

    @ViewBuilder
    private var unknownActivityStopSection: some View {
        let requiresConfirmation = runtime.activityState.requiresManualIdleConfirmation
        let canStop = runtime.lifecycleState.stopEnabled && !runtime.isActionInProgress

        if requiresConfirmation && runtime.lifecycleState.stopEnabled {
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                Text(runtime.activityState == .notSupported
                     ? "Atividade não monitorada. Confirme manualmente que o serviço está ocioso antes de parar."
                     : "Atividade não verificada. Confirme manualmente que o serviço está ocioso antes de parar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle(isOn: $unknownActivityConfirmed) {
                    Text("Confirmo que o serviço está ocioso")
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
                .toggleStyle(.checkbox)
                .disabled(!canStop)
                .onChange(of: unknownActivityConfirmed) { _, _ in
                    // Intentionally empty — toggle changes only UI state, never service state
                }

                Button(role: .destructive) {
                    Task {
                        await coordinator.stopService(
                            runtime.id,
                            userConfirmedIdle: unknownActivityConfirmed
                        )
                        unknownActivityConfirmed = false
                    }
                } label: {
                    Label("Parar", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
                .disabled(!unknownActivityConfirmed || !canStop)
                .accessibilityLabel("Parar \(runtime.profile.name) com atividade não monitorada")
                .accessibilityHint("Requer confirmação manual de que o serviço está ocioso")
                .help("Parar serviço (confirmação manual necessária)")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Label("Parada exige confirmação", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color("OrqGoldAccent"))
                    .accessibilityAddTraits(.isHeader)
            }
        }
    }

    private var activityDisplayStatus: String {
        switch runtime.activityState {
        case .notSupported:
            return "Atividade não monitorada"
        case .unknown:
            return "Atividade não verificada"
        case .idle:
            return "Ocioso"
        case .busy(let r, let p):
            return "Ocupado (\(r) em execução, \(p) pendentes)"
        }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Atividade")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 6) {
                Image(systemName: activityIcon)
                    .font(.caption)
                    .foregroundStyle(activityColor)
                    .accessibilityHidden(true)
                Text(activityDisplayStatus)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }

            if runtime.profile.activityURL == nil {
                Text("Observação indisponível: o perfil não tem endpoint de atividade. Isso não significa que esteja ocioso.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if runtime.activityState == .unknown {
                Text("Sinal de atividade não pôde ser verificado. Isso não significa que esteja ocioso.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color("CardSurface"))
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }

    private var quotaSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Cota de IA")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(runtime.quotaState.displayText)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Text("Leitura local sem credenciais; ausência de endpoint não representa cota disponível.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color("CardSurface"))
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }

    private var processSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Processo e última saída")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(runtime.managedPID.map { "PID gerenciado: \($0)" } ?? "PID gerenciado: —")
                .font(.system(.caption, design: .monospaced))
            Text(runtime.lastExitStatus.map { "Último código de saída: \($0)" } ?? "Último código de saída: —")
                .font(.system(.caption, design: .monospaced))
            if let output = runtime.lastOutput {
                Text(output)
                    .font(.system(.caption2, design: .monospaced))
                    .lineLimit(5)
                    .textSelection(.enabled)
            } else {
                Text("Nenhuma saída recente capturada.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color("CardSurface"))
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }

    private var activityIcon: String {
        switch runtime.activityState {
        case .idle:         return "checkmark.circle"
        case .busy:         return "circle.fill"
        case .unknown:      return "questionmark.circle"
        case .notSupported: return "minus.circle"
        }
    }

    private var activityColor: Color {
        switch runtime.activityState {
        case .idle:         return Color("OrqGreenAccent")
        case .busy:         return Color("OrqGoldAccent")
        case .unknown:      return Color("OrqMuted")
        case .notSupported: return Color("OrqMuted")
        }
    }

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Eventos recentes")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if runtime.recentEvents.isEmpty {
                Text("Nenhum evento registrado.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(runtime.recentEvents.reversed()) { event in
                    HStack(alignment: .top, spacing: 6) {
                        Text(event.timestamp.formatted(.dateTime.hour().minute().second()))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 60, alignment: .leading)
                        Text(event.kind.rawValue)
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                            .frame(width: 80, alignment: .leading)
                        Text(event.message)
                            .font(.caption2)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color("CardSurface"))
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }
}
