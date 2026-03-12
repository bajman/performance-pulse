import Foundation
import Testing
@testable import PerformancePulse

@Test("CPU deltas normalize to a 0...100 usage percentage")
func cpuUsageDelta() {
    let previous = CPULoadSnapshot(user: 100, system: 40, idle: 160, nice: 0)
    let current = CPULoadSnapshot(user: 160, system: 80, idle: 210, nice: 0)

    let usage = current.usage(since: previous)

    #expect(usage != nil)
    #expect(abs((usage ?? 0) - 66.6666666667) < 0.0001)
}

@Test("History retains only the most recent samples")
func historyCapacity() {
    var history = MetricHistory(capacity: 3)
    let totalMemory: UInt64 = 32_000_000_000

    for second in 0..<5 {
        history.append(
            PerformanceSnapshot(
                timestamp: Date(timeIntervalSince1970: Double(second)),
                cpuUsage: Double(second * 10),
                memoryUsedBytes: UInt64(second) * 1_000_000_000,
                totalMemoryBytes: totalMemory))
    }

    #expect(history.snapshots.count == 3)
    #expect(history.snapshots.map(\.timestamp) == [
        Date(timeIntervalSince1970: 2),
        Date(timeIntervalSince1970: 3),
        Date(timeIntervalSince1970: 4),
    ])
}

@Test("Memory usage is derived from used and total bytes")
func memoryUsageCalculation() {
    let snapshot = PerformanceSnapshot(
        timestamp: .now,
        cpuUsage: 42,
        memoryUsedBytes: 12,
        totalMemoryBytes: 48)

    #expect(snapshot.memoryUsage == 25)
}
