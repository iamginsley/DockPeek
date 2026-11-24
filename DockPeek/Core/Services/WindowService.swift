import AppKit
import ApplicationServices

/// Lists an app's windows and acts on them through Accessibility.
@MainActor
enum WindowService {
    /// Standard windows of `app` in the current Space, including minimized ones, front to back.
    static func windows(of app: NSRunningApplication) -> [AppWindow] {
        let element = AXUIElementCreateApplication(app.processIdentifier)
        return AX.elements(element, kAXWindowsAttribute).compactMap { window in
            let isMinimized = AX.attribute(window, kAXMinimizedAttribute, as: Bool.self) ?? false
            let subrole = AX.attribute(window, kAXSubroleAttribute, as: String.self)
            // Minimized windows report the subrole AXDialog instead of AXStandardWindow.
            guard AX.attribute(window, kAXRoleAttribute, as: String.self) == kAXWindowRole,
                  subrole == kAXStandardWindowSubrole || isMinimized,
                  let id = AX.windowID(window),
                  let size = AX.size(window), size.width > 40, size.height > 40
            else { return nil }
            let title = AX.attribute(window, kAXTitleAttribute, as: String.self) ?? ""
            return AppWindow(
                id: id,
                title: title.isEmpty ? (app.localizedName ?? "") : title,
                size: size,
                isMinimized: isMinimized,
                element: window
            )
        }
    }

    /// The app's focused (or main) window, if it is a standard window that is open right now.
    static func openFrontWindow(of app: NSRunningApplication) -> AXUIElement? {
        let element = AXUIElementCreateApplication(app.processIdentifier)
        guard let window = AX.attribute(element, kAXFocusedWindowAttribute, as: AXUIElement.self)
                ?? AX.attribute(element, kAXMainWindowAttribute, as: AXUIElement.self),
              AX.attribute(window, kAXMinimizedAttribute, as: Bool.self) == false,
              AX.attribute(window, kAXSubroleAttribute, as: String.self) == kAXStandardWindowSubrole
        else { return nil }
        return window
    }

    static func minimize(_ window: AXUIElement) {
        AX.set(window, kAXMinimizedAttribute, kCFBooleanTrue)
    }

    /// Brings the window to the front, restoring it from the Dock if it was minimized.
    static func focus(_ window: AppWindow, of app: NSRunningApplication) {
        guard let element = window.element else { return }
        if window.isMinimized {
            AX.set(element, kAXMinimizedAttribute, kCFBooleanFalse)
        }
        AX.set(element, kAXMainAttribute, kCFBooleanTrue)
        AX.perform(element, kAXRaiseAction)
        app.activate()
    }

    /// Presses the window's close button, so the app can still ask about unsaved changes.
    static func close(_ window: AppWindow) {
        guard let element = window.element,
              let button = AX.attribute(element, kAXCloseButtonAttribute, as: AXUIElement.self)
        else { return }
        AX.perform(button, kAXPressAction)
    }
}
