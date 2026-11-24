import AppKit
import ScreenCaptureKit

/// Captures window images with ScreenCaptureKit and keeps the last thumbnail per window,
/// so minimized windows (which cannot be captured) still show their last content.
@MainActor
final class ThumbnailService {
    /// How often the front app's windows are captured in the background.
    static let backgroundInterval: TimeInterval = 3

    private var cache: [CGWindowID: NSImage] = [:]
    private var backgroundTimer: Timer?
    private var isCapturingInBackground = false

    func cached(_ id: CGWindowID) -> NSImage? { cache[id] }

    func forget(_ id: CGWindowID) {
        cache[id] = nil
    }

    /// Captures the open ones of `windows`, each fitted into `box` (scaled for Retina),
    /// and returns the new images.
    func capture(_ windows: [AppWindow], in box: CGSize) async -> [CGWindowID: NSImage] {
        let targets = windows.filter { !$0.isMinimized }
        guard !targets.isEmpty, let content = await shareableContent() else { return [:] }
        var images: [CGWindowID: NSImage] = [:]
        // One window after the other; each capture takes a few milliseconds.
        for window in targets {
            guard let scWindow = content.windows.first(where: { $0.windowID == window.id }) else { continue }
            let size = PreviewLayout.thumbnailSize(for: window.size, in: box)
            if let image = await Self.image(of: scWindow, size: size) {
                images[window.id] = image
            }
        }
        cache.merge(images) { $1 }
        return images
    }

    /// A full-size image of one open window, for Aero Peek.
    func captureFullSize(_ window: AppWindow) async -> NSImage? {
        guard !window.isMinimized,
              let content = await shareableContent(),
              let scWindow = content.windows.first(where: { $0.windowID == window.id })
        else { return nil }
        return await Self.image(of: scWindow, size: window.size)
    }

    // MARK: - Background capture

    /// Captures the front app's windows every few seconds, so a window minimized later
    /// still has a recent thumbnail. Does nothing without Screen Recording access.
    func setBackgroundCapture(_ enabled: Bool, box: @escaping @MainActor () -> CGSize) {
        backgroundTimer?.invalidate()
        backgroundTimer = nil
        guard enabled else { return }
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: Self.backgroundInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.captureFrontApp(in: box()) }
        }
        captureFrontApp(in: box())
    }

    private func captureFrontApp(in box: CGSize) {
        guard !isCapturingInBackground,
              PermissionService.hasAccessibility,
              PermissionService.hasScreenRecording,
              let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else { return }
        isCapturingInBackground = true
        let windows = WindowService.windows(of: app)
        Task {
            _ = await capture(windows, in: box)
            await pruneClosedWindows()
            isCapturingInBackground = false
        }
    }

    /// Drops thumbnails of windows that no longer exist.
    private func pruneClosedWindows() async {
        guard let content = await shareableContent() else { return }
        let existing = Set(content.windows.map(\.windowID))
        cache = cache.filter { existing.contains($0.key) }
    }

    // MARK: - ScreenCaptureKit

    private func shareableContent() async -> SCShareableContent? {
        guard PermissionService.hasScreenRecording else { return nil }
        return try? await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
    }

    private static func image(of window: SCWindow, size: CGSize) async -> NSImage? {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let configuration = SCStreamConfiguration()
        configuration.width = max(Int(size.width * scale), 1)
        configuration.height = max(Int(size.height * scale), 1)
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = true
        let filter = SCContentFilter(desktopIndependentWindow: window)
        guard let image = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        else { return nil }
        return NSImage(cgImage: image, size: size)
    }
}
