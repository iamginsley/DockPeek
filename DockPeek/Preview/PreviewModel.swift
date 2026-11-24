import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class PreviewModel {
    var appIcon: NSImage?
    var windows: [WindowInfo] = []
    var thumbnails: [CGWindowID: CGImage] = [:]
    var hoveredWindowID: CGWindowID?
    var axis: Axis = .horizontal
}
