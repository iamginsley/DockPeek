import AppKit
import SwiftUI

/// Borderless floating panel above the Dock that never takes focus from the app in front.
@MainActor
final class PreviewPanel: NSPanel {
    private let hostingView = FirstMouseHostingView(rootView: AnyView(EmptyView()))

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isFloatingPanel = true
        // Above the Dock (which sits at the Dock window level).
        level = .popUpMenu
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        contentView = hostingView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Replaces the content and places the panel next to `icon` on the screen that holds it.
    func show(_ view: some View, near icon: CGRect) {
        hostingView.rootView = AnyView(view)
        hostingView.layoutSubtreeIfNeeded()
        let size = hostingView.fittingSize
        let screen = NSScreen.screens.first { $0.frame.intersects(icon) } ?? NSScreen.main
        guard let screenFrame = screen?.frame else { return }
        let edge = PreviewLayout.edge(of: icon, on: screenFrame)
        let origin = PreviewLayout.origin(for: size, icon: icon, screen: screenFrame, edge: edge)
        setFrame(CGRect(origin: origin, size: size), display: true)

        if !isVisible {
            alphaValue = 0
            orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                animator().alphaValue = 1
            }
        }
    }

    /// Updates the content without moving the panel, e.g. when thumbnails arrive.
    func update(_ view: some View) {
        hostingView.rootView = AnyView(view)
    }

    func hide() {
        orderOut(nil)
    }
}

/// Lets the first click on a thumbnail act right away, although the panel is never key.
private final class FirstMouseHostingView: NSHostingView<AnyView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
