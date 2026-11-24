import AppKit
import ApplicationServices

@MainActor
enum WindowProvider {
    /// Ignore tiny helper windows (tooltips, invisible utility windows, …).
    private static let minimumSize: CGFloat = 50
    /// Keeps the Dock responsive if the target app hangs.
    private static let messagingTimeout: Float = 0.3

    /// Standard windows of `app` on the current Space, including minimized ones, front to back.
    static func windows(of app: NSRunningApplication) -> [WindowInfo] {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, messagingTimeout)
        let fallbackTitle = app.localizedName ?? ""

        return appElement.elements(kAXWindowsAttribute).compactMap { window in
            guard
                window.role == kAXWindowRole,
                let subrole = window.subrole,
                [kAXStandardWindowSubrole, kAXDialogSubrole].contains(subrole),
                let id = window.windowID
            else { return nil }

            if let size = window.size(kAXSizeAttribute),
               size.width < minimumSize || size.height < minimumSize {
                return nil
            }

            let title = window.title.flatMap { $0.isEmpty ? nil : $0 } ?? fallbackTitle
            return WindowInfo(
                id: id,
                element: window,
                title: title,
                isMinimized: window.bool(kAXMinimizedAttribute) ?? false
            )
        }
    }
}
