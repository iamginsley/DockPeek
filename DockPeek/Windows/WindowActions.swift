import AppKit
import ApplicationServices

@MainActor
enum WindowActions {
    /// Brings exactly this window to the front, restoring it if minimized or hidden.
    static func focus(_ window: WindowInfo, of app: NSRunningApplication) {
        if app.isHidden {
            app.unhide()
        }
        if window.isMinimized {
            window.element.set(kAXMinimizedAttribute, kCFBooleanFalse)
        }

        // Setting AXFrontmost works from a background app, unlike NSRunningApplication.activate()
        // which macOS 14+ may refuse under cooperative activation.
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        appElement.set(kAXFrontmostAttribute, kCFBooleanTrue)
        window.element.set(kAXMainAttribute, kCFBooleanTrue)
        window.element.perform(kAXRaiseAction)
    }

    /// Presses the window's close button, so the app can still ask about unsaved changes.
    static func close(_ window: WindowInfo) {
        window.element.element(kAXCloseButtonAttribute)?.perform(kAXPressAction)
    }
}
