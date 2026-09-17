import SwiftUI

/// Painel de Diagnóstico e Visualização de Recursos do Resource Guard
public struct ResourceDiagnosticsView: View {
    @ObservedObject var resourceGuard: ResourceGuardCoordinator
    
    public init(resourceGuard: ResourceGuardCoordinator) {
        self.resourceGuard = resourceGuard
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                        .font(.title2)
                        .foregroundColor(Color("accentNavy"))
                    Text("Resource Guard — Diagnóstico de Sistema")
                        .font(.headline)
                    Spacer()
                    
                    Picker("Modo", selection: Binding(
                        get: { resourceGuard.mode },
                        set: { resourceGuard.setMode($0) }
                    )) {
                        Text("Observador").tag(ResourceGuardMode.observing)
                        Text("Admissão Ativa").tag(ResourceGuardMode.activeAdmission)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }
                .padding(.bottom, 8)
                
                Divider()
                
                // Cards de Telemetria
                if let snap = resourceGuard.currentSnapshot {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        metricCard(
                            title: "Memória RAM",
                            value: snap.formattedRAMUsed,
                            subvalue: "Pressão: \(snap.memoryPressure.rawValue.uppercased())",
                            systemIcon: "memorychip",
                            statusColor: colorForPressure(snap.memoryPressure)
                        )
                        
                        metricCard(
                            title: "Espaço Swap",
                            value: snap.formattedSwapUsed,
                            subvalue: "Delta: \(snap.formattedSwapDelta)",
                            systemIcon: "externaldrive",
                            statusColor: Color.secondary
                        )
                        
                        metricCard(
                            title: "Estado Térmico",
                            value: snap.thermalLevel.rawValue.capitalized,
                            subvalue: snap.isThrottled ? "Throttling Ativo" : "Nominal",
                            systemIcon: "thermometer.medium",
                            statusColor: snap.isThrottled ? Color.red : Color.green
                        )
                        
                        metricCard(
                            title: "Última Decisão",
                            value: resourceGuard.lastDecision,
                            subvalue: "Modo: \(resourceGuard.mode.rawValue)",
                            systemIcon: "shield.checkerboard",
                            statusColor: Color("accentNavy")
                        )
                    }
                } else {
                    Text("Coletando telemetria inicial...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                // Seção de Jobs Pesados Ativos
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Jobs Pesados em Andamento (\(resourceGuard.activeJobs.count))")
                            .font(.headline)
                        Spacer()
                    }
                    
                    if resourceGuard.activeJobs.isEmpty {
                        Text("Nenhum job pesado cadastrado em execução.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(resourceGuard.activeJobs) { job in
                            HStack {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading) {
                                    Text(job.description)
                                        .font(.callout)
                                        .bold()
                                    Text("\(job.serviceLabel) • \(job.kind.rawValue)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(8)
                            .background(Color("cardSurfaceSecondary"))
                            .cornerRadius(8)
                        }
                    }
                }
                
                // Seção de Leases de Manutenção
                VStack(alignment: .leading, spacing: 8) {
                    Text("Leases de Manutenção Ativas (\(resourceGuard.activeLeases.count))")
                        .font(.headline)
                    
                    if resourceGuard.activeLeases.isEmpty {
                        Text("Nenhuma restrição de manutenção ativa no momento.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(resourceGuard.activeLeases) { lease in
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading) {
                                    Text(lease.reason)
                                        .font(.callout)
                                    Text("Dono: \(lease.owner) • Expira em: \(lease.expiresAt.formatted(date: .omitted, time: .standard))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(8)
                            .background(Color("cardSurfaceSecondary"))
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .padding(16)
        }
    }
    
    private func metricCard(title: String, value: String, subvalue: String, systemIcon: String, statusColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: systemIcon)
                    .foregroundColor(statusColor)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            Text(value)
                .font(.headline)
                .lineLimit(1)
            Text(subvalue)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color("cardSurfaceSecondary"))
        .cornerRadius(10)
    }
    
    private func colorForPressure(_ p: MemoryPressureLevel) -> Color {
        switch p {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        case .unknown: return .secondary
        }
    }
}
