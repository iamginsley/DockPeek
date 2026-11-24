import AppKit
import ApplicationServices

/// Watches the Dock via Accessibility. The Dock updates the "selected children" of its
/// icon list while the mouse moves over it, so one notification gives us hover in/out
/// without polling the mouse position.
@MainActor
final class DockObserver {
    // nonisolated: also read from the Sendable NSWorkspace notification closure.
    private nonisolated static let dockBundleIdentifier = "com.apple.dock"

    var onHoverChanged: (@MainActor (DockItem?) -> Void)?
    private(set) var hoveredItem: DockItem?

    private var observer: AXObserver?
    private var dockList: AXUIElement?
    private var retryTask: Task<Void, Never>?
    private var relaunchToken: NSObjectProtocol?

    func start() {
        stop()
        observeDockRelaunch()

        guard
            let dock = NSRunningApplication.runningApplications(withBundleIdentifier: Self.dockBundleIdentifier).first
        else {
            scheduleRetry()
            return
        }

        let pid = dock.processIdentifier
        let dockElement = AXUIElementCreateApplication(pid)
        guard let list = dockElement.elements(kAXChildrenAttribute).first(where: { $0.role == kAXListRole }) else {
            scheduleRetry()
            return
        }

        var newObserver: AXObserver?
        guard AXObserverCreate(pid, dockSelectionCallback, &newObserver) == .success, let newObserver else {
            scheduleRetry()
            return
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let result = AXObserverAddNotification(
            newObserver, list, kAXSelectedChildrenChangedNotification as CFString, refcon
        )
        guard result == .success else {
            scheduleRetry()
            return
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(newObserver), .commonModes)
        observer = newObserver
        dockList = list
    }

    func stop() {
        retryTask?.cancel()
        retryTask = nil
        if let observer {
            if let dockList {
                AXObserverRemoveNotification(observer, dockList, kAXSelectedChildrenChangedNotification as CFString)
            }
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observer = nil
        dockList = nil
        updateHoveredItem(nil)
    }

    // MARK: - Notification handling

    fileprivate func selectionDidChange() {
        updateHoveredItem(dockList.flatMap { currentItem(in: $0) })
    }

    private func updateHoveredItem(_ item: DockItem?) {
        guard item != hoveredItem else { return }
        hoveredItem = item
        onHoverChanged?(item)
    }

    private func currentItem(in list: AXUIElement) -> DockItem? {
        guard
            let selected = list.elements(kAXSelectedChildrenAttribute).first,
            selected.subrole == "AXApplicationDockItem",
            let axFrame = selected.frame
        else { return nil }

        let title = selected.title ?? ""
        guard let app = runningApplication(url: selected.url(kAXURLAttribute), title: title) else { return nil }
        return DockItem(app: app, title: title, iconFrame: ScreenGeometry.cocoaRect(fromAccessibility: axFrame))
    }

    private func runningApplication(url: URL?, title: String) -> NSRunningApplication? {
        let apps = NSWorkspace.shared.runningApplications
        if let url {
            let target = url.standardizedFileURL.resolvingSymlinksInPath()
            if let match = apps.first(where: { $0.bundleURL?.standardizedFileURL.resolvingSymlinksInPath() == target }) {
                return match
            }
        }
        return apps.first { $0.localizedName == title }
    }

    // MARK: - Resilience

    /// The Dock restarts after `killall Dock` or certain settings changes; re-attach then.
    private func observeDockRelaunch() {
        guard relaunchToken == nil else { return }
        relaunchToken = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard app?.bundleIdentifier == Self.dockBundleIdentifier else { return }
            MainActor.assumeIsolated { self?.scheduleRetry() }
        }
    }

    private func scheduleRetry() {
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.start()
        }
    }
}

/// C callback for the AXObserver. Delivered on the main run loop (see `CFRunLoopAddSource`).
private func dockSelectionCallback(
    _ observer: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ refcon: UnsafeMutableRawPointer?
) {
    guard let refcon else { return }
    let dockObserver = Unmanaged<DockObserver>.fromOpaque(refcon).takeUnretainedValue()
    MainActor.assumeIsolated { dockObserver.selectionDidChange() }
}
