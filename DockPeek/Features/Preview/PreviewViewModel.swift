import AppKit
import Observation
import SwiftUI

/// Shows the window previews while the pointer is over a Dock icon and hides them once
/// it leaves both the icon and the panel.
@MainActor
@Observable
final class PreviewViewModel {
    /// Hover delay before the first preview, so passing over the Dock does not flash panels.
    static let showDelay: Duration = .milliseconds(200)
    /// How long the pointer may be outside icon and panel before the preview hides.
    static let hideDelay: TimeInterval = 0.25

    private(set) var isRunning = false

    var isEnabled: Bool {
        get { access(keyPath: \.isEnabled); return defaults.object(forKey: Self.enabledKey) as? Bool ?? true }
        set {
            withMutation(keyPath: \.isEnabled) { defaults.set(newValue, forKey: Self.enabledKey) }
            if !newValue { hide() }
        }
    }

    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private let dock = DockObserver()
    @ObservationIgnored private let thumbnailService = ThumbnailService()
    @ObservationIgnored private let panel = PreviewPanel()
    @ObservationIgnored private var item: DockItem?
    @ObservationIgnored private var content = PreviewContent.empty
    @ObservationIgnored private var showTask: Task<Void, Never>?
    @ObservationIgnored private var trackingTimer: Timer?
    @ObservationIgnored private var outsideSince: Date?
    @ObservationIgnored private var clickMonitor: Any?
    @ObservationIgnored private var accessTimer: Timer?
    @ObservationIgnored private var isDemo = false

    private static let enabledKey = "previewEnabled"

    /// Starts watching the Dock once Accessibility is granted.
    func start() {
        guard !isRunning else { return }
        log.info("Start, trusted: \(PermissionService.hasAccessibility)")
        guard PermissionService.hasAccessibility else {
            // The grant takes effect without a restart; pick it up as soon as it arrives.
            accessTimer?.invalidate()
            accessTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, PermissionService.hasAccessibility else { return }
                    self.accessTimer?.invalidate()
                    self.accessTimer = nil
                    self.start()
                }
            }
            return
        }
        dock.onHover = { [weak self] item in self?.hovered(item) }
        dock.start()
        isRunning = true
    }

    // MARK: - Hover

    private func hovered(_ item: DockItem?) {
        guard isEnabled, !isDemo else { return }
        showTask?.cancel()
        // Leaving the icons is handled by the tracking timer, so the pointer can move to the panel.
        guard let item else { return }

        if panel.isVisible {
            // Moving along the Dock switches right away, like the Windows taskbar.
            show(item)
            return
        }
        showTask = Task { [weak self] in
            try? await Task.sleep(for: Self.showDelay)
            guard !Task.isCancelled, let self else { return }
            self.show(item)
        }
    }

    private func show(_ item: DockItem) {
        let windows = WindowService.windows(of: item.app)
        log.debug("Show \(item.app.localizedName ?? "?"): \(windows.count) windows")
        guard !windows.isEmpty else {
            hide()
            return
        }
        self.item = item
        let screen = NSScreen.screens.first { $0.frame.intersects(item.frame) } ?? NSScreen.main
        let maxWidth = (screen?.frame.width ?? 1440) - PreviewLayout.margin * 2
        content = PreviewContent(
            appIcon: item.app.icon,
            rows: PreviewView.rows(for: windows, maxWidth: maxWidth),
            thumbnails: Dictionary(uniqueKeysWithValues: windows.compactMap { window in
                thumbnailService.cached(window.id).map { (window.id, $0) }
            })
        )
        panel.show(view, near: item.frame)
        startTracking()
        // Cached images show right away; fresh ones replace them when they arrive.
        loadThumbnails(for: windows, of: item.app)
    }

    private func loadThumbnails(for windows: [AppWindow], of app: NSRunningApplication) {
        Task { [weak self] in
            guard let self else { return }
            let images = await thumbnailService.capture(windows, pointSize: PreviewView.thumbnailSize(for:))
            guard self.item?.app == app, self.panel.isVisible, !images.isEmpty else { return }
            self.content.thumbnails.merge(images) { $1 }
            self.panel.update(self.view)
        }
    }

    private var view: PreviewView {
        PreviewView(
            content: content,
            onFocus: { [weak self] window in self?.focus(window) },
            onClose: { [weak self] window in self?.close(window) }
        )
    }

    // MARK: - Actions

    private func focus(_ window: AppWindow) {
        guard let app = item?.app else { return }
        hide()
        WindowService.focus(window, of: app)
    }

    private func close(_ window: AppWindow) {
        WindowService.close(window)
        thumbnailService.forget(window.id)
        // Give the app a moment to close the window (or show a save dialog), then refresh.
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, let item = self.item, self.panel.isVisible else { return }
            self.show(item)
        }
    }

    // MARK: - Tracking

    private func startTracking() {
        outsideSince = nil
        if trackingTimer == nil {
            trackingTimer = Timer.scheduledTimer(withTimeInterval: 1 / 30, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.track() }
            }
        }
        if clickMonitor == nil {
            // A click anywhere else (including the Dock icon itself) dismisses the preview.
            clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
                MainActor.assumeIsolated { self?.hide() }
            }
        }
    }

    private func track() {
        guard let item else { return hide() }
        let mouse = NSEvent.mouseLocation
        // The icon, the panel and the gap between them keep the preview open.
        let zone = item.frame.union(panel.frame).insetBy(dx: -6, dy: -6)
        if zone.contains(mouse) {
            outsideSince = nil
            return
        }
        let now = Date()
        if let outsideSince, now.timeIntervalSince(outsideSince) > Self.hideDelay {
            hide()
        } else if outsideSince == nil {
            outsideSince = now
        }
    }

    func hide() {
        guard !isDemo else { return }
        showTask?.cancel()
        trackingTimer?.invalidate()
        trackingTimer = nil
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        clickMonitor = nil
        item = nil
        outsideSince = nil
        panel.hide()
    }

    // MARK: - Demo

    #if DEBUG
    /// Shows sample windows above the bottom center of the main screen (`-DockPeekDemo`).
    func showDemo() {
        isDemo = true
        guard let screen = NSScreen.main else { return }
        let windows = DemoData.windows
        content = PreviewContent(
            appIcon: NSWorkspace.shared.icon(forFile: "/System/Applications/Notes.app"),
            rows: PreviewView.rows(for: windows, maxWidth: screen.frame.width - PreviewLayout.margin * 2),
            thumbnails: DemoData.thumbnails(for: windows, size: PreviewView.thumbnailSize(for:))
        )
        let icon = CGRect(x: screen.frame.midX - 32, y: screen.frame.minY + 4, width: 64, height: 64)
        panel.show(view, near: icon)
    }
    #endif
}
