import CoreGraphics
@preconcurrency import ScreenCaptureKit

/// CGImage is immutable; the wrapper lets it cross from the actor to the main actor.
struct Thumbnail: @unchecked Sendable {
    let image: CGImage
}

/// Captures window thumbnails with ScreenCaptureKit and keeps the last good image per window,
/// so minimized or hidden windows (which cannot be captured) still show their last state.
actor ThumbnailService {
    private var cache: [CGWindowID: Thumbnail] = [:]
    private var shareableWindows: [CGWindowID: SCWindow] = [:]

    func cached(_ windowID: CGWindowID) -> Thumbnail? {
        cache[windowID]
    }

    /// Refreshes the list of capturable windows. Call once per preview before `thumbnail(for:)`.
    func refreshShareableContent() async -> Bool {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            shareableWindows = Dictionary(content.windows.map { ($0.windowID, $0) }, uniquingKeysWith: { first, _ in first })
            return true
        } catch {
            return false
        }
    }

    func thumbnail(for windowID: CGWindowID, fitting maxPointSize: CGSize) async -> Thumbnail? {
        guard let window = shareableWindows[windowID] else { return cache[windowID] }
        let windowSize = window.frame.size
        guard windowSize.width > 0, windowSize.height > 0 else { return cache[windowID] }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let scale = CGFloat(filter.pointPixelScale)
        let fit = min(maxPointSize.width / windowSize.width, maxPointSize.height / windowSize.height, 1)

        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int(windowSize.width * fit * scale))
        configuration.height = max(1, Int(windowSize.height * fit * scale))
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = true

        do {
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            let thumbnail = Thumbnail(image: image)
            cache[windowID] = thumbnail
            return thumbnail
        } catch {
            return cache[windowID]
        }
    }
}
