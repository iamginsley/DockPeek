import AppKit

/// A running application's icon in the Dock that the mouse is currently over.
struct DockItem: Equatable {
    let app: NSRunningApplication
    let title: String
    /// Icon frame in Cocoa screen coordinates.
    let iconFrame: CGRect
}

/// Which screen edge the Dock sits on, derived from the hovered icon's position.
enum DockOrientation {
    case bottom, left, right

    @MainActor
    init(iconFrame: CGRect) {
        guard let screen = ScreenGeometry.screen(containing: iconFrame) else {
            self = .bottom
            return
        }
        let frame = screen.frame
        let toBottom = iconFrame.minY - frame.minY
        let toLeft = iconFrame.minX - frame.minX
        let toRight = frame.maxX - iconFrame.maxX

        if toBottom <= toLeft, toBottom <= toRight {
            self = .bottom
        } else if toLeft <= toRight {
            self = .left
        } else {
            self = .right
        }
    }
}
