import Foundation

enum PerformanceMetric: String, CaseIterable, Identifiable, Sendable {
    case cpu
    case memory
    case download

    var id: Self { self }

    var title: String {
        switch self {
        case .cpu:
            "CPU"
        case .memory:
            "Memory"
        case .download:
            "Download"
        }
    }

    var subtitle: String {
        switch self {
        case .cpu:
            "System-wide utilization"
        case .memory:
            "Physical memory in use"
        case .download:
            "Current receive throughput"
        }
    }
}

struct PerformanceSnapshot: Sendable {
    let timestamp: Date
    let cpuUsage: Double?
    let memoryUsedBytes: UInt64
    let totalMemoryBytes: UInt64
    let downloadRateMBps: Double?

    var memoryUsage: Double {
        guard self.totalMemoryBytes > 0 else { return 0 }
        let usage = (Double(self.memoryUsedBytes) / Double(self.totalMemoryBytes)) * 100
        return usage.clamped(to: 0...100)
    }

    var formattedCPUUsage: String {
        guard let cpuUsage else { return "--" }
        return cpuUsage.formatted(.number.precision(.fractionLength(0))) + "%"
    }

    var formattedMemoryUsage: String {
        self.memoryUsage.formatted(.number.precision(.fractionLength(0))) + "%"
    }

    var formattedMemorySummary: String {
        "\(Self.byteString(self.memoryUsedBytes)) / \(Self.byteString(self.totalMemoryBytes))"
    }

    var formattedDownloadSpeed: String {
        guard let downloadRateMBps else { return "--" }
        if downloadRateMBps >= 10 {
            return downloadRateMBps.formatted(.number.precision(.fractionLength(1))) + " MB/s"
        }
        return downloadRateMBps.formatted(.number.precision(.fractionLength(2))) + " MB/s"
    }

    static func placeholder(totalMemoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory) -> Self {
        .init(
            timestamp: .now,
            cpuUsage: nil,
            memoryUsedBytes: 0,
            totalMemoryBytes: totalMemoryBytes,
            downloadRateMBps: nil)
    }

    private static func byteString(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }
}

struct MetricSeriesPoint: Identifiable, Sendable {
    let timestamp: Date
    let value: Double

    var id: Date { self.timestamp }
}

struct MetricHistory: Sendable {
    let capacity: Int
    private(set) var snapshots: [PerformanceSnapshot] = []

    init(capacity: Int) {
        self.capacity = max(1, capacity)
    }

    mutating func append(_ snapshot: PerformanceSnapshot) {
        self.snapshots.append(snapshot)
        let overflow = self.snapshots.count - self.capacity
        if overflow > 0 {
            self.snapshots.removeFirst(overflow)
        }
    }

    func series(for metric: PerformanceMetric) -> [MetricSeriesPoint] {
        switch metric {
        case .cpu:
            self.snapshots.compactMap { snapshot in
                guard let cpuUsage = snapshot.cpuUsage else { return nil }
                return MetricSeriesPoint(timestamp: snapshot.timestamp, value: cpuUsage)
            }
        case .memory:
            self.snapshots.map { snapshot in
                MetricSeriesPoint(timestamp: snapshot.timestamp, value: snapshot.memoryUsage)
            }
        case .download:
            self.snapshots.compactMap { snapshot in
                guard let downloadRateMBps = snapshot.downloadRateMBps else { return nil }
                return MetricSeriesPoint(timestamp: snapshot.timestamp, value: downloadRateMBps)
            }
        }
    }
}

struct CPULoadSnapshot: Sendable {
    let user: UInt64
    let system: UInt64
    let idle: UInt64
    let nice: UInt64

    func usage(since previous: Self) -> Double? {
        let userDelta = self.user - previous.user
        let systemDelta = self.system - previous.system
        let idleDelta = self.idle - previous.idle
        let niceDelta = self.nice - previous.nice
        let totalDelta = userDelta + systemDelta + idleDelta + niceDelta

        guard totalDelta > 0 else { return nil }

        let activeDelta = userDelta + systemDelta + niceDelta
        let usage = (Double(activeDelta) / Double(totalDelta)) * 100
        return usage.clamped(to: 0...100)
    }
}

struct NetworkCounterSnapshot: Sendable {
    let timestamp: Date
    let receivedBytes: UInt64

    func downloadRateMBps(since previous: Self) -> Double? {
        guard self.receivedBytes >= previous.receivedBytes else { return nil }
        let interval = self.timestamp.timeIntervalSince(previous.timestamp)
        guard interval > 0 else { return nil }

        let bytesDelta = self.receivedBytes - previous.receivedBytes
        return Double(bytesDelta) / 1_000_000 / interval
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
