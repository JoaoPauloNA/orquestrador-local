import SwiftUI

struct EmptyStateView: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Nenhum serviço cadastrado")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("Adicione um serviço para começar a orquestrar.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Adicionar Serviço") {
                onAdd()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("n", modifiers: .command)
            .accessibilityLabel("Adicionar novo serviço ao catálogo")
        }
        .frame(maxWidth: 300)
        .padding(32)
    }
}
