import AppKit
import SwiftUI

@main
struct PerformancePulseApp: App {
    @State private var store = PerformanceStore()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            DashboardView(store: self.store)
                .environment(\.liquidGlassActive, LiquidGlassAvailability.shouldApplyGlass)
        } label: {
            MenuBarLabelView(store: self.store)
                .environment(\.liquidGlassActive, LiquidGlassAvailability.shouldApplyGlass)
        }
        .menuBarExtraStyle(.window)
    }
}
