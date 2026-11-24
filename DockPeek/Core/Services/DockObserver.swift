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
    private var relaunchObserver: NSObjectProtocol?

    private nonisolated static let dockBundleID = "com.apple.dock"

    func start() {
        attach()
        // The Dock restarts after some settings changes; attach to the new process.
        relaunchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard app?.bundleIdentifier == Self.dockBundleID else { return }
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(1))
                self?.attach()
            }
        }
    }

    func stop() {
        detach()
        if let relaunchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(relaunchObserver)
        }
        relaunchObserver = nil
    }

    /// The app icon currently under the pointer, read straight from the Dock.
    func currentItem() -> DockItem? {
        guard let list else { return nil }
        return AX.elements(list, kAXSelectedChildrenAttribute).first.flatMap(Self.item(for:))
    }

    private func attach() {
        detach()
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: Self.dockBundleID).first else {
            log.error("Dock process not found")
            return
        }
        let app = AXUIElementCreateApplication(dock.processIdentifier)
        guard let list = AX.elements(app, kAXChildrenAttribute).first(where: {
            AX.attribute($0, kAXRoleAttribute, as: String.self) == kAXListRole
        }) else {
            log.error("Dock icon list not found, trusted: \(AXIsProcessTrusted())")
            return
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
            return
        }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let added = AXObserverAddNotification(observer, list, kAXSelectedChildrenChangedNotification as CFString, refcon)
        log.info("Attached to Dock list, add notification: \(added.rawValue)")
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        self.observer = observer
        self.list = list
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
