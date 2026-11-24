import CoreGraphics
import Foundation
import Observation

/// Size of the thumbnails in the preview.
enum ThumbnailSize: String, CaseIterable, Identifiable, Sendable {
    case small, medium, large

    var id: Self { self }

    /// Largest thumbnail, in points.
    var box: CGSize {
        switch self {
        case .small: CGSize(width: 160, height: 100)
        case .medium: CGSize(width: 220, height: 140)
        case .large: CGSize(width: 320, height: 200)
        }
    }

    var title: String {
        switch self {
        case .small: "Klein"
        case .medium: "Mittel"
        case .large: "Groß"
        }
    }
}

/// All user settings, stored in UserDefaults. Every feature has its own switch.
@MainActor
@Observable
final class Preferences {
    /// Window previews when hovering a Dock icon.
    var isPreviewEnabled: Bool { didSet { save(isPreviewEnabled, Key.preview) } }
    /// Seconds the pointer rests on an icon before the first preview appears.
    var previewDelay: Double { didSet { save(previewDelay, Key.delay) } }
    var thumbnailSize: ThumbnailSize { didSet { save(thumbnailSize.rawValue, Key.size) } }
    /// Hovering a thumbnail shows only that window and frosts everything else.
    var isPeekEnabled: Bool { didSet { save(isPeekEnabled, Key.peek) } }
    /// Captures the front app's windows now and then, so minimized windows keep their content.
    var isBackgroundCaptureEnabled: Bool { didSet { save(isBackgroundCaptureEnabled, Key.backgroundCapture) } }
    /// Clicking the Dock icon of the app in front minimizes its front window.
    var isClickToMinimizeEnabled: Bool { didSet { save(isClickToMinimizeEnabled, Key.clickToMinimize) } }
    /// Middle-clicking a thumbnail closes that window.
    var isMiddleClickCloseEnabled: Bool { didSet { save(isMiddleClickCloseEnabled, Key.middleClick) } }

    static let delayRange: ClosedRange<Double> = 0...1

    @ObservationIgnored private let defaults: UserDefaults

    private enum Key {
        static let preview = "previewEnabled"
        static let delay = "previewDelay"
        static let size = "thumbnailSize"
        static let peek = "peekEnabled"
        static let backgroundCapture = "backgroundCaptureEnabled"
        static let clickToMinimize = "clickToMinimizeEnabled"
        static let middleClick = "middleClickCloseEnabled"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isPreviewEnabled = defaults.object(forKey: Key.preview) as? Bool ?? true
        previewDelay = (defaults.object(forKey: Key.delay) as? Double ?? 0.2).clamped(to: Self.delayRange)
        thumbnailSize = defaults.string(forKey: Key.size).flatMap(ThumbnailSize.init) ?? .medium
        isPeekEnabled = defaults.object(forKey: Key.peek) as? Bool ?? true
        isBackgroundCaptureEnabled = defaults.object(forKey: Key.backgroundCapture) as? Bool ?? true
        isClickToMinimizeEnabled = defaults.object(forKey: Key.clickToMinimize) as? Bool ?? true
        isMiddleClickCloseEnabled = defaults.object(forKey: Key.middleClick) as? Bool ?? true
    }

    private func save(_ value: Any, _ key: String) {
        defaults.set(value, forKey: key)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
