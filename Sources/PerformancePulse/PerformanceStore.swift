import Observation
import SwiftUI

@MainActor
@Observable
final class PerformanceStore {
    private(set) var currentSnapshot: PerformanceSnapshot
    private(set) var history: MetricHistory
    private(set) var lastUpdate: Date?
    private(set) var isSampling = false

    let sampleInterval: Duration
    private var samplingTask: Task<Void, Never>?

    var historyWindowDuration: TimeInterval {
        self.sampleInterval.timeInterval * Double(self.history.capacity)
    }

    init(sampleInterval: Duration = .seconds(1), historyCapacity: Int = 90) {
        self.sampleInterval = sampleInterval
        self.currentSnapshot = .placeholder()
        self.history = MetricHistory(capacity: historyCapacity)
        self.startSampling()
    }

    func toggleSampling() {
        if self.isSampling {
            self.stopSampling()
        } else {
            self.startSampling()
        }
    }

    func stopSampling() {
        self.isSampling = false
        self.samplingTask?.cancel()
        self.samplingTask = nil
    }

    private func startSampling() {
        guard self.samplingTask == nil else { return }

        self.isSampling = true
        self.samplingTask = Task { [weak self] in
            guard let self else { return }
            await self.runSamplingLoop()
        }
    }

    private func runSamplingLoop() async {
        var sampler = SystemMetricsSampler()
        self.ingest(sampler.sample())

        while !Task.isCancelled {
            do {
                try await Task.sleep(for: self.sampleInterval)
            } catch {
                break
            }

            guard !Task.isCancelled else { break }
            self.ingest(sampler.sample())
        }

        self.samplingTask = nil
    }

    private func ingest(_ snapshot: PerformanceSnapshot) {
        withAnimation(.smooth(duration: 0.18)) {
            self.currentSnapshot = snapshot
            self.lastUpdate = snapshot.timestamp
        }

        var updatedHistory = self.history
        updatedHistory.append(snapshot)

        withTransaction(Transaction(animation: nil)) {
            self.history = updatedHistory
        }
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        let components = self.components
        let attosecondsPerSecond = 1_000_000_000_000_000_000.0
        return TimeInterval(components.seconds)
            + (Double(components.attoseconds) / attosecondsPerSecond)
    }
}
