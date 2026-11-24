#if DEBUG
import AppKit

/// Sample windows for `-DockPeekDemo` (screenshots and UI checks without a real Dock hover).
@MainActor
enum DemoData {
    static let windows: [AppWindow] = [
        AppWindow(id: 900_001, title: "Einkaufsliste", size: CGSize(width: 900, height: 640), isMinimized: false, element: nil),
        AppWindow(id: 900_002, title: "Urlaub Gardasee – Packliste", size: CGSize(width: 1200, height: 800), isMinimized: false, element: nil),
        AppWindow(id: 900_003, title: "Ideen für DockPeek", size: CGSize(width: 700, height: 900), isMinimized: true, element: nil),
    ]

    /// Simple drawn stand-ins for window content.
    static func thumbnails(for windows: [AppWindow], size: (AppWindow) -> CGSize) -> [CGWindowID: NSImage] {
        var images: [CGWindowID: NSImage] = [:]
        for (index, window) in windows.enumerated() where !window.isMinimized {
            let tint: NSColor = [.systemYellow, .systemBlue, .systemGreen][index % 3]
            images[window.id] = NSImage(size: size(window), flipped: true) { rect in
                NSColor.textBackgroundColor.setFill()
                NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6).fill()
                NSColor.windowBackgroundColor.setFill()
                NSRect(x: 0, y: 0, width: rect.width, height: 18).fill()
                for (dot, color) in [NSColor.systemRed, .systemOrange, .systemGreen].enumerated() {
                    color.setFill()
                    NSBezierPath(ovalIn: NSRect(x: 8 + CGFloat(dot) * 12, y: 5, width: 8, height: 8)).fill()
                }
                tint.withAlphaComponent(0.7).setFill()
                NSRect(x: 12, y: 30, width: rect.width * 0.5, height: 10).fill()
                NSColor.tertiaryLabelColor.setFill()
                for line in 0..<6 {
                    NSRect(x: 12, y: 52 + CGFloat(line) * 14, width: rect.width * (line % 2 == 0 ? 0.8 : 0.6), height: 6).fill()
                }
                return true
            }
        }
        return images
    }
}
#endif
