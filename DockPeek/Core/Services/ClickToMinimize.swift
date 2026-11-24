import AppKit
import ApplicationServices

/// Clicking the Dock icon of the app that is already in front minimizes its front window,
/// like clicking the active app in the Windows taskbar. A second click restores it (the Dock
/// does that on its own).
///
/// Global mouse events arrive slightly late, so everything is judged by the state at the
/// moment of the press: the app must have been in front before the press (not brought there
/// by this click), and its front window must have been open (not one the Dock is restoring).
@MainActor
final class ClickToMinimize {
    /// Moving further than this between press and release counts as dragging the icon.
    static let dragTolerance: CGFloat = 5

    private let dock: DockObserver
    private let preferences: Preferences
    private var monitor: Any?
    private var activationObserver: NSObjectProtocol?
    /// When the frontmost app came to the front, in system uptime (same clock as event timestamps).
    private var frontmostSince: (pid: pid_t, uptime: TimeInterval)?
    /// The window to minimize, chosen at press time.
    private var pressed: (app: NSRunningApplication, window: AXUIElement, location: CGPoint)?

    init(dock: DockObserver, preferences: Preferences) {
        self.dock = dock
        self.preferences = preferences
    }

    func start() {
        guard monitor == nil else { return }
        if let app = NSWorkspace.shared.frontmostApplication {
            frontmostSince = (app.processIdentifier, 0)
        }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let uptime = ProcessInfo.processInfo.systemUptime
            MainActor.assumeIsolated {
                guard let app else { return }
                self?.frontmostSince = (app.processIdentifier, uptime)
            }
        }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { [weak self] event in
            let type = event.type
            let timestamp = event.timestamp
            MainActor.assumeIsolated { self?.handle(type, at: timestamp) }
        }
    }

    private func handle(_ type: NSEvent.EventType, at timestamp: TimeInterval) {
        guard preferences.isClickToMinimizeEnabled else { return }
        let location = NSEvent.mouseLocation
        switch type {
        case .leftMouseDown:
            pressed = nil
            guard let item = dock.currentItem(),
                  item.frame.contains(location),
                  let since = frontmostSince,
                  since.pid == item.app.processIdentifier,
                  since.uptime < timestamp,
                  let window = WindowService.openFrontWindow(of: item.app)
            else { return }
            pressed = (item.app, window, location)
        case .leftMouseUp:
            defer { pressed = nil }
            guard let pressed,
                  hypot(location.x - pressed.location.x, location.y - pressed.location.y) <= Self.dragTolerance,
                  dock.currentItem()?.app == pressed.app
            else { return }
            WindowService.minimize(pressed.window)
        default:
            break
        }
    }
}
