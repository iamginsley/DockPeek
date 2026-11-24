import AppKit
import ApplicationServices

/// One window of an app, as shown in the preview.
struct AppWindow: Identifiable {
    let id: CGWindowID
    let title: String
    let size: CGSize
    let isMinimized: Bool
    /// Nil for demo windows.
    let element: AXUIElement?
}

/// The Dock icon the pointer is over.
struct DockItem: Equatable {
    let app: NSRunningApplication
    /// Icon frame in Cocoa screen coordinates.
    let frame: CGRect
}
