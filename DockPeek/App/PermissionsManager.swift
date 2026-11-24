import AppKit
import ApplicationServices
import CoreGraphics

/// Tracks the two system permissions DockPeek relies on:
/// - Accessibility: read the Dock, list and control windows of other apps (required).
/// - Screen Recording: capture window thumbnails (optional, falls back to app icons).
@MainActor
final class PermissionsManager {
    private var pollTimer: Timer?
    private var pendingHandlers: [@MainActor () -> Void] = []

    var isAccessibilityGranted: Bool { AXIsProcessTrusted() }
    var isScreenRecordingGranted: Bool { CGPreflightScreenCaptureAccess() }

    func requestMissingPermissions() {
        if !isAccessibilityGranted {
            // Literal key avoids touching the non-Sendable global `kAXTrustedCheckOptionPrompt`.
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
        if !isScreenRecordingGranted {
            _ = CGRequestScreenCaptureAccess()
        }
    }

    func whenAccessibilityGranted(_ handler: @escaping @MainActor () -> Void) {
        if isAccessibilityGranted {
            handler()
            return
        }
        pendingHandlers.append(handler)
        startPolling()
    }

    func openAccessibilitySettings() {
        openPrivacyPane("Privacy_Accessibility")
    }

    func openScreenRecordingSettings() {
        openPrivacyPane("Privacy_ScreenCapture")
    }

    // MARK: - Private

    private func startPolling() {
        guard pollTimer == nil else { return }
        // There is no notification for permission changes, so poll while waiting.
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkAccessibility() }
        }
    }

    private func checkAccessibility() {
        guard isAccessibilityGranted else { return }
        pollTimer?.invalidate()
        pollTimer = nil
        let handlers = pendingHandlers
        pendingHandlers.removeAll()
        handlers.forEach { $0() }
    }

    private func openPrivacyPane(_ anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else { return }
        NSWorkspace.shared.open(url)
    }
}
