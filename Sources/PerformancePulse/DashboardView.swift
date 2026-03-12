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
                self.chartCard(for: .download)
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

                    HeaderMetricReadout(
                        symbol: "arrow.down.circle",
                        title: "Down",
                        valueText: self.store.currentSnapshot.formattedDownloadSpeed,
                        tint: .mint)
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
    @State private var selectedPoint: MetricSeriesPoint?

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

                VStack(alignment: .trailing, spacing: 2) {
                    Text(self.currentValueText)
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(self.accent)
                        .monospacedDigit()
                        .contentTransition(.numericText())

                    if let selectedPoint {
                        Text(selectedPoint.timestamp.formatted(date: .omitted, time: .standard))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
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

                if self.selectedPoint == nil, let lastPoint = self.points.last {
                    PointMark(
                        x: .value("Time", lastPoint.timestamp),
                        y: .value("Usage", lastPoint.value))
                    .symbolSize(36)
                    .foregroundStyle(.white.opacity(0.92))
                }
            }
            .chartYScale(domain: self.yScaleDomain)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: self.yAxisValues) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.7, dash: [3, 5]))
                        .foregroundStyle(.white.opacity(0.12))
                    AxisValueLabel {
                        if let numericValue = value.as(Double.self) {
                            Text(self.axisLabel(for: numericValue))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    if let plotFrame = proxy.plotFrame {
                        let frame = geometry[plotFrame]

                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in
                                self.handleHover(phase, proxy: proxy, plotFrame: frame)
                            }

                        if let selectedPoint,
                           let xPosition = proxy.position(forX: selectedPoint.timestamp),
                           let yPosition = proxy.position(forY: selectedPoint.value)
                        {
                            ChartHoverOverlay(
                                point: selectedPoint,
                                metric: self.metric,
                                accent: self.accent,
                                xPosition: frame.minX + xPosition,
                                yPosition: frame.minY + yPosition,
                                plotFrame: frame)
                        }
                    }
                }
            }
            .frame(height: 130)
        }
        .padding(16)
        .panelSurface()
    }

    private var currentValueText: String {
        if let selectedPoint {
            return self.valueText(for: selectedPoint.value)
        }

        switch self.metric {
        case .cpu:
            return self.latestSnapshot.formattedCPUUsage
        case .memory:
            return self.latestSnapshot.formattedMemoryUsage
        case .download:
            return self.latestSnapshot.formattedDownloadSpeed
        }
    }

    private var accent: Color {
        switch self.metric {
        case .cpu:
            .orange
        case .memory:
            .cyan
        case .download:
            .mint
        }
    }

    private var yScaleDomain: ClosedRange<Double> {
        switch self.metric {
        case .cpu, .memory:
            return 0...100
        case .download:
            let peak = self.points.map(\.value).max() ?? 0
            return 0...max(1, peak * 1.2)
        }
    }

    private var yAxisValues: [Double] {
        switch self.metric {
        case .cpu, .memory:
            return [0, 25, 50, 75, 100]
        case .download:
            let upperBound = self.yScaleDomain.upperBound
            return [0, upperBound / 2, upperBound]
        }
    }

    private func axisLabel(for value: Double) -> String {
        switch self.metric {
        case .cpu, .memory:
            return value.formatted(.number.precision(.fractionLength(0)))
        case .download:
            return value.formatted(.number.precision(.fractionLength(1)))
        }
    }

    private func valueText(for value: Double) -> String {
        switch self.metric {
        case .cpu, .memory:
            return value.formatted(.number.precision(.fractionLength(0))) + "%"
        case .download:
            if value >= 10 {
                return value.formatted(.number.precision(.fractionLength(1))) + " MB/s"
            }
            return value.formatted(.number.precision(.fractionLength(2))) + " MB/s"
        }
    }

    private func handleHover(_ phase: HoverPhase, proxy: ChartProxy, plotFrame: CGRect) {
        switch phase {
        case .active(let location):
            let localX = location.x - plotFrame.minX
            guard localX >= 0,
                  localX <= plotFrame.width,
                  let hoveredDate = proxy.value(atX: localX, as: Date.self)
            else {
                self.selectedPoint = nil
                return
            }

            self.selectedPoint = self.nearestPoint(to: hoveredDate)
        case .ended:
            self.selectedPoint = nil
        }
    }

    private func nearestPoint(to date: Date) -> MetricSeriesPoint? {
        self.points.min { lhs, rhs in
            abs(lhs.timestamp.timeIntervalSince(date)) < abs(rhs.timestamp.timeIntervalSince(date))
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

private struct ChartHoverOverlay: View {
    let point: MetricSeriesPoint
    let metric: PerformanceMetric
    let accent: Color
    let xPosition: CGFloat
    let yPosition: CGFloat
    let plotFrame: CGRect

    var body: some View {
        ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: CGPoint(x: self.xPosition, y: self.plotFrame.minY))
                path.addLine(to: CGPoint(x: self.xPosition, y: self.plotFrame.maxY))
            }
            .stroke(
                Color.white.opacity(0.28),
                style: StrokeStyle(lineWidth: 1, dash: [4, 6]))

            Circle()
                .fill(self.accent)
                .frame(width: 10, height: 10)
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.9), lineWidth: 2)
                }
                .position(x: self.xPosition, y: self.yPosition)

            HoverCallout(
                title: self.valueText,
                timestamp: self.point.timestamp.formatted(date: .omitted, time: .standard),
                accent: self.accent)
            .position(
                x: self.calloutX,
                y: max(self.plotFrame.minY + 18, self.yPosition - 28))
        }
        .allowsHitTesting(false)
    }

    private var calloutX: CGFloat {
        min(max(self.xPosition, self.plotFrame.minX + 70), self.plotFrame.maxX - 70)
    }

    private var valueText: String {
        switch self.metric {
        case .cpu, .memory:
            return self.point.value.formatted(.number.precision(.fractionLength(0))) + "%"
        case .download:
            if self.point.value >= 10 {
                return self.point.value.formatted(.number.precision(.fractionLength(1))) + " MB/s"
            }
            return self.point.value.formatted(.number.precision(.fractionLength(2))) + " MB/s"
        }
    }
}

private struct HoverCallout: View {
    let title: String
    let timestamp: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(self.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .monospacedDigit()

            Text(self.timestamp)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.72))
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.black.opacity(0.72))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(self.accent.opacity(0.35), lineWidth: 1)
                }
        )
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
