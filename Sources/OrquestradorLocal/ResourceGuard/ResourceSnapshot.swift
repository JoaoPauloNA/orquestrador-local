import Foundation

/// Nível de pressão de memória do sistema macOS
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
    public let totalRAMBytes: UInt64
    public let freeRAMBytes: UInt64
    public let usedRAMBytes: UInt64
    public let memoryPressure: MemoryPressureLevel
    
    public let totalSwapBytes: UInt64
    public let usedSwapBytes: UInt64
    public let freeSwapBytes: UInt64
    public let swapDeltaBytes: Int64
    
    public let cpuUsagePercent: Double?
    public let thermalLevel: ThermalLevel
    public let isThrottled: Bool
    
    public init(
        timestamp: Date = Date(),
        totalRAMBytes: UInt64,
        freeRAMBytes: UInt64,
        usedRAMBytes: UInt64,
        memoryPressure: MemoryPressureLevel,
        totalSwapBytes: UInt64,
        usedSwapBytes: UInt64,
        freeSwapBytes: UInt64,
        swapDeltaBytes: Int64,
        cpuUsagePercent: Double?,
        thermalLevel: ThermalLevel,
        isThrottled: Bool
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
        let gb = Double(usedRAMBytes) / Double(1024 * 1024 * 1024)
        let totalGb = Double(totalRAMBytes) / Double(1024 * 1024 * 1024)
        return String(format: "%.1f GB / %.1f GB", gb, totalGb)
    }
    
    public var formattedSwapUsed: String {
        let gb = Double(usedSwapBytes) / Double(1024 * 1024 * 1024)
        let totalGb = Double(totalSwapBytes) / Double(1024 * 1024 * 1024)
        return String(format: "%.1f GB / %.1f GB", gb, totalGb)
    }
    
    public var formattedSwapDelta: String {
        let mb = Double(swapDeltaBytes) / Double(1024 * 1024)
        if mb >= 0 {
            return String(format: "+%.1f MB", mb)
        } else {
            return String(format: "%.1f MB", mb)
        }
    }
}
