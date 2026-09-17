import Foundation

/// Protocolo abstrato para coleta de métricas de sistema do macOS
public protocol SystemMetricsProvider: Sendable {
    func collectMetrics() async -> (
        totalRAM: UInt64,
        freeRAM: UInt64,
        usedRAM: UInt64,
        pressure: MemoryPressureLevel,
        totalSwap: UInt64,
        usedSwap: UInt64,
        freeSwap: UInt64,
        cpuPercent: Double?,
        thermal: ThermalLevel,
        throttled: Bool
    )
}

/// Provedor real de métricas via APIs do macOS / Darwin / Sysctl
public final class DarwinSystemMetricsProvider: SystemMetricsProvider, Sendable {
    public init() {}
    
    public func collectMetrics() async -> (
        totalRAM: UInt64,
        freeRAM: UInt64,
        usedRAM: UInt64,
        pressure: MemoryPressureLevel,
        totalSwap: UInt64,
        usedSwap: UInt64,
        freeSwap: UInt64,
        cpuPercent: Double?,
        thermal: ThermalLevel,
        throttled: Bool
    ) {
        var totalRAM: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &totalRAM, &size, nil, 0)
        
        var freeRAM: UInt64 = 0
        var usedRAM: UInt64 = 0
        var pressure: MemoryPressureLevel = .normal
        
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
            
            freeRAM = freePages * pageSize
            usedRAM = (activePages + wiredPages + compressedPages) * pageSize
            
            // Heurística de pressão: se páginas comprimidas + ativas ocupam > 85% da RAM
            if totalRAM > 0 {
                let usageRatio = Double(usedRAM) / Double(totalRAM)
                if usageRatio > 0.90 {
                    pressure = .critical
                } else if usageRatio > 0.80 {
                    pressure = .warning
                } else {
                    pressure = .normal
                }
            }
        } else {
            usedRAM = totalRAM / 2
            freeRAM = totalRAM / 2
        }
        
        // Coleta de Swap via sysctl vm.swapusage
        var totalSwap: UInt64 = 0
        var usedSwap: UInt64 = 0
        var freeSwap: UInt64 = 0
        
        var xsw = xsw_usage()
        var xswSize = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &xsw, &xswSize, nil, 0) == 0 {
            totalSwap = UInt64(xsw.xsu_total)
            usedSwap = UInt64(xsw.xsu_used)
            freeSwap = UInt64(xsw.xsu_avail)
        }
        
        // Thermal State
        let thermal: ThermalLevel = .nominal
        let throttled = false
        
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
        
        if initialSwapUsed == nil {
            initialSwapUsed = m.usedSwap
        }
        
        let delta: Int64 = Int64(m.usedSwap) - Int64(initialSwapUsed ?? m.usedSwap)
        
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
