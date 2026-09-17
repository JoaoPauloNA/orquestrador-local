import Foundation

/// Protocolo abstrato para coleta de métricas de sistema do macOS
public protocol SystemMetricsProvider: Sendable {
    func collectMetrics() async -> (
        totalRAM: UInt64?,
        freeRAM: UInt64?,
        usedRAM: UInt64?,
        pressure: MemoryPressureLevel,
        totalSwap: UInt64?,
        usedSwap: UInt64?,
        freeSwap: UInt64?,
        cpuPercent: Double?,
        thermal: ThermalLevel,
        throttled: Bool?
    )
}

/// Provedor real de métricas via APIs do macOS / Darwin / Sysctl
public final class DarwinSystemMetricsProvider: SystemMetricsProvider, Sendable {
    public init() {}
    
    public func collectMetrics() async -> (
        totalRAM: UInt64?,
        freeRAM: UInt64?,
        usedRAM: UInt64?,
        pressure: MemoryPressureLevel,
        totalSwap: UInt64?,
        usedSwap: UInt64?,
        freeSwap: UInt64?,
        cpuPercent: Double?,
        thermal: ThermalLevel,
        throttled: Bool?
    ) {
        var totalRAMVal: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        let sysctlRamRes = sysctlbyname("hw.memsize", &totalRAMVal, &size, nil, 0)
        let totalRAM: UInt64? = (sysctlRamRes == 0 && totalRAMVal > 0) ? totalRAMVal : nil
        
        var freeRAM: UInt64? = nil
        var usedRAM: UInt64? = nil
        var pressure: MemoryPressureLevel = .unknown
        
        // Coleta de estatísticas de VM do Mach
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let hostPort = mach_host_self()
        
        let kerr = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(hostPort, HOST_VM_INFO64, intPtr, &count)
            }
        }
        
        var pageSize: UInt64 = 16384
        var vmPageSize: vm_size_t = 0
        if host_page_size(hostPort, &vmPageSize) == KERN_SUCCESS && vmPageSize > 0 {
            pageSize = UInt64(vmPageSize)
        }
        
        if kerr == KERN_SUCCESS {
            let freePages = UInt64(stats.free_count) + UInt64(stats.speculative_count)
            let activePages = UInt64(stats.active_count)
            let wiredPages = UInt64(stats.wire_count)
            let compressedPages = UInt64(stats.compressor_page_count)
            
            let calcFree = freePages * pageSize
            let calcUsed = (activePages + wiredPages + compressedPages) * pageSize
            
            freeRAM = calcFree
            usedRAM = calcUsed
            
            // Heurística de pressão estimada pelo Resource Guard:
            // razão entre páginas ocupadas (ativas + wired + compressor) e total físico
            if let total = totalRAM, total > 0 {
                let usageRatio = Double(calcUsed) / Double(total)
                if usageRatio > 0.90 {
                    pressure = .critical
                } else if usageRatio > 0.80 {
                    pressure = .warning
                } else {
                    pressure = .normal
                }
            } else {
                pressure = .unknown
            }
        } else {
            // Em caso de falha Mach, retorna nil e unknown sem dados inventados
            freeRAM = nil
            usedRAM = nil
            pressure = .unknown
        }
        
        // Coleta de Swap via sysctl vm.swapusage
        var totalSwap: UInt64? = nil
        var usedSwap: UInt64? = nil
        var freeSwap: UInt64? = nil
        
        var xsw = xsw_usage()
        var xswSize = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &xsw, &xswSize, nil, 0) == 0 {
            totalSwap = UInt64(xsw.xsu_total)
            usedSwap = UInt64(xsw.xsu_used)
            freeSwap = UInt64(xsw.xsu_avail)
        }
        
        // Estado Térmico: Sem API estável sem privilégios IOKit/root, reporta unknown/nil explicitamente
        let thermal: ThermalLevel = .unknown
        let throttled: Bool? = nil
        
        return (
            totalRAM: totalRAM,
            freeRAM: freeRAM,
            usedRAM: usedRAM,
            pressure: pressure,
            totalSwap: totalSwap,
            usedSwap: usedSwap,
            freeSwap: freeSwap,
            cpuPercent: nil,
            thermal: thermal,
            throttled: throttled
        )
    }
}

/// Monitor de Recursos: coleta snapshots periódicos e mantém histórico de Swap delta
public actor ResourceMonitor {
    private let provider: SystemMetricsProvider
    private var lastSnapshot: SystemResourceSnapshot?
    private var initialSwapUsed: UInt64?
    
    public init(provider: SystemMetricsProvider = DarwinSystemMetricsProvider()) {
        self.provider = provider
    }
    
    public func sample() async -> SystemResourceSnapshot {
        let m = await provider.collectMetrics()
        
        var delta: Int64? = nil
        if let currentUsedSwap = m.usedSwap {
            if initialSwapUsed == nil {
                initialSwapUsed = currentUsedSwap
            }
            delta = Int64(currentUsedSwap) - Int64(initialSwapUsed ?? currentUsedSwap)
        }
        
        let snapshot = SystemResourceSnapshot(
            timestamp: Date(),
            totalRAMBytes: m.totalRAM,
            freeRAMBytes: m.freeRAM,
            usedRAMBytes: m.usedRAM,
            memoryPressure: m.pressure,
            totalSwapBytes: m.totalSwap,
            usedSwapBytes: m.usedSwap,
            freeSwapBytes: m.freeSwap,
            swapDeltaBytes: delta,
            cpuUsagePercent: m.cpuPercent,
            thermalLevel: m.thermal,
            isThrottled: m.throttled
        )
        
        self.lastSnapshot = snapshot
        return snapshot
    }
    
    public func currentSnapshot() -> SystemResourceSnapshot? {
        return lastSnapshot
    }
}
