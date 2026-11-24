import AppKit

/// Converts between Accessibility coordinates (origin top-left of the primary screen, y down)
/// and Cocoa coordinates (origin bottom-left of the primary screen, y up).
@MainActor
enum ScreenGeometry {
    static func cocoaRect(fromAccessibility rect: CGRect) -> CGRect {
        guard let primary = NSScreen.screens.first else { return rect }
        return CGRect(x: rect.minX, y: primary.frame.maxY - rect.maxY, width: rect.width, height: rect.height)
    }

    static func screen(containing rect: CGRect) -> NSScreen? {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        return NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main
    }
}
