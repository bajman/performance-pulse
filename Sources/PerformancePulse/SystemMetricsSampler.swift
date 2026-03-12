import Darwin
import Darwin.Mach
import Foundation

struct SystemMetricsSampler {
    private var previousCPULoad: CPULoadSnapshot?
    private var previousNetworkCounter: NetworkCounterSnapshot?
    private let totalMemoryBytes = ProcessInfo.processInfo.physicalMemory

    mutating func sample(at date: Date = .now) -> PerformanceSnapshot {
        PerformanceSnapshot(
            timestamp: date,
            cpuUsage: self.readCPUUsage(),
            memoryUsedBytes: self.readMemoryUsedBytes() ?? 0,
            totalMemoryBytes: self.totalMemoryBytes,
            downloadRateMBps: self.readDownloadRate(at: date))
    }

    private mutating func readCPUUsage() -> Double? {
        guard let current = self.readCPULoadSnapshot() else { return nil }
        defer { self.previousCPULoad = current }
        guard let previous = self.previousCPULoad else { return nil }
        return current.usage(since: previous)
    }

    private func readCPULoadSnapshot() -> CPULoadSnapshot? {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, reboundPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else { return nil }

        return CPULoadSnapshot(
            user: UInt64(info.cpu_ticks.0),
            system: UInt64(info.cpu_ticks.1),
            idle: UInt64(info.cpu_ticks.2),
            nice: UInt64(info.cpu_ticks.3))
    }

    private func readMemoryUsedBytes() -> UInt64? {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, reboundPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else { return nil }

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)

        let availablePages = UInt64(stats.free_count + stats.inactive_count + stats.speculative_count)
        let availableBytes = min(UInt64(pageSize) * availablePages, self.totalMemoryBytes)
        return self.totalMemoryBytes > availableBytes ? self.totalMemoryBytes - availableBytes : 0
    }

    private mutating func readDownloadRate(at date: Date) -> Double? {
        guard let receivedBytes = self.readReceivedBytes() else { return nil }
        let currentCounter = NetworkCounterSnapshot(timestamp: date, receivedBytes: receivedBytes)
        defer { self.previousNetworkCounter = currentCounter }
        guard let previousCounter = self.previousNetworkCounter else { return nil }
        return currentCounter.downloadRateMBps(since: previousCounter)
    }

    private func readReceivedBytes() -> UInt64? {
        var interfacesPointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfacesPointer) == 0, let firstInterface = interfacesPointer else {
            return nil
        }

        defer { freeifaddrs(interfacesPointer) }

        var totalReceivedBytes: UInt64 = 0
        var currentInterface: UnsafeMutablePointer<ifaddrs>? = firstInterface

        while let interface = currentInterface {
            let interfaceData = interface.pointee
            let flags = Int32(interfaceData.ifa_flags)
            let isUpAndRunning = (flags & (IFF_UP | IFF_RUNNING)) == (IFF_UP | IFF_RUNNING)
            let isLoopback = (flags & IFF_LOOPBACK) == IFF_LOOPBACK

            if isUpAndRunning,
               !isLoopback,
               let address = interfaceData.ifa_addr,
               address.pointee.sa_family == UInt8(AF_LINK),
               let statsPointer = interfaceData.ifa_data?.assumingMemoryBound(to: if_data.self)
            {
                totalReceivedBytes += UInt64(statsPointer.pointee.ifi_ibytes)
            }

            currentInterface = interfaceData.ifa_next
        }

        return totalReceivedBytes
    }
}
