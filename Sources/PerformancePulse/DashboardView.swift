import AppKit
import Charts
import SwiftUI

struct MenuBarLabelView: View {
    let store: PerformanceStore

    var body: some View {
        HStack(spacing: 8) {
            MenuBarMetricBadge(
                symbol: "cpu",
                valueText: self.store.currentSnapshot.formattedCPUUsage,
                tint: .orange)

            MenuBarMetricBadge(
                symbol: "memorychip",
                valueText: self.store.currentSnapshot.formattedMemoryUsage,
                tint: .cyan)
        }
    }
}

struct DashboardView: View {
    @Bindable var store: PerformanceStore

    var body: some View {
        ZStack {
            AtmosphericBackdrop()

            VStack(alignment: .leading, spacing: 16) {
                self.header
                self.chartCard(for: .cpu)
                self.chartCard(for: .memory)
                self.footer
            }
            .padding(20)
        }
        .frame(width: 430)
        .liquidShell()
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Performance Pulse")
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                if let lastUpdate = self.store.lastUpdate {
                    Text("Updated \(lastUpdate.formatted(date: .omitted, time: .standard))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                HStack(spacing: 12) {
                    HeaderMetricReadout(
                        symbol: "cpu",
                        title: "CPU",
                        valueText: self.store.currentSnapshot.formattedCPUUsage,
                        tint: .orange)

                    HeaderMetricReadout(
                        symbol: "memorychip",
                        title: "Memory",
                        valueText: self.store.currentSnapshot.formattedMemoryUsage,
                        tint: .cyan)
                }
            }

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                Circle()
                    .fill(self.store.isSampling ? Color.green : Color.secondary)
                    .frame(width: 8, height: 8)
                Text(self.store.isSampling ? "Live" : "Paused")
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .metricGlassCard()
        }
    }

    private func chartCard(for metric: PerformanceMetric) -> some View {
        MetricChartCard(
            metric: metric,
            latestSnapshot: self.store.currentSnapshot,
            points: self.store.history.series(for: metric))
    }

    private var footer: some View {
        HStack {
            Button(self.store.isSampling ? "Pause Sampling" : "Resume Sampling") {
                self.store.toggleSampling()
            }
            .adaptiveGlassButton()

            Spacer()

            Text("Last \(self.store.history.snapshots.count)s")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .adaptiveGlassButton(prominent: true)
        }
    }
}

private struct MenuBarMetricBadge: View {
    let symbol: String
    let valueText: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(self.tint.opacity(0.18))
                    .frame(width: 15, height: 15)
                Image(systemName: self.symbol)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(self.tint)
            }

            Text(self.valueText)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }
}

private struct HeaderMetricReadout: View {
    let symbol: String
    let title: String
    let valueText: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: self.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(self.tint)

            Text(self.title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Text(self.valueText)
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }
}

private struct MetricChartCard: View {
    let metric: PerformanceMetric
    let latestSnapshot: PerformanceSnapshot
    let points: [MetricSeriesPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(self.metric.title)
                        .font(.headline.weight(.semibold))
                    Text(self.metric.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(self.currentValueText)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(self.accent)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            Chart {
                ForEach(self.points) { point in
                    AreaMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Usage", point.value))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(self.areaGradient)
                }

                ForEach(self.points) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Usage", point.value))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(self.accent)
                }

                if let lastPoint = self.points.last {
                    PointMark(
                        x: .value("Time", lastPoint.timestamp),
                        y: .value("Usage", lastPoint.value))
                    .symbolSize(36)
                    .foregroundStyle(.white.opacity(0.92))
                }
            }
            .chartYScale(domain: 0...100)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.7, dash: [3, 5]))
                        .foregroundStyle(.white.opacity(0.12))
                    AxisValueLabel()
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 130)
        }
        .padding(16)
        .panelSurface()
    }

    private var currentValueText: String {
        switch self.metric {
        case .cpu:
            self.latestSnapshot.formattedCPUUsage
        case .memory:
            self.latestSnapshot.formattedMemoryUsage
        }
    }

    private var accent: Color {
        switch self.metric {
        case .cpu:
            .orange
        case .memory:
            .cyan
        }
    }

    private var areaGradient: LinearGradient {
        LinearGradient(
            colors: [
                self.accent.opacity(0.42),
                self.accent.opacity(0.08),
            ],
            startPoint: .top,
            endPoint: .bottom)
    }
}

private struct AtmosphericBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Circle()
                .fill(self.warmGlow)
                .frame(width: 220, height: 220)
                .blur(radius: 45)
                .offset(x: -130, y: -90)

            Circle()
                .fill(self.coolGlow)
                .frame(width: 240, height: 240)
                .blur(radius: 54)
                .offset(x: 150, y: 90)

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.black.opacity(self.colorScheme == .dark ? 0.10 : 0.04))
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private var warmGlow: Color {
        self.colorScheme == .dark
            ? Color.orange.opacity(0.34)
            : Color.orange.opacity(0.28)
    }

    private var coolGlow: Color {
        self.colorScheme == .dark
            ? Color.cyan.opacity(0.30)
            : Color.blue.opacity(0.24)
    }
}
