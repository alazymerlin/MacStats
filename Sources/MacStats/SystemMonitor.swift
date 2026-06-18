 import Foundation
 import IOKit
 import IOKit.ps
 import MachO
 import Metal
 
 // MARK: - Models
 
 struct MemoryUsage {
     let used: UInt64
     let total: UInt64
     var percent: Double {
         total > 0 ? Double(used) / Double(total) * 100 : 0
     }
 }
 
 struct DiskInfo {
     let free: Int64
     let total: Int64
     var usedPercent: Double {
         total > 0 ? Double(total - free) / Double(total) * 100 : 0
     }
 }
 
 struct BatteryInfo {
     let cycleCount: Int
     let healthPercent: Int
     let isCharging: Bool
     let currentCapacity: Int
     let maxCapacity: Int
     var capacityPercent: Int {
         maxCapacity > 0 ? Int(Double(currentCapacity) / Double(maxCapacity) * 100) : 0
     }
 }
 
 struct GPUInfo {
     let name: String
     let utilization: Double?
     let memoryUsed: UInt64?
     let memoryTotal: UInt64?
 }
 
 
struct WidgetStats: Codable {
    let cpuUsage: Double
    let memoryPercent: Double
    let memoryUsed: String
    let memoryTotal: String
    let gpuName: String
    let uploadSpeed: String
    let downloadSpeed: String
    let localIP: String
    let publicIP: String
    let diskFree: String
    let diskPercent: Double
    let batteryCycles: Int
    let batteryHealth: Int
    let batteryCharging: Bool
    let hasBattery: Bool
}

