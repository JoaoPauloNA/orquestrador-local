import Foundation

/// Nível de pressão de memória do sistema macOS (estimada via ocupação de páginas ativas/wired/comprimidas)
public enum MemoryPressureLevel: String, Codable, Sendable {
    case normal
    case warning
    case critical
    case unknown
}

/// Nível térmico do hardware Apple Silicon / macOS
public enum ThermalLevel: String, Codable, Sendable {
    case nominal
    case fair
    case serious
    case critical
    case unknown
}

/// Snapshot imutável de telemetria de recursos do sistema
public struct SystemResourceSnapshot: Sendable, Codable {
    public let timestamp: Date
    public let totalRAMBytes: UInt64?
    public let freeRAMBytes: UInt64?
    public let usedRAMBytes: UInt64?
    public let memoryPressure: MemoryPressureLevel
    
    public let totalSwapBytes: UInt64?
    public let usedSwapBytes: UInt64?
    public let freeSwapBytes: UInt64?
    public let swapDeltaBytes: Int64?
    
    public let cpuUsagePercent: Double?
    public let thermalLevel: ThermalLevel
    public let isThrottled: Bool?
    
    public init(
        timestamp: Date = Date(),
        totalRAMBytes: UInt64?,
        freeRAMBytes: UInt64?,
        usedRAMBytes: UInt64?,
        memoryPressure: MemoryPressureLevel,
        totalSwapBytes: UInt64?,
        usedSwapBytes: UInt64?,
        freeSwapBytes: UInt64?,
        swapDeltaBytes: Int64?,
        cpuUsagePercent: Double?,
        thermalLevel: ThermalLevel,
        isThrottled: Bool?
    ) {
        self.timestamp = timestamp
        self.totalRAMBytes = totalRAMBytes
        self.freeRAMBytes = freeRAMBytes
        self.usedRAMBytes = usedRAMBytes
        self.memoryPressure = memoryPressure
        self.totalSwapBytes = totalSwapBytes
        self.usedSwapBytes = usedSwapBytes
        self.freeSwapBytes = freeSwapBytes
        self.swapDeltaBytes = swapDeltaBytes
        self.cpuUsagePercent = cpuUsagePercent
        self.thermalLevel = thermalLevel
        self.isThrottled = isThrottled
    }
    
    public var formattedRAMUsed: String {
        guard let used = usedRAMBytes, let total = totalRAMBytes, total > 0 else {
            return "Indisponível"
        }
        let gb = Double(used) / Double(1024 * 1024 * 1024)
        let totalGb = Double(total) / Double(1024 * 1024 * 1024)
        return String(format: "%.1f GB / %.1f GB", gb, totalGb)
    }
    
    public var formattedSwapUsed: String {
        guard let used = usedSwapBytes, let total = totalSwapBytes, total > 0 else {
            return "Indisponível"
        }
        let gb = Double(used) / Double(1024 * 1024 * 1024)
        let totalGb = Double(total) / Double(1024 * 1024 * 1024)
        return String(format: "%.1f GB / %.1f GB", gb, totalGb)
    }
    
    public var formattedSwapDelta: String {
        guard let delta = swapDeltaBytes else {
            return "N/D"
        }
        let mb = Double(delta) / Double(1024 * 1024)
        if mb >= 0 {
            return String(format: "+%.1f MB", mb)
        } else {
            return String(format: "%.1f MB", mb)
        }
    }
}
