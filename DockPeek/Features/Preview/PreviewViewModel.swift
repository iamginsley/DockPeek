import AppKit
import Observation
import SwiftUI

/// Shows the window previews while the pointer is over a Dock icon and hides them once
/// it leaves both the icon and the panel.
@MainActor
@Observable
final class PreviewViewModel {
    /// How long the pointer rests on a thumbnail before Aero Peek starts.
    static let peekDelay: Duration = .milliseconds(400)
    /// How long the pointer may be outside icon and panel before the preview hides.
    static let hideDelay: TimeInterval = 0.25

    private(set) var isRunning = false

    @ObservationIgnored private let preferences: Preferences
    @ObservationIgnored private let dock: DockObserver
    @ObservationIgnored private let peek = PeekOverlay()
    @ObservationIgnored private var peekTask: Task<Void, Never>?
    @ObservationIgnored private let thumbnailService = ThumbnailService()
    @ObservationIgnored private let panel = PreviewPanel()
    @ObservationIgnored private var item: DockItem?
    @ObservationIgnored private var content = PreviewContent.empty
    @ObservationIgnored private var showTask: Task<Void, Never>?
    @ObservationIgnored private var trackingTimer: Timer?
    @ObservationIgnored private var outsideSince: Date?
    @ObservationIgnored private var clickMonitor: Any?
    @ObservationIgnored private var middleClickMonitor: Any?
    @ObservationIgnored private var hoveredWindowID: CGWindowID?
    @ObservationIgnored private var accessTimer: Timer?
    @ObservationIgnored private var isDemo = false

    init(dock: DockObserver, preferences: Preferences) {
        self.dock = dock
        self.preferences = preferences
    }

    /// Applies settings that need more than a check at use time.
    func applyPreferences() {
        if !preferences.isPreviewEnabled { hide() }
        thumbnailService.setBackgroundCapture(isRunning && preferences.isBackgroundCaptureEnabled) { [weak self] in
            self?.preferences.thumbnailSize.box ?? ThumbnailSize.medium.box
        }
    }

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
        applyPreferences()
    }

    // MARK: - Hover

    private func hovered(_ item: DockItem?) {
        guard preferences.isPreviewEnabled, !isDemo else { return }
        showTask?.cancel()
        // Leaving the icons is handled by the tracking timer, so the pointer can move to the panel.
        guard let item else { return }

        if panel.isVisible {
            // Moving along the Dock switches right away, like the Windows taskbar.
            show(item)
            return
        }
        showTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.preferences.previewDelay ?? 0.2))
            guard !Task.isCancelled, let self else { return }
            self.show(item)
        }
    }

    private func show(_ item: DockItem) {
        let windows = WindowService.windows(of: item.app)
        log.debug("Show \(item.app.localizedName ?? "?", privacy: .public): \(windows.count) windows")
        guard !windows.isEmpty else {
            hide()
            return
        }
        self.item = item
        let screen = NSScreen.screens.first { $0.frame.intersects(item.frame) } ?? NSScreen.main
        let maxWidth = (screen?.frame.width ?? 1440) - PreviewLayout.margin * 2
        let box = preferences.thumbnailSize.box
        content = PreviewContent(
            appIcon: item.app.icon,
            rows: PreviewView.rows(for: windows, in: box, maxWidth: maxWidth),
            thumbnails: Dictionary(uniqueKeysWithValues: windows.compactMap { window in
                thumbnailService.cached(window.id).map { (window.id, $0) }
            }),
            box: box
        )
        panel.show(view, near: item.frame)
        startTracking()
        // Cached images show right away; fresh ones replace them when they arrive.
        loadThumbnails(for: windows, of: item.app)
    }

    private func loadThumbnails(for windows: [AppWindow], of app: NSRunningApplication) {
        Task { [weak self] in
            guard let self else { return }
            let images = await thumbnailService.capture(windows, in: self.content.box)
            guard self.item?.app == app, self.panel.isVisible, !images.isEmpty else { return }
            self.content.thumbnails.merge(images) { $1 }
            self.panel.update(self.view)
        }
    }

    private var view: PreviewView {
        PreviewView(
            content: content,
            onFocus: { [weak self] window in self?.focus(window) },
            onClose: { [weak self] window in self?.close(window) },
            onHover: { [weak self] id, isHovered in
                guard let self else { return }
                // Leaving one card and entering the next can arrive in either order.
                if isHovered {
                    self.hoveredWindowID = id
                    self.schedulePeek(at: id)
                } else if self.hoveredWindowID == id {
                    self.hoveredWindowID = nil
                    self.endPeek()
                }
            }
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

    private func closeHoveredWindow() -> Bool {
        guard let hoveredWindowID,
              let window = content.rows.joined().first(where: { $0.id == hoveredWindowID })
        else { return false }
        close(window)
        return true
    }

    // MARK: - Aero Peek

    private func schedulePeek(at id: CGWindowID) {
        peekTask?.cancel()
        guard preferences.isPeekEnabled,
              let window = content.rows.joined().first(where: { $0.id == id }),
              !window.isMinimized, window.frame != nil
        else {
            // A minimized window has no place on screen to show; frosting alone would be pointless.
            peek.hide()
            return
        }
        peekTask = Task { [weak self] in
            // Already peeking: move to the next window without waiting again.
            if self?.peek.isVisible != true {
                try? await Task.sleep(for: Self.peekDelay)
            }
            guard !Task.isCancelled, let self else { return }
            let image = await self.thumbnailService.captureFullSize(window)
            guard !Task.isCancelled, self.hoveredWindowID == id, self.panel.isVisible else { return }
            guard let image else { return self.peek.hide() }
            self.peek.show(image, frame: window.frame)
        }
    }

    private func endPeek() {
        peekTask?.cancel()
        peekTask = nil
        peek.hide()
    }

    // MARK: - Tracking

    private func startTracking() {
        outsideSince = nil
        if trackingTimer == nil {
            trackingTimer = Timer.scheduledTimer(withTimeInterval: 1 / 30, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.track() }
            }
        }
        if middleClickMonitor == nil {
            // Middle-click on a thumbnail closes that window, like in the Windows taskbar.
            middleClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .otherMouseDown) { [weak self] event in
                guard event.buttonNumber == 2,
                      MainActor.assumeIsolated({ self?.preferences.isMiddleClickCloseEnabled == true })
                else { return event }
                let handled = MainActor.assumeIsolated { self?.closeHoveredWindow() ?? false }
                return handled ? nil : event
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
        if let middleClickMonitor { NSEvent.removeMonitor(middleClickMonitor) }
        middleClickMonitor = nil
        hoveredWindowID = nil
        endPeek()
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
        let box = preferences.thumbnailSize.box
        content = PreviewContent(
            appIcon: NSWorkspace.shared.icon(forFile: "/System/Applications/Notes.app"),
            rows: PreviewView.rows(for: windows, in: box, maxWidth: screen.frame.width - PreviewLayout.margin * 2),
            thumbnails: DemoData.thumbnails(for: windows) { PreviewView.thumbnailSize(for: $0, in: box) },
            box: box
        )
        let icon = CGRect(x: screen.frame.midX - 32, y: screen.frame.minY + 4, width: 64, height: 64)
        panel.show(view, near: icon)
    }
    #endif
}
