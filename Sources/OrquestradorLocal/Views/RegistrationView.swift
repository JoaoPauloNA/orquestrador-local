import SwiftUI

/// Guided registration form. No free-form shell field.
/// Uses ProfileValidator before creating the profile.
struct RegistrationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var coordinator: OrchestrationCoordinator

    @State private var input = ProfileValidator.RawInput()
    @State private var validationError: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Identificação") {
                    LabeledContent("Nome") {
                        TextField("ex.: mflux-studio", text: $input.name)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Nome do serviço")
                    }
                    LabeledContent("Descrição") {
                        TextField("Breve descrição opcional", text: $input.description)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Descrição do serviço")
                    }
                }

                Section("LaunchAgent") {
                    Picker("Domínio", selection: $input.launchdDomain) {
                        Text("Sessão gráfica (gui)").tag(LaunchdDomain.gui)
                        Text("Usuário (user)").tag(LaunchdDomain.user)
                    }
                    .help("LaunchAgents comuns são registrados no domínio gui do usuário.")
                    LabeledContent("Label") {
                        TextField("com.exemplo.servico", text: $input.label)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .accessibilityLabel("Label do LaunchAgent")
                            .help("Label exata registrada no launchctl (ex.: com.joaopaulo.mflux-studio)")
                    }
                    LabeledContent("Plist") {
                        TextField("/Users/…/Library/LaunchAgents/…plist", text: $input.plistPath)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.caption, design: .monospaced))
                            .accessibilityLabel("Caminho absoluto do arquivo plist")
                    }
                    LabeledContent("Executável") {
                        TextField("/caminho/absoluto/para/executável", text: $input.executablePath)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.caption, design: .monospaced))
                            .accessibilityLabel("Caminho absoluto do executável principal")
                    }
                    LabeledContent("Diretório") {
                        TextField("/caminho/do/projeto", text: $input.workingDirectory)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.caption, design: .monospaced))
                            .accessibilityLabel("Diretório de trabalho")
                    }
                }

                Section("Endpoints (loopback 127.0.0.1)") {
                    LabeledContent("Prontidão") {
                        TextField("http://127.0.0.1:8765/", text: $input.readinessURLString)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .accessibilityLabel("URL de verificação de prontidão")
                    }
                    Picker("Prova de identidade", selection: $input.readinessIdentityKind) {
                        ForEach(ProfileValidator.ReadinessIdentityKind.allCases) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    LabeledContent("Identidade esperada") {
                        TextField("ex.: mflux ou system", text: $input.readinessIdentityValue)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Marcador obrigatório de identidade na resposta")
                            .help("Prontidão exige 2xx e este marcador específico; porta aberta não basta.")
                    }
                    LabeledContent("Atividade (opcional)") {
                        TextField("http://127.0.0.1:8765/queue (vazio = não suportado)", text: $input.activityURLString)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .accessibilityLabel("URL de verificação de atividade — deixe vazio se não suportado")
                            .help("Deve retornar JSON com queue_running e queue_pending. Deixe vazio se o serviço não suporta.")
                    }
                    LabeledContent("Abrir") {
                        TextField("http://127.0.0.1:8765/", text: $input.openURLString)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .accessibilityLabel("URL a abrir no navegador quando pronto")
                    }
                }

                Section("Tempos limite") {
                    LabeledContent("Prontidão (s)") {
                        Stepper("\(input.readinessTimeoutSeconds) segundos",
                                value: $input.readinessTimeoutSeconds, in: 5...600, step: 10)
                    }
                    LabeledContent("Parada (s)") {
                        Stepper("\(input.stopTimeoutSeconds) segundos",
                                value: $input.stopTimeoutSeconds, in: 5...300, step: 5)
                    }
                }

                if let err = validationError {
                    Section {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(Color("OrqDangerText"))
                                .accessibilityHidden(true)
                            Text(err)
                                .foregroundStyle(Color("OrqDangerText"))
                                .font(.subheadline)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Adicionar Serviço")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .keyboardShortcut(.escape, modifiers: [])
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        Task { await save() }
                    }
                    .disabled(isSaving || !quickValidation)
                    .keyboardShortcut(.return, modifiers: .command)
                    .accessibilityLabel("Salvar perfil de serviço")
                }
            }
        }
        .frame(minWidth: 520, minHeight: 540)
    }

    private var quickValidation: Bool {
        !input.name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !input.label.trimmingCharacters(in: .whitespaces).isEmpty &&
        !input.plistPath.trimmingCharacters(in: .whitespaces).isEmpty &&
        !input.executablePath.trimmingCharacters(in: .whitespaces).isEmpty &&
        !input.workingDirectory.trimmingCharacters(in: .whitespaces).isEmpty &&
        !input.readinessURLString.trimmingCharacters(in: .whitespaces).isEmpty &&
        !input.readinessIdentityValue.trimmingCharacters(in: .whitespaces).isEmpty &&
        !input.openURLString.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save() async {
        isSaving = true
        validationError = nil
        do {
            try await coordinator.register(input: input)
            dismiss()
        } catch {
            validationError = error.localizedDescription
        }
        isSaving = false
    }
}
