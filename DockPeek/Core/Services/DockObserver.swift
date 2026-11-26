import AppKit
import ApplicationServices
import OSLog

let log = Logger(subsystem: "com.iamginsley.dockpeek", category: "dock")

/// Watches the Dock through Accessibility and reports which app icon the pointer is over.
///
/// The Dock marks the icon under the pointer as the selected child of its icon list and posts
/// `kAXSelectedChildrenChangedNotification` whenever that changes, so no mouse polling is needed.
@MainActor
final class DockObserver {
    /// Called with the hovered running app, or nil when the pointer leaves the app icons.
    var onHover: ((DockItem?) -> Void)?

    private var observer: AXObserver?
    private var list: AXUIElement?
    private var appsObservation: NSKeyValueObservation?
    /// The Dock process the observer belongs to, or is being attached to.
    private var dockPID: pid_t?
    private var reattachTask: Task<Void, Never>?

    private nonisolated static let dockBundleID = "com.apple.dock"

    func start() {
        reattach()
        // The Dock restarts after some settings changes (and when it crashes). Its old
        // Accessibility elements die with it, so attach to the new process. NSWorkspace posts
        // no launch or terminate notifications for the Dock, but its running-app list changes.
        appsObservation = NSWorkspace.shared.observe(\.runningApplications) { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.checkDockProcess() }
        }
    }

    func stop() {
        reattachTask?.cancel()
        reattachTask = nil
        detach()
        appsObservation?.invalidate()
        appsObservation = nil
    }

    /// Attaches to the Dock, retrying for a while: a freshly launched Dock needs a moment
    /// before its icon list shows up in Accessibility.
    func reattach() {
        reattachTask?.cancel()
        dockPID = Self.dockProcess()?.processIdentifier
        reattachTask = Task { [weak self] in
            for attempt in 1...Self.attachAttempts {
                guard let self, !Task.isCancelled else { return }
                if self.attach() {
                    if attempt > 1 { log.info("Attached to Dock after \(attempt) attempts") }
                    return
                }
                try? await Task.sleep(for: Self.attachRetryInterval)
            }
            log.error("Giving up attaching to the Dock")
            // Try again on the next change to the running apps.
            self?.dockPID = nil
        }
    }

    static let attachAttempts = 20
    static let attachRetryInterval: Duration = .milliseconds(500)

    /// Reattaches when the Dock process is gone or a new one has started.
    private func checkDockProcess() {
        let pid = Self.dockProcess()?.processIdentifier
        guard pid != dockPID else { return }
        onHover?(nil)
        if pid == nil {
            log.info("Dock terminated")
            reattachTask?.cancel()
            detach()
            dockPID = nil
        } else {
            log.info("Dock (re)started, attaching to the new process")
            reattach()
        }
    }

    private static func dockProcess() -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: dockBundleID).first { !$0.isTerminated }
    }

    /// The app icon currently under the pointer, read straight from the Dock.
    func currentItem() -> DockItem? {
        guard let list else { return nil }
        return AX.elements(list, kAXSelectedChildrenAttribute).first.flatMap(Self.item(for:))
    }

    /// Returns whether the observer is in place.
    @discardableResult
    private func attach() -> Bool {
        detach()
        guard let dock = Self.dockProcess() else {
            log.error("Dock process not found")
            return false
        }
        let app = AXUIElementCreateApplication(dock.processIdentifier)
        guard let list = AX.elements(app, kAXChildrenAttribute).first(where: {
            AX.attribute($0, kAXRoleAttribute, as: String.self) == kAXListRole
        }) else {
            log.error("Dock icon list not found, trusted: \(AXIsProcessTrusted())")
            return false
        }

        var observer: AXObserver?
        let callback: AXObserverCallback = { _, _, _, refcon in
            guard let refcon else { return }
            let dockObserver = Unmanaged<DockObserver>.fromOpaque(refcon).takeUnretainedValue()
            // The observer's run loop source is on the main run loop.
            MainActor.assumeIsolated { dockObserver.selectionChanged() }
        }
        let created = AXObserverCreate(dock.processIdentifier, callback, &observer)
        guard created == .success, let observer else {
            log.error("AXObserverCreate failed: \(created.rawValue)")
            return false
        }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let added = AXObserverAddNotification(observer, list, kAXSelectedChildrenChangedNotification as CFString, refcon)
        log.info("Attached to Dock list, add notification: \(added.rawValue)")
        guard added == .success else { return false }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        self.observer = observer
        self.list = list
        return true
    }

    private func detach() {
        if let observer, let list {
            AXObserverRemoveNotification(observer, list, kAXSelectedChildrenChangedNotification as CFString)
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
        observer = nil
        list = nil
    }

    private func selectionChanged() {
        let item = currentItem()
        if let list, item == nil, let element = AX.elements(list, kAXSelectedChildrenAttribute).first {
            let subrole = AX.attribute(element, kAXSubroleAttribute, as: String.self) ?? "-"
            let running = AX.attribute(element, "AXIsApplicationRunning", as: Bool.self).map(String.init) ?? "-"
            let url = AX.attribute(element, kAXURLAttribute, as: URL.self)?.path ?? "-"
            log.debug("Hover on non-app item: subrole \(subrole), running \(running), url \(url)")
        } else {
            log.debug("Hover: \(item?.app.localizedName ?? "none")")
        }
        onHover?(item)
    }

    /// A Dock icon of a running app, with its frame. Folders, Trash and apps that are not
    /// running return nil.
    private static func item(for element: AXUIElement) -> DockItem? {
        guard AX.attribute(element, kAXSubroleAttribute, as: String.self) == "AXApplicationDockItem",
              AX.attribute(element, "AXIsApplicationRunning", as: Bool.self) == true,
              let url = AX.attribute(element, kAXURLAttribute, as: URL.self),
              let axFrame = AX.frame(element),
              let primary = NSScreen.screens.first
        else { return nil }
        let path = url.standardizedFileURL.path
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleURL?.standardizedFileURL.path == path
        }) else { return nil }
        let frame = PreviewLayout.cocoaRect(fromAccessibility: axFrame, primaryScreenHeight: primary.frame.height)
        return DockItem(app: app, frame: frame)
    }
}
