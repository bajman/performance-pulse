import AppKit
import Observation
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private let store: PerformanceStore
    private let liquidGlassActive: Bool
    private let statusItem: NSStatusItem
    private let popover: NSPopover

    init(store: PerformanceStore, liquidGlassActive: Bool) {
        self.store = store
        self.liquidGlassActive = liquidGlassActive
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()

        super.init()

        self.configureStatusItem()
        self.configurePopover()
        self.bindStatusItem()
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
        button.image = nil
        button.imagePosition = .noImage
        button.lineBreakMode = .byClipping

        self.updateStatusItem()
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

    private func bindStatusItem() {
        withObservationTracking {
            _ = self.store.currentSnapshot.formattedCPUUsage
            _ = self.store.currentSnapshot.formattedMemoryUsage
            _ = self.store.currentSnapshot.formattedDownloadSpeed
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.updateStatusItem()
                self?.bindStatusItem()
            }
        }
    }

    private func updateStatusItem() {
        guard let button = self.statusItem.button else { return }

        let title = NSMutableAttributedString()
        title.append(self.makeSegment("CPU ", font: .systemFont(ofSize: 10, weight: .medium), color: NSColor.white.withAlphaComponent(0.92)))
        title.append(self.makeSegment(self.store.currentSnapshot.formattedCPUUsage, font: .monospacedSystemFont(ofSize: 12, weight: .semibold), color: .white))
        title.append(self.makeSegment("   MEM ", font: .systemFont(ofSize: 10, weight: .medium), color: NSColor.white.withAlphaComponent(0.92)))
        title.append(self.makeSegment(self.store.currentSnapshot.formattedMemoryUsage, font: .monospacedSystemFont(ofSize: 12, weight: .semibold), color: .white))
        title.append(self.makeSegment("   RX ", font: .systemFont(ofSize: 10, weight: .medium), color: NSColor.white.withAlphaComponent(0.92)))
        title.append(self.makeSegment(self.store.currentSnapshot.formattedDownloadSpeed, font: .monospacedSystemFont(ofSize: 12, weight: .semibold), color: .white))

        button.attributedTitle = title
        button.toolTip = "CPU \(self.store.currentSnapshot.formattedCPUUsage)  Memory \(self.store.currentSnapshot.formattedMemoryUsage)  Receive \(self.store.currentSnapshot.formattedDownloadSpeed)"
        self.statusItem.length = max(196, ceil(title.size().width) + 18)
    }

    private func makeSegment(_ value: String, font: NSFont, color: NSColor) -> NSAttributedString {
        NSAttributedString(
            string: value,
            attributes: [
                .font: font,
                .foregroundColor: color,
            ])
    }
}
