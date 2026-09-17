import SwiftUI

struct ServiceCardView: View {
    @ObservedObject var runtime: ServiceRuntime
    let isSelected: Bool

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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(runtime.profile.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                StateBadgeView(state: runtime.lifecycleState)
            }

            if let lastChecked = runtime.lastChecked {
                Text("Verificado: \(lastChecked.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if let err = runtime.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(Color("OrqDangerText"))
                    .lineLimit(2)
            }

            Text(activityDisplayStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text("Cota: \(runtime.quotaState.displayText)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color("CardSurface"))
                .stroke(isSelected ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(runtime.profile.name), estado \(runtime.lifecycleState.label)")
        .accessibilityValue(runtime.lastError ?? "\(activityDisplayStatus). Cota: \(runtime.quotaState.displayText)")
    }
}
