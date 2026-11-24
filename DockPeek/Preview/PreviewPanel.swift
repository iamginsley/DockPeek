import AppKit
import SwiftUI

/// Borderless floating panel above the Dock that never activates DockPeek,
/// so the app the user is working in keeps focus.
final class PreviewPanel: NSPanel {
    convenience init(rootView: PreviewView) {
        self.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        isFloatingPanel = true
        level = .popUpMenu // above the Dock (kCGDockWindowLevel)
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]

        let hostingView = FirstMouseHostingView(rootView: rootView)
        // The panel size is set explicitly from PreviewMetrics; don't let SwiftUI resize the window.
        hostingView.sizingOptions = []
        contentView = hostingView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Lets the first click on a thumbnail act immediately instead of only focusing the panel.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
