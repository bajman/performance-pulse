import SwiftUI

private enum SurfaceProminence {
    case content
}

private struct LiquidShellModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.liquidGlassActive) private var liquidGlassActive
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)

        content
            .clipShape(shape)
            .background {
                self.shellFill(shape: shape)
            }
            .overlay {
                shape.strokeBorder(self.shellStroke, lineWidth: 0.7)
            }
    }

    @ViewBuilder
    private func shellFill(shape: RoundedRectangle) -> some View {
        if self.liquidGlassActive, !self.reduceTransparency {
            shape
                .fill(.clear)
                .glassEffect(.regular, in: shape)
        } else {
            shape.fill(.thickMaterial)
        }
    }

    private var shellStroke: Color {
        if self.reduceTransparency {
            return Color(nsColor: .separatorColor).opacity(0.45)
        }
        return Color.white.opacity(self.colorScheme == .dark ? 0.12 : 0.22)
    }
}

private struct PanelSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.liquidGlassActive) private var liquidGlassActive
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        self.surface(content: content, prominence: .content)
    }

    private func surface(content: Content, prominence: SurfaceProminence) -> some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

        return content
            .background {
                shape
                    .fill(self.fillColor(prominence: prominence))
                    .overlay {
                        shape.strokeBorder(self.strokeColor, lineWidth: 0.8)
                    }
            }
            .shadow(color: self.shadowColor, radius: 16, x: 0, y: 10)
    }

    private func fillColor(prominence: SurfaceProminence) -> Color {
        if self.reduceTransparency {
            return Color(nsColor: .windowBackgroundColor)
        }

        let base = Color(nsColor: .controlBackgroundColor)
        if self.liquidGlassActive {
            switch (prominence, self.colorScheme) {
            case (.content, .dark):
                return base.opacity(0.74)
            case (.content, .light):
                return base.opacity(0.64)
            default:
                return base.opacity(0.7)
            }
        }

        return base.opacity(0.94)
    }

    private var strokeColor: Color {
        if self.reduceTransparency {
            return Color(nsColor: .separatorColor).opacity(0.55)
        }
        return Color.white.opacity(self.colorScheme == .dark ? 0.1 : 0.22)
    }

    private var shadowColor: Color {
        guard self.liquidGlassActive, !self.reduceTransparency else { return .clear }
        return Color.black.opacity(self.colorScheme == .dark ? 0.12 : 0.08)
    }
}

private struct MetricGlassCardModifier: ViewModifier {
    @Environment(\.liquidGlassActive) private var liquidGlassActive
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

        content
            .background {
                if self.liquidGlassActive, !self.reduceTransparency {
                    shape
                        .fill(.clear)
                        .glassEffect(.regular, in: shape)
                        .overlay {
                            shape.strokeBorder(Color.white.opacity(self.colorScheme == .dark ? 0.14 : 0.26), lineWidth: 0.7)
                        }
                } else {
                    shape
                        .fill(.regularMaterial)
                        .overlay {
                            shape.strokeBorder(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 0.8)
                        }
                }
            }
            .shadow(color: Color.black.opacity(self.liquidGlassActive ? 0.12 : 0.04), radius: 14, x: 0, y: 8)
    }
}

private struct AdaptiveGlassButtonModifier: ViewModifier {
    @Environment(\.liquidGlassActive) private var liquidGlassActive
    let prominent: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if self.liquidGlassActive {
            if self.prominent {
                content.buttonStyle(.glassProminent)
            } else {
                content.buttonStyle(.glass)
            }
        } else {
            if self.prominent {
                content.buttonStyle(.borderedProminent)
            } else {
                content.buttonStyle(.bordered)
            }
        }
    }
}

extension View {
    func liquidShell() -> some View {
        modifier(LiquidShellModifier())
    }

    func panelSurface() -> some View {
        modifier(PanelSurfaceModifier())
    }

    func metricGlassCard() -> some View {
        modifier(MetricGlassCardModifier())
    }

    func adaptiveGlassButton(prominent: Bool = false) -> some View {
        modifier(AdaptiveGlassButtonModifier(prominent: prominent))
    }
}
