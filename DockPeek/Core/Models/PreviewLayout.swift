import CoreGraphics

/// The screen edge the Dock sits on.
enum DockEdge: Equatable, Sendable {
    case bottom, left, right
}

/// Pure geometry for placing the preview panel next to a Dock icon.
/// All rects use Cocoa screen coordinates (origin bottom-left of the primary display).
enum PreviewLayout {
    /// Space between the Dock icon and the panel.
    static let gap: CGFloat = 10
    /// Minimum distance between the panel and the screen edges.
    static let margin: CGFloat = 8

    /// The Dock edge is the screen edge closest to the icon.
    static func edge(of icon: CGRect, on screen: CGRect) -> DockEdge {
        let bottom = icon.minY - screen.minY
        let left = icon.minX - screen.minX
        let right = screen.maxX - icon.maxX
        if bottom <= left, bottom <= right { return .bottom }
        return left <= right ? .left : .right
    }

    /// Origin of a panel of `size` next to `icon`, centered on it and kept on `screen`.
    static func origin(for size: CGSize, icon: CGRect, screen: CGRect, edge: DockEdge) -> CGPoint {
        switch edge {
        case .bottom:
            CGPoint(
                x: clamp(icon.midX - size.width / 2, screen.minX + margin, screen.maxX - margin - size.width),
                y: icon.maxY + gap
            )
        case .left:
            CGPoint(
                x: icon.maxX + gap,
                y: clamp(icon.midY - size.height / 2, screen.minY + margin, screen.maxY - margin - size.height)
            )
        case .right:
            CGPoint(
                x: icon.minX - gap - size.width,
                y: clamp(icon.midY - size.height / 2, screen.minY + margin, screen.maxY - margin - size.height)
            )
        }
    }

    /// Size of a thumbnail for a window of `windowSize`, fitted into `box` without upscaling.
    static func thumbnailSize(for windowSize: CGSize, in box: CGSize) -> CGSize {
        guard windowSize.width > 0, windowSize.height > 0 else { return box }
        let scale = min(box.width / windowSize.width, box.height / windowSize.height, 1)
        return CGSize(width: (windowSize.width * scale).rounded(), height: (windowSize.height * scale).rounded())
    }

    /// Converts a rect from Accessibility coordinates (origin top-left of the primary display)
    /// to Cocoa coordinates.
    static func cocoaRect(fromAccessibility rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryScreenHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    private static func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        // A panel wider than the screen starts at the left margin.
        guard upper >= lower else { return lower }
        return min(max(value, lower), upper)
    }
}
