import AppKit
import SwiftUI

@main
struct PerformancePulseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = PerformanceStore()
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        self.statusBarController = StatusBarController(
            store: self.store,
            liquidGlassActive: LiquidGlassAvailability.shouldApplyGlass)
    }
}
