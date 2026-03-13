import AppKit
import Charts
import SwiftUI

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
            points: self.store.history.series(for: metric),
            windowDuration: self.store.historyWindowDuration,
            isLive: self.store.isSampling)
    }

    private var footer: some View {
        HStack {
            Button(self.store.isSampling ? "Pause Sampling" : "Resume Sampling") {
                self.store.toggleSampling()
            }
            .adaptiveGlassButton()

            Spacer()

            Text("Last \(Int(self.store.historyWindowDuration.rounded()))s")
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
                .animation(.smooth(duration: 0.18), value: self.valueText)
        }
    }
}

private struct MetricChartCard: View {
    let metric: PerformanceMetric
    let latestSnapshot: PerformanceSnapshot
    let points: [MetricSeriesPoint]
    let windowDuration: TimeInterval
    let isLive: Bool
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
                        .animation(.smooth(duration: 0.18), value: self.currentValueText)

                    if let selectedPoint {
                        Text(selectedPoint.timestamp.formatted(date: .omitted, time: .standard))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }

            LiveMetricChart(
                metric: self.metric,
                points: self.smoothedPoints,
                selectedPoint: self.$selectedPoint,
                accent: self.accent,
                areaGradient: self.areaGradient,
                windowDuration: self.windowDuration,
                isLive: self.isLive)
            .frame(height: 130)
        }
        .padding(16)
        .panelSurface()
    }

    private var smoothedPoints: [MetricSeriesPoint] {
        self.points.smoothed(alpha: self.metric.chartSmoothingAlpha)
    }

    private var currentValueText: String {
        if let selectedPoint {
            return self.metric.chartValueText(for: selectedPoint.value)
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

private struct LiveMetricChart: View {
    let metric: PerformanceMetric
    let points: [MetricSeriesPoint]
    @Binding var selectedPoint: MetricSeriesPoint?
    let accent: Color
    let areaGradient: LinearGradient
    let windowDuration: TimeInterval
    let isLive: Bool

    private let frameInterval = 1.0 / 24.0

    var body: some View {
        Group {
            if self.isLive, self.selectedPoint == nil {
                TimelineView(.periodic(from: .now, by: self.frameInterval)) { context in
                    self.chartBody(at: self.displayDate(for: context.date))
                }
            } else {
                self.chartBody(at: self.referenceDate)
            }
        }
    }

    private var referenceDate: Date {
        self.points.last?.timestamp ?? .now
    }

    private var scale: MetricChartScale {
        MetricChartScale(metric: self.metric, points: self.points)
    }

    private func displayDate(for date: Date) -> Date {
        let latestSample = self.referenceDate
        return date < latestSample ? latestSample : date
    }

    private func chartBody(at now: Date) -> some View {
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
        .chartXScale(domain: self.chartDomain(endingAt: now))
        .chartYScale(domain: self.scale.domain)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: self.scale.axisValues) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.7, dash: [3, 5]))
                    .foregroundStyle(.white.opacity(0.12))
                AxisValueLabel {
                    if let numericValue = value.as(Double.self) {
                        Text(self.metric.axisLabel(for: numericValue))
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
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private func chartDomain(endingAt now: Date) -> ClosedRange<Date> {
        let endDate = Swift.max(now, self.referenceDate)
        return endDate.addingTimeInterval(-self.windowDuration)...endDate
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
}

private struct MetricChartScale {
    let domain: ClosedRange<Double>
    let axisValues: [Double]

    init(metric: PerformanceMetric, points: [MetricSeriesPoint]) {
        switch metric {
        case .cpu, .memory:
            self.domain = 0...100
            self.axisValues = [0, 25, 50, 75, 100]
        case .download:
            let peak = points.map(\.value).max() ?? 0
            let upperBound = Self.niceUpperBound(for: peak * 1.2)
            self.domain = 0...upperBound
            self.axisValues = [0, upperBound / 2, upperBound]
        }
    }

    private static func niceUpperBound(for target: Double) -> Double {
        let adjustedTarget = Swift.max(1, target)
        let exponent = floor(log10(adjustedTarget))
        let magnitude = pow(10.0, exponent)
        let normalized = adjustedTarget / magnitude

        let step: Double
        switch normalized {
        case ...1:
            step = 1
        case ...2:
            step = 2
        case ...5:
            step = 5
        default:
            step = 10
        }

        return step * magnitude
    }
}

private extension PerformanceMetric {
    var chartSmoothingAlpha: Double {
        switch self {
        case .cpu:
            0.38
        case .memory:
            0.24
        case .download:
            0.55
        }
    }

    func axisLabel(for value: Double) -> String {
        switch self {
        case .cpu, .memory:
            return value.formatted(.number.precision(.fractionLength(0)))
        case .download:
            return value.formatted(.number.precision(.fractionLength(1)))
        }
    }

    func chartValueText(for value: Double) -> String {
        switch self {
        case .cpu, .memory:
            return value.formatted(.number.precision(.fractionLength(0))) + "%"
        case .download:
            if value >= 10 {
                return value.formatted(.number.precision(.fractionLength(1))) + " MB/s"
            }
            return value.formatted(.number.precision(.fractionLength(2))) + " MB/s"
        }
    }
}

private extension Array where Element == MetricSeriesPoint {
    func smoothed(alpha: Double) -> [MetricSeriesPoint] {
        guard let first else { return [] }

        let clampedAlpha = Swift.max(0, Swift.min(alpha, 1))
        var runningValue = first.value

        return self.map { point in
            runningValue += (point.value - runningValue) * clampedAlpha
            return MetricSeriesPoint(timestamp: point.timestamp, value: runningValue)
        }
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
        self.metric.chartValueText(for: self.point.value)
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
