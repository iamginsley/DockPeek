import AppKit
import SwiftUI

/// Connects Dock hover events with the preview panel: shows it after a short delay,
/// loads thumbnails, hides it when the mouse leaves both the icon and the panel,
/// and handles focusing / closing windows.
@MainActor
final class PreviewCoordinator {
    private enum Timing {
        /// Small delay so sweeping across the Dock doesn't flash previews.
        static let showDelay: Duration = .milliseconds(120)
        /// Grace period for moving the mouse from the icon to the panel.
        static let hideGrace: TimeInterval = 0.3
        static let mousePollInterval: TimeInterval = 0.08
        /// Time for an app to actually close a window before re-reading the list.
        static let closeSettleDelay: Duration = .milliseconds(250)
    }

    private enum DefaultsKey {
        static let isEnabled = "previewEnabled"
    }

    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: DefaultsKey.isEnabled)
            if !isEnabled { hide() }
        }
    }

    private let dockObserver = DockObserver()
    private let thumbnailService = ThumbnailService()
    private let model = PreviewModel()
    private lazy var panel = PreviewPanel(
        rootView: PreviewView(
            model: model,
            onSelect: { [weak self] window in self?.select(window) },
            onClose: { [weak self] window in self?.close(window) }
        )
    )

    private var currentItem: DockItem?
    private var orientation: DockOrientation = .bottom
    private var showTask: Task<Void, Never>?
    private var thumbnailTask: Task<Void, Never>?
    private var mousePollTimer: Timer?
    private var mouseOutsideSince: Date?
    private var eventMonitors: [Any] = []

    init() {
        UserDefaults.standard.register(defaults: [DefaultsKey.isEnabled: true])
        isEnabled = UserDefaults.standard.bool(forKey: DefaultsKey.isEnabled)
    }

    func start() {
        dockObserver.onHoverChanged = { [weak self] item in
            self?.dockHoverChanged(item)
        }
        dockObserver.start()
        installEventMonitors()
    }

    // MARK: - Showing

    private func dockHoverChanged(_ item: DockItem?) {
        showTask?.cancel()
        guard isEnabled, let item else { return } // leaving is handled by mouse tracking

        if panel.isVisible {
            // Switching between icons while a preview is open feels instant, like Windows.
            show(item)
            return
        }
        showTask = Task { [weak self] in
            try? await Task.sleep(for: Timing.showDelay)
            guard !Task.isCancelled else { return }
            self?.show(item)
        }
    }

    private func show(_ item: DockItem) {
        let isSameApp = panel.isVisible && currentItem?.app == item.app
        orientation = DockOrientation(iconFrame: item.iconFrame)
        let axis: Axis = orientation == .bottom ? .horizontal : .vertical

        var windows = WindowProvider.windows(of: item.app)
        guard !windows.isEmpty else {
            hide()
            return
        }
        if let screen = ScreenGeometry.screen(containing: item.iconFrame) {
            let length = axis == .horizontal ? screen.frame.width : screen.frame.height
            let available = length - 2 * PreviewMetrics.screenMargin
            windows = Array(windows.prefix(PreviewMetrics.maxItemCount(fitting: available, axis: axis)))
        }

        currentItem = item
        if !isSameApp {
            model.hoveredWindowID = nil
            model.thumbnails = [:]
        }
        model.appIcon = item.app.icon
        model.axis = axis
        model.windows = windows

        layoutPanel()
        panel.orderFrontRegardless()
        startMouseTracking()

        if !isSameApp {
            loadThumbnails(for: windows, of: item.app)
        }
    }

    private func layoutPanel() {
        guard let item = currentItem else { return }
        let icon = item.iconFrame
        let size = PreviewMetrics.panelSize(itemCount: model.windows.count, axis: model.axis)
        let gap = PreviewMetrics.dockGap

        var origin: CGPoint
        switch orientation {
        case .bottom:
            origin = CGPoint(x: icon.midX - size.width / 2, y: icon.maxY + gap)
        case .left:
            origin = CGPoint(x: icon.maxX + gap, y: icon.midY - size.height / 2)
        case .right:
            origin = CGPoint(x: icon.minX - gap - size.width, y: icon.midY - size.height / 2)
        }

        if let screen = ScreenGeometry.screen(containing: icon) {
            let bounds = screen.frame.insetBy(dx: PreviewMetrics.screenMargin, dy: PreviewMetrics.screenMargin)
            origin.x = min(max(origin.x, bounds.minX), bounds.maxX - size.width)
            origin.y = min(max(origin.y, bounds.minY), bounds.maxY - size.height)
        }

        panel.setFrame(CGRect(origin: origin, size: size), display: true)
        panel.invalidateShadow()
    }

    private func loadThumbnails(for windows: [WindowInfo], of app: NSRunningApplication) {
        thumbnailTask?.cancel()

        let allIDs = windows.map(\.id)
        // Minimized windows and windows of hidden apps can't be captured; they keep their cached image.
        let capturableIDs = app.isHidden ? [] : windows.filter { !$0.isMinimized }.map(\.id)
        let canCapture = CGPreflightScreenCaptureAccess()
        let service = thumbnailService
        let maxSize = PreviewMetrics.thumbnailSize

        thumbnailTask = Task { [weak self] in
            for id in allIDs {
                if let cached = await service.cached(id) {
                    self?.model.thumbnails[id] = cached.image
                }
            }
            guard canCapture, await service.refreshShareableContent() else { return }
            for id in capturableIDs {
                guard !Task.isCancelled else { return }
                if let thumbnail = await service.thumbnail(for: id, fitting: maxSize) {
                    self?.model.thumbnails[id] = thumbnail.image
                }
            }
        }
    }

    // MARK: - Hiding

    func hide() {
        showTask?.cancel()
        thumbnailTask?.cancel()
        stopMouseTracking()
        panel.orderOut(nil)
        currentItem = nil
        model.hoveredWindowID = nil
    }

    /// Polls the mouse only while the panel is visible. Simpler and more robust than tracking
    /// areas across two processes (Dock + panel), and cheap at ~12 Hz.
    private func startMouseTracking() {
        mouseOutsideSince = nil
        guard mousePollTimer == nil else { return }
        mousePollTimer = Timer.scheduledTimer(withTimeInterval: Timing.mousePollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkMouseLocation() }
        }
    }

    private func stopMouseTracking() {
        mousePollTimer?.invalidate()
        mousePollTimer = nil
        mouseOutsideSince = nil
    }

    private func checkMouseLocation() {
        let mouse = NSEvent.mouseLocation
        let isOverPanel = panel.frame.insetBy(dx: -6, dy: -6).contains(mouse)
        let isOverIcon = dockObserver.hoveredItem != nil && dockObserver.hoveredItem?.app == currentItem?.app

        if isOverPanel || isOverIcon {
            mouseOutsideSince = nil
            return
        }
        guard let since = mouseOutsideSince else {
            mouseOutsideSince = Date()
            return
        }
        if Date().timeIntervalSince(since) >= Timing.hideGrace {
            hide()
        }
    }

    // MARK: - Window actions

    private func select(_ window: WindowInfo) {
        guard let app = currentItem?.app else { return }
        hide()
        WindowActions.focus(window, of: app)
    }

    private func close(_ window: WindowInfo) {
        guard let item = currentItem else { return }
        WindowActions.close(window)

        Task { [weak self] in
            try? await Task.sleep(for: Timing.closeSettleDelay)
            guard let self, self.panel.isVisible, self.currentItem?.app == item.app else { return }
            self.refreshWindows()
        }
    }

    private func refreshWindows() {
        guard let item = currentItem else { return }
        let windows = WindowProvider.windows(of: item.app)
        guard !windows.isEmpty else {
            hide()
            return
        }
        model.windows = windows
        layoutPanel()
    }

    // MARK: - Global events

    private func installEventMonitors() {
        guard eventMonitors.isEmpty else { return }

        // Clicks anywhere else (including the Dock icon itself, or a right-click for the Dock menu)
        // dismiss the preview, like on Windows.
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.hide() }
        }) {
            eventMonitors.append(monitor)
        }

        // Middle-click on a thumbnail closes that window.
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: .otherMouseDown, handler: { [weak self] event in
            let isMiddleButton = event.buttonNumber == 2
            let handled = MainActor.assumeIsolated { () -> Bool in
                guard isMiddleButton, let self, let id = self.model.hoveredWindowID,
                      let window = self.model.windows.first(where: { $0.id == id }) else { return false }
                self.close(window)
                return true
            }
            return handled ? nil : event
        }) {
            eventMonitors.append(monitor)
        }
    }
}
