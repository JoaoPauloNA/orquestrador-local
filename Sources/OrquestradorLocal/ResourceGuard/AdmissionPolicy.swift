import Foundation

/// Decisão tomada pela política de admissão
public enum AdmissionDecision: Sendable, Equatable {
    case admit(reason: String)
    case queue(reason: String)
    case deferMaintenance(reason: String)
    case unknown(reason: String)
}

/// Configuração de limites da Política de Admissão
public struct AdmissionConfig: Sendable, Codable {
    public var maxConcurrentHeavyJobs: Int
    public var maxSwapGrowthBytes: Int64
    public var blockOnCriticalPressure: Bool
    public var blockOnSeriousThermal: Bool
    public var blockOnUnknownMetrics: Bool
    
    public init(
        maxConcurrentHeavyJobs: Int = 2,
        maxSwapGrowthBytes: Int64 = 4 * 1024 * 1024 * 1024, // 4 GB
        blockOnCriticalPressure: Bool = true,
        blockOnSeriousThermal: Bool = true,
        blockOnUnknownMetrics: Bool = true
    ) {
        self.maxConcurrentHeavyJobs = maxConcurrentHeavyJobs
        self.maxSwapGrowthBytes = maxSwapGrowthBytes
        self.blockOnCriticalPressure = blockOnCriticalPressure
        self.blockOnSeriousThermal = blockOnSeriousThermal
        self.blockOnUnknownMetrics = blockOnUnknownMetrics
    }
}

/// Avaliador da Política de Admissão de Carga
public struct AdmissionPolicy: Sendable {
    public let config: AdmissionConfig
    
    public init(config: AdmissionConfig = AdmissionConfig()) {
        self.config = config
    }
    
    public func evaluate(
        snapshot: SystemResourceSnapshot?,
        activeJobCount: Int,
        isMaintenanceTask: Bool = false,
        hasMaintenanceLease: Bool = false
    ) -> AdmissionDecision {
        // Se for tarefa de manutenção e houver lease ativo
        if isMaintenanceTask && hasMaintenanceLease {
            return .deferMaintenance(reason: "Manutenção adiada: há jobs ativos retendo Lease de execução.")
        }
        
        guard let snapshot else {
            return .unknown(reason: "Métricas de recursos do sistema não disponíveis para avaliação.")
        }
        
        // 1. Verificação de Métricas Desconhecidas
        if config.blockOnUnknownMetrics && (snapshot.memoryPressure == .unknown || snapshot.usedRAMBytes == nil) {
            return .unknown(reason: "Métricas de memória do sistema indisponíveis. Início automático prevenido por segurança.")
        }
        
        // 2. Verificação de Pressão de Memória
        if config.blockOnCriticalPressure && snapshot.memoryPressure == .critical {
            return .queue(reason: "Pressão de memória estimada em estado CRÍTICO. Carga enfileirada para prevenir OOM.")
        }
        
        // 3. Verificação de Térmica (apenas quando realmente medido em serious ou critical)
        if config.blockOnSeriousThermal && (snapshot.thermalLevel == .serious || snapshot.thermalLevel == .critical) {
            return .queue(reason: "Nível térmico do sistema elevado (\(snapshot.thermalLevel.rawValue)). Carga postergada.")
        }
        
        // 4. Verificação de Jobs Pesados Concorrentes
        if activeJobCount >= config.maxConcurrentHeavyJobs {
            return .queue(reason: "Limite de jobs pesados concorrentes atingido (\(activeJobCount)/\(config.maxConcurrentHeavyJobs)).")
        }
        
        // 5. Verificação de Delta de Swap excessivo
        if let delta = snapshot.swapDeltaBytes, delta > config.maxSwapGrowthBytes {
            return .queue(reason: "Crescimento de swap excessivo nesta janela (\(snapshot.formattedSwapDelta)).")
        }
        
        return .admit(reason: "Recursos adequados para admissão da carga.")
    }
}
