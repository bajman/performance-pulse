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
    private var samplingGeneration = 0

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
        self.samplingGeneration &+= 1

        let generation = self.samplingGeneration
        let sampleInterval = self.sampleInterval

        self.samplingTask = Task.detached(priority: .utility) { [weak self] in
            var sampler = SystemMetricsSampler()
            await self?.ingest(sampler.sample())

            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: sampleInterval)
                } catch {
                    break
                }

                guard !Task.isCancelled else { break }
                await self?.ingest(sampler.sample())
            }

            await self?.samplingLoopDidFinish(for: generation)
        }
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

    private func samplingLoopDidFinish(for generation: Int) {
        guard generation == self.samplingGeneration else { return }
        self.samplingTask = nil

        if self.isSampling {
            self.isSampling = false
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
