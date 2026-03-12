import AppKit
import SwiftUI

enum LiquidGlassAvailability {
    static var shouldApplyGlass: Bool {
        guard #available(macOS 26.4, *) else { return false }
        return !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
    }
}

private struct LiquidGlassActiveKey: EnvironmentKey {
    static let defaultValue = LiquidGlassAvailability.shouldApplyGlass
}

extension EnvironmentValues {
    var liquidGlassActive: Bool {
        get { self[LiquidGlassActiveKey.self] }
        set { self[LiquidGlassActiveKey.self] = newValue }
    }
}
