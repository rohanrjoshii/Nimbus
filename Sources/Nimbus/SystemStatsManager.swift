import Foundation
import IOKit.ps

class SystemStatsManager: ObservableObject {
    static let shared = SystemStatsManager()
    
    @Published var cpuUsage: Double = 0.0
    @Published var memoryUsage: Double = 0.0
    @Published var batteryLevel: Int = 100
    @Published var isBatteryCharging: Bool = false
    
    // New storage and network speed stats
    @Published var diskUsedGB: Double = 0.0
    @Published var diskTotalGB: Double = 1.0
    @Published var networkUploadRate: String = "0 KB/s"
    @Published var networkDownloadRate: String = "0 KB/s"
    
    private var timer: Timer?
    private let pollInterval: TimeInterval = 2.0

    // CPU load tracking variables
    private var previousCpuInfo: processor_info_array_t?
    private var previousCpuInfoCount: mach_msg_type_number_t = 0
    private let cpuLock = NSLock()

    // Network throughput tracking (cumulative byte counters from the kernel)
    private var previousBytesIn: UInt64 = 0
    private var previousBytesOut: UInt64 = 0
    private var hasNetworkBaseline = false
    
    private init() {
        startPolling()
    }
    
    deinit {
        if let prevInfo = previousCpuInfo {
            let size = MemoryLayout<integer_t>.stride * Int(previousCpuInfoCount)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prevInfo), vm_size_t(size))
        }
        timer?.invalidate()
    }
    
    func startPolling() {
        _ = calculateCPUUsage()
        _ = currentNetworkBytes() // prime the baseline so the first reading isn't a huge spike

        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.updateStats()
        }
        updateStats()
    }

    private func updateStats() {
        let cpu = calculateCPUUsage()
        let ram = calculateMemoryUsage()
        let (batLevel, batCharging) = getBatteryInfo()
        let disk = calculateDiskSpace()
        let net = calculateNetworkSpeed()

        DispatchQueue.main.async {
            self.cpuUsage = cpu
            self.memoryUsage = ram
            self.batteryLevel = batLevel
            self.isBatteryCharging = batCharging
            self.diskUsedGB = disk.used
            self.diskTotalGB = disk.total
            self.networkUploadRate = net.upload
            self.networkDownloadRate = net.download
        }
    }
    
    // MARK: - CPU Usage Calculation
    private func calculateCPUUsage() -> Double {
        cpuLock.lock()
        defer { cpuLock.unlock() }
        
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0
        
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &numCPUInfo)
        
        guard result == KERN_SUCCESS, let cpuInfo = cpuInfo else {
            return 0.0
        }
        
        var totalUsage: Double = 0.0
        
        if let prevCpuInfo = previousCpuInfo {
            var totalUser: UInt32 = 0
            var totalSystem: UInt32 = 0
            var totalIdle: UInt32 = 0
            var totalNice: UInt32 = 0
            
            for i in 0..<Int(numCPUs) {
                let base = i * Int(CPU_STATE_MAX)
                
                let user = UInt32(cpuInfo[base + Int(CPU_STATE_USER)]) - UInt32(prevCpuInfo[base + Int(CPU_STATE_USER)])
                let system = UInt32(cpuInfo[base + Int(CPU_STATE_SYSTEM)]) - UInt32(prevCpuInfo[base + Int(CPU_STATE_SYSTEM)])
                let idle = UInt32(cpuInfo[base + Int(CPU_STATE_IDLE)]) - UInt32(prevCpuInfo[base + Int(CPU_STATE_IDLE)])
                let nice = UInt32(cpuInfo[base + Int(CPU_STATE_NICE)]) - UInt32(prevCpuInfo[base + Int(CPU_STATE_NICE)])
                
                totalUser += user
                totalSystem += system
                totalIdle += idle
                totalNice += nice
            }
            
            let total = Double(totalUser + totalSystem + totalIdle + totalNice)
            if total > 0 {
                let active = Double(totalUser + totalSystem + totalNice)
                totalUsage = (active / total) * 100.0
            }
            
            let size = MemoryLayout<integer_t>.stride * Int(previousCpuInfoCount)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prevCpuInfo), vm_size_t(size))
        }
        
        previousCpuInfo = cpuInfo
        previousCpuInfoCount = numCPUInfo
        
        return min(max(totalUsage, 0.0), 100.0)
    }
    
    // MARK: - Memory Usage Calculation
    private func calculateMemoryUsage() -> Double {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            return 0.0
        }
        
        let active = Double(stats.active_count)
        let wire = Double(stats.wire_count)
        let inactive = Double(stats.inactive_count)
        let free = Double(stats.free_count)
        
        let total = active + wire + inactive + free
        if total > 0 {
            let used = active + wire
            return (used / total) * 100.0
        }
        return 0.0
    }
    
    // MARK: - Disk Storage Calculation
    private func calculateDiskSpace() -> (used: Double, total: Double) {
        let fileManager = FileManager.default
        if let attrs = try? fileManager.attributesOfFileSystem(forPath: "/"),
           let freeSpace = attrs[.systemFreeSize] as? Int64,
           let totalSpace = attrs[.systemSize] as? Int64 {
            let totalGB = Double(totalSpace) / 1_000_000_000
            let freeGB = Double(freeSpace) / 1_000_000_000
            return (totalGB - freeGB, totalGB)
        }
        return (0.0, 1.0)
    }
    
    // MARK: - Network Throughput (real kernel byte counters)

    /// Sums cumulative in/out bytes across all active non-loopback interfaces
    /// using `getifaddrs` + `if_data`. These are monotonic counters; we diff
    /// successive samples to derive a live throughput rate.
    private func currentNetworkBytes() -> (inBytes: UInt64, outBytes: UInt64) {
        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0

        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else {
            return (0, 0)
        }
        defer { freeifaddrs(ifaddrPtr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let current = ptr {
            let addr = current.pointee.ifa_addr
            // Link-layer entries (AF_LINK) carry the if_data byte counters.
            if let addr = addr, addr.pointee.sa_family == UInt8(AF_LINK) {
                let name = String(cString: current.pointee.ifa_name)
                // Skip loopback — it doesn't represent real network activity.
                if !name.hasPrefix("lo"), let data = current.pointee.ifa_data {
                    let networkData = data.assumingMemoryBound(to: if_data.self)
                    totalIn  += UInt64(networkData.pointee.ifi_ibytes)
                    totalOut += UInt64(networkData.pointee.ifi_obytes)
                }
            }
            ptr = current.pointee.ifa_next
        }
        return (totalIn, totalOut)
    }

    private func calculateNetworkSpeed() -> (upload: String, download: String) {
        let (bytesIn, bytesOut) = currentNetworkBytes()

        guard hasNetworkBaseline else {
            previousBytesIn = bytesIn
            previousBytesOut = bytesOut
            hasNetworkBaseline = true
            return ("0 KB/s", "0 KB/s")
        }

        // Guard against counter resets (e.g. interface flap) producing negatives.
        let deltaIn  = bytesIn  >= previousBytesIn  ? bytesIn  - previousBytesIn  : 0
        let deltaOut = bytesOut >= previousBytesOut ? bytesOut - previousBytesOut : 0
        previousBytesIn = bytesIn
        previousBytesOut = bytesOut

        let downBytesPerSec = Double(deltaIn)  / pollInterval
        let upBytesPerSec   = Double(deltaOut) / pollInterval
        return (formatRate(upBytesPerSec), formatRate(downBytesPerSec))
    }

    private func formatRate(_ bytesPerSec: Double) -> String {
        let kb = bytesPerSec / 1024.0
        if kb >= 1024 {
            return String(format: "%.1f MB/s", kb / 1024.0)
        }
        return String(format: "%.0f KB/s", kb)
    }
    
    // MARK: - Battery Level & Status
    private func getBatteryInfo() -> (level: Int, isCharging: Bool) {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        
        for source in sources {
            if let desc = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as? [String: Any] {
                let type = desc[kIOPSTypeKey] as? String
                if type == kIOPSInternalBatteryType {
                    let capacity = desc[kIOPSCurrentCapacityKey] as? Int ?? 100
                    let isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
                    return (capacity, isCharging)
                }
            }
        }
        return (100, false)
    }
}
