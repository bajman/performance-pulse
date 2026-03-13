import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private let store: PerformanceStore
    private let liquidGlassActive: Bool
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let statusButtonHostingView: StatusItemHostingView<AnyView>

    init(store: PerformanceStore, liquidGlassActive: Bool) {
        self.store = store
        self.liquidGlassActive = liquidGlassActive
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        self.statusButtonHostingView = StatusItemHostingView(
            rootView: AnyView(
                MenuBarLabelView(store: store)
                    .environment(\.liquidGlassActive, liquidGlassActive)))

        super.init()

        self.configureStatusItem()
        self.configurePopover()
    }

    @objc
    private func togglePopover(_ sender: Any?) {
        if self.popover.isShown {
            self.popover.close()
        } else {
            self.showPopover()
        }
    }

    private func configureStatusItem() {
        guard let button = self.statusItem.button else { return }

        button.target = self
        button.action = #selector(self.togglePopover(_:))

        self.statusButtonHostingView.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(self.statusButtonHostingView)

        NSLayoutConstraint.activate([
            self.statusButtonHostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            self.statusButtonHostingView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            self.statusButtonHostingView.topAnchor.constraint(equalTo: button.topAnchor),
            self.statusButtonHostingView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
        ])

        let fittingWidth = self.statusButtonHostingView.fittingSize.width
        self.statusItem.length = fittingWidth > 0 ? fittingWidth : 96
    }

    private func configurePopover() {
        let dashboard = DashboardView(store: self.store)
            .environment(\.liquidGlassActive, self.liquidGlassActive)

        let hostingController = NSHostingController(rootView: dashboard)
        hostingController.view.layoutSubtreeIfNeeded()

        self.popover.animates = true
        self.popover.behavior = .applicationDefined
        self.popover.contentViewController = hostingController
        self.popover.contentSize = hostingController.view.fittingSize
    }

    private func showPopover() {
        guard let button = self.statusItem.button else { return }

        NSApp.activate(ignoringOtherApps: true)
        self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
}

private final class StatusItemHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
