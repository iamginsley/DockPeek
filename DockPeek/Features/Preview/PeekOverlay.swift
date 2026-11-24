import AppKit
import SwiftUI

/// Aero Peek: frosts everything on screen and shows one window at its real place.
///
/// macOS has no public way to make other apps' windows transparent, so the overlay covers
/// each screen just below the Dock (the Dock and the preview stay on top) and draws a
/// snapshot of the peeked window where it really is.
@MainActor
final class PeekOverlay {
    private var panels: [NSPanel] = []

    func show(_ image: NSImage?, frame: CGRect?) {
        hide()
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        for screen in NSScreen.screens {
            let panel = Self.makePanel(for: screen)
            let snapshot = frame.flatMap { frame -> PeekView.Snapshot? in
                guard let image, frame.intersects(screen.frame) else { return nil }
                // SwiftUI draws from the top-left of the screen.
                let local = CGRect(
                    x: frame.minX - screen.frame.minX,
                    y: screen.frame.maxY - frame.maxY,
                    width: frame.width,
                    height: frame.height
                )
                return PeekView.Snapshot(image: image, frame: local)
            }
            panel.contentView = NSHostingView(rootView: PeekView(snapshot: snapshot))
            panel.alphaValue = reduceMotion ? 1 : 0
            panel.orderFrontRegardless()
            if !reduceMotion {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.18
                    panel.animator().alphaValue = 1
                }
            }
            panels.append(panel)
        }
    }

    func hide() {
        for panel in panels { panel.orderOut(nil) }
        panels.removeAll()
    }

    var isVisible: Bool { !panels.isEmpty }

    private static func makePanel(for screen: NSScreen) -> NSPanel {
        let panel = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        // Right below the Dock, so the Dock and the preview panel stay visible.
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) - 1)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.setFrame(screen.frame, display: false)
        return panel
    }
}

private struct PeekView: View {
    struct Snapshot {
        let image: NSImage
        let frame: CGRect
    }

    let snapshot: Snapshot?

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack(alignment: .topLeading) {
            if reduceTransparency {
                Color.black.opacity(0.6)
            } else {
                Rectangle().fill(.ultraThinMaterial)
                Color.black.opacity(0.15)
            }
            if let snapshot {
                Image(nsImage: snapshot.image)
                    .resizable()
                    .frame(width: snapshot.frame.width, height: snapshot.frame.height)
                    .shadow(color: .black.opacity(0.35), radius: 24, y: 10)
                    .offset(x: snapshot.frame.minX, y: snapshot.frame.minY)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
