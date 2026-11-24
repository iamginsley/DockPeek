import AppKit
import ScreenCaptureKit

/// Captures window thumbnails with ScreenCaptureKit and keeps the last one per window,
/// so minimized windows (which cannot be captured) still show their last content.
@MainActor
final class ThumbnailService {
    private var cache: [CGWindowID: NSImage] = [:]

    func cached(_ id: CGWindowID) -> NSImage? { cache[id] }

    /// Captures `windows` at `pointSize` (scaled for Retina) and returns the new images.
    func capture(_ windows: [AppWindow], pointSize: (AppWindow) -> CGSize) async -> [CGWindowID: NSImage] {
        guard PermissionService.hasScreenRecording else { return [:] }
        let targets = windows.filter { !$0.isMinimized }
        guard !targets.isEmpty,
              let content = try? await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
        else { return [:] }

        let scale = NSScreen.main?.backingScaleFactor ?? 2
        var images: [CGWindowID: NSImage] = [:]
        // One window after the other; each capture takes a few milliseconds.
        for window in targets {
            guard let scWindow = content.windows.first(where: { $0.windowID == window.id }) else { continue }
            let size = pointSize(window)
            let configuration = SCStreamConfiguration()
            configuration.width = Int(size.width * scale)
            configuration.height = Int(size.height * scale)
            configuration.showsCursor = false
            configuration.ignoreShadowsSingleWindow = true
            let filter = SCContentFilter(desktopIndependentWindow: scWindow)
            if let image = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration) {
                images[window.id] = NSImage(cgImage: image, size: size)
            }
        }
        cache.merge(images) { $1 }
        return images
    }

    func forget(_ id: CGWindowID) {
        cache[id] = nil
    }
}
