import AppKit
import ApplicationServices
import CoreGraphics

/// The two privacy permissions DockPeek needs.
@MainActor
enum PermissionService {
    /// Accessibility: see which Dock icon the pointer is over and control windows.
    /// Takes effect without a restart.
    static var hasAccessibility: Bool { AXIsProcessTrusted() }

    /// Screen Recording: capture window thumbnails. Without it the preview shows titles only.
    static var hasScreenRecording: Bool { CGPreflightScreenCaptureAccess() }

    static func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            SystemSettings.open(.accessibility)
        }
    }

    static func requestScreenRecording() {
        if !CGRequestScreenCaptureAccess() {
            SystemSettings.open(.screenRecording)
        }
    }
}

/// Opens the privacy panes in System Settings.
@MainActor
enum SystemSettings {
    enum Pane: String {
        case accessibility = "Privacy_Accessibility"
        case screenRecording = "Privacy_ScreenCapture"
    }

    static func open(_ pane: Pane) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane.rawValue)") else { return }
        NSWorkspace.shared.open(url)
    }
}