// MARK: - SystemMonitor
 
 @MainActor
 final class SystemMonitor: ObservableObject {
     @Published var cpuUsage: Double = 0
     @Published var memory: MemoryUsage = .init(used: 0, total: 0)
     @Published var gpu: GPUInfo = .init(name: "查询中…", utilization: nil, memoryUsed: nil, memoryTotal: nil)
     @Published var uploadSpeed: Double = 0
     @Published var downloadSpeed: Double = 0
     @Published var localIP: String = "N/A"
     @Published var publicIP: String = "N/A"
     @Published var disk: DiskInfo = .init(free: 0, total: 0)
     @Published var battery: BatteryInfo = .init(cycleCount: 0, healthPercent: 100, isCharging: false, currentCapacity: 0, maxCapacity: 0)
     @Published var hasBattery: Bool = true
 
     // Delta tracking
     private var prevCPULoad: host_cpu_load_info?
     private var prevNetwork: (rx: UInt64, tx: UInt64)?
 
     private var updateTimer: Timer?
     private let pageSize: UInt64 = {
         UInt64(vm_kernel_page_size)
     }()
 
     private let ipRefreshInterval: TimeInterval = 120
     private var lastPublicIPFetch: Date = .distantPast
 
     init() {
        fetchGPUDeviceInfo()
         startMonitoring()
     }
 
     deinit {
         updateTimer?.invalidate()
     }
 
     // MARK: - Timer
 
     func startMonitoring() {
         updateTimer?.invalidate()
         updateOnce()
         updateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
             Task { @MainActor in
                 self?.updateOnce()
             }
         }
     }
 
     func updateOnce() {
         cpuUsage = readCPUUsage()
         memory = readMemoryUsage()
         let net = readNetworkSpeed()
         uploadSpeed = net.upload
         downloadSpeed = net.download
         localIP = readLocalIP()
         disk = readDiskSpace()
         battery = readBatteryInfo()
         if Date().timeIntervalSince(lastPublicIPFetch) > ipRefreshInterval {
             Task { await fetchPublicIP() }
         }
         writeWidgetStats()
     }
 
     // MARK: - CPU
 
     private func readCPUUsage() -> Double {
         var load = host_cpu_load_info()
         var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
         let kr = withUnsafeMutablePointer(to: &load) { ptr in
             ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                 host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
             }
         }
         guard kr == KERN_SUCCESS else { return 0 }
 
         let user   = UInt64(load.cpu_ticks.0)
         let system = UInt64(load.cpu_ticks.1)
         let idle   = UInt64(load.cpu_ticks.2)
         let nice   = UInt64(load.cpu_ticks.3)
         let total  = user + system + idle + nice
 
         guard let prev = prevCPULoad else {
             prevCPULoad = load
             return 0
         }
 
         let prevUser   = UInt64(prev.cpu_ticks.0)
         let prevSystem = UInt64(prev.cpu_ticks.1)
         let prevIdle   = UInt64(prev.cpu_ticks.2)
         let prevNice   = UInt64(prev.cpu_ticks.3)
         let prevTotal  = prevUser + prevSystem + prevIdle + prevNice
 
         prevCPULoad = load
 
         let totalDelta = total - prevTotal
         let idleDelta  = idle - prevIdle
         guard totalDelta > 0 else { return 0 }
 
         return Double(totalDelta - idleDelta) / Double(totalDelta) * 100.0
     }
 
     // MARK: - Memory
 
     private func readMemoryUsage() -> MemoryUsage {
         var stats = vm_statistics64()
         var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
         let kr = withUnsafeMutablePointer(to: &stats) { ptr in
             ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                 host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
             }
         }
         guard kr == KERN_SUCCESS else {
             return MemoryUsage(used: 0, total: 0)
         }
 
         let used = UInt64(stats.active_count + stats.wire_count) * pageSize
         let total = ProcessInfo.processInfo.physicalMemory
         return MemoryUsage(used: used, total: total)
     }
 
     // MARK: - GPU
 
     private func fetchGPUDeviceInfo() {
         if let device = MTLCreateSystemDefaultDevice() {
             let name = device.name
             let totalMem = device.recommendedMaxWorkingSetSize
             // Try to read utilization from IOKit
             var util: Double?
             if let u = readGPUUtilization() { util = u }
             gpu = GPUInfo(name: name, utilization: util, memoryUsed: nil, memoryTotal: totalMem)
         }
     }
 
     private func readGPUUtilization() -> Double? {
         let matching = IOServiceMatching("AGXAccelerator")
         var iterator: io_iterator_t = 0
         guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
             return nil
         }
         defer { IOObjectRelease(iterator) }
 
         var result: Double?
         var entry = IOIteratorNext(iterator)
         while entry != 0 {
             var dict: Unmanaged<CFMutableDictionary>?
             if IORegistryEntryCreateCFProperties(entry, &dict, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                let d = dict?.takeRetainedValue() as? [String: Any] {
                 // Common keys: "GPU Utilization", "GPU Core Utilization"
                 if let val = d["GPU Utilization"] as? Double {
                     result = val * 100.0
                     IOObjectRelease(entry)
                     break
                 }
                 if let val = d["GPU Core Utilization"] as? Double {
                     result = val * 100.0
                     IOObjectRelease(entry)
                     break
                 }
             }
             IOObjectRelease(entry)
             entry = IOIteratorNext(iterator)
         }
         return result
     }
 
     // MARK: - Network Speed
 
     private func readNetworkSpeed() -> (upload: Double, download: Double) {
         var ifaddr: UnsafeMutablePointer<ifaddrs>?
         guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return (0, 0) }
         defer { freeifaddrs(ifaddr) }
 
         var totalRX: UInt64 = 0
         var totalTX: UInt64 = 0
 
         var ptr = first
         repeat {
             let flags = ptr.pointee.ifa_flags
             if (flags & UInt32(IFF_LOOPBACK)) == 0 && (flags & UInt32(IFF_RUNNING)) != 0,
                ptr.pointee.ifa_addr.pointee.sa_family == AF_LINK {
                 if let data = ptr.pointee.ifa_data?.assumingMemoryBound(to: if_data.self) {
                     totalRX += UInt64(data.pointee.ifi_ibytes)
                     totalTX += UInt64(data.pointee.ifi_obytes)
                 }
             }
             guard let next = ptr.pointee.ifa_next else { break }
             ptr = next
         } while true
 
         guard let prev = prevNetwork, totalRX >= prev.rx, totalTX >= prev.tx else {
             prevNetwork = (totalRX, totalTX)
             return (0, 0)
         }
         prevNetwork = (totalRX, totalTX)
 
         let interval: TimeInterval = 2.0
         return (Double(totalTX - prev.tx) / interval, Double(totalRX - prev.rx) / interval)
     }
 
     // MARK: - IP Address
 
     private func readLocalIP() -> String {
         var ifaddr: UnsafeMutablePointer<ifaddrs>?
         guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return "N/A" }
         defer { freeifaddrs(ifaddr) }
 
         var ptr = first
         repeat {
             let flags = ptr.pointee.ifa_flags
             let name = String(cString: ptr.pointee.ifa_name)
             if (flags & UInt32(IFF_UP)) != 0 && (flags & UInt32(IFF_LOOPBACK)) == 0,
                ptr.pointee.ifa_addr.pointee.sa_family == AF_INET,
                name.hasPrefix("en") {
                 var addr = ptr.pointee.ifa_addr.pointee
                 var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                 if getnameinfo(&addr, socklen_t(addr.sa_len),
                                &host, socklen_t(host.count),
                                nil, 0, NI_NUMERICHOST) == 0 {
                     let ip = String(cString: host)
                     if ip != "0.0.0.0" { return ip }
                 }
             }
             guard let next = ptr.pointee.ifa_next else { break }
             ptr = next
         } while true
         return "N/A"
     }
 
     private func fetchPublicIP() async {
         guard let url = URL(string: "https://api.ipify.org") else { return }
         lastPublicIPFetch = Date()
         do {
             let (data, _) = try await URLSession.shared.data(from: url)
             publicIP = String(data: data, encoding: .utf8) ?? "N/A"
         } catch {
             publicIP = "获取失败"
         }
     }
 
     // MARK: - Disk
 
     private func readDiskSpace() -> DiskInfo {
         let path = "/"
         do {
             let attrs = try FileManager.default.attributesOfFileSystem(forPath: path)
             let free  = (attrs[.systemFreeSize]  as? NSNumber)?.int64Value ?? 0
             let total = (attrs[.systemSize]      as? NSNumber)?.int64Value ?? 0
             return DiskInfo(free: free, total: total)
         } catch {
             return DiskInfo(free: 0, total: 0)
         }
     }
 
     // MARK: - Battery
 
    private func readBatteryInfo() -> BatteryInfo {
        // hasBattery is already set by checkBatteryWithPMSet() in init
        guard hasBattery else {
            return BatteryInfo(cycleCount: 0, healthPercent: 100, isCharging: false, currentCapacity: 0, maxCapacity: 0)
        }

        let matching = IOServiceMatching("AppleSmartBattery")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return battery
        }
        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != 0 else { return battery }
        defer { IOObjectRelease(service) }

        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any] else {
            return battery
        }

        let cycleCount  = dict["CycleCount"]          as? Int ?? 0
        let isCharging  = dict["Is Charging"]          as? Bool ?? false
        let currentRaw  = dict["AppleRawCurrentCapacity"] as? Int ?? 0
        let maxCapRatio = dict["MaxCapacity"]          as? Int
        let health = max(0, min(100, maxCapRatio ?? 100))

        return BatteryInfo(cycleCount: cycleCount, healthPercent: health, isCharging: isCharging,
                          currentCapacity: currentRaw, maxCapacity: currentRaw)
    }

    private func checkBatteryWithPMSet() {
        let task = Process()
        task.launchPath = "/usr/bin/pmset"
        task.arguments = ["-g", "batt"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            hasBattery = output.contains("InternalBattery")
            if !hasBattery {
                battery = BatteryInfo(cycleCount: 0, healthPercent: 100, isCharging: false, currentCapacity: 0, maxCapacity: 0)
            }
        } catch {
            // Keep default hasBattery = true
        }
    }
 

     // MARK: - Widget Shared Data

    private func writeWidgetStats() {
        var appCache = FileManager.default.homeDirectoryForCurrentUser
        appCache.appendPathComponent("Library/Caches/com.macstats")
        try? FileManager.default.createDirectory(at: appCache, withIntermediateDirectories: true)
        let url = appCache.appendingPathComponent("stats.json")
        let stats = WidgetStats(
            cpuUsage: cpuUsage,
            memoryPercent: memory.percent,
            memoryUsed: formatBytes(memory.used),
            memoryTotal: formatBytes(memory.total),
            gpuName: gpu.name,
            uploadSpeed: formatSpeed(uploadSpeed),
            downloadSpeed: formatSpeed(downloadSpeed),
            localIP: localIP,
            publicIP: publicIP,
            diskFree: formatBytes(disk.free),
            diskPercent: disk.usedPercent,
            batteryCycles: battery.cycleCount,
            batteryHealth: battery.healthPercent,
            batteryCharging: battery.isCharging,
            hasBattery: hasBattery
        )
        guard let data = try? JSONEncoder().encode(stats) else { return }
        try? data.write(to: url, options: .atomic)
    }

     // MARK: - Helpers
 
     func formatBytes(_ value: Int64) -> String {
         let absVal = abs(value)
         let units = ["B", "KB", "MB", "GB", "TB"]
         var v = Double(absVal)
         var u = 0
         while v >= 1024 && u < units.count - 1 { v /= 1024; u += 1 }
         return String(format: "%.1f %@", v, units[u])
     }
 
     func formatBytes(_ value: UInt64) -> String {
         formatBytes(Int64(value))
     }
 
     func formatSpeed(_ bytesPerSec: Double) -> String {
         let absVal = abs(bytesPerSec)
         if absVal < 1024 { return String(format: "%.0f B/s", absVal) }
         if absVal < 1024 * 1024 { return String(format: "%.1f KB/s", absVal / 1024) }
         if absVal < 1024 * 1024 * 1024 { return String(format: "%.1f MB/s", absVal / (1024 * 1024)) }
         return String(format: "%.2f GB/s", absVal / (1024 * 1024 * 1024))
     }
 
     var cpuUsageFormatted: String {
         String(format: "%.1f%%", cpuUsage)
     }
 
     var memoryFormatted: String {
         "\(formatBytes(memory.used)) / \(formatBytes(memory.total))"
     }
 
     var memoryPercentFormatted: String {
         String(format: "%.1f%%", memory.percent)
     }
 
     var diskFormatted: String {
         "\(formatBytes(disk.free)) / \(formatBytes(disk.total))"
     }
 
     var diskPercentFormatted: String {
         String(format: "%.1f%%", disk.usedPercent)
     }
 
     var networkFormatted: String {
         "↑ \(formatSpeed(uploadSpeed))  ↓ \(formatSpeed(downloadSpeed))"
     }
 
     var batterySummary: String {
         guard hasBattery else { return "无电池" }
         let charge = battery.isCharging ? "⚡充电中" : "🔋"
         return "循环 \(battery.cycleCount)次  健康 \(battery.healthPercent)%  \(charge)"
     }
 }
