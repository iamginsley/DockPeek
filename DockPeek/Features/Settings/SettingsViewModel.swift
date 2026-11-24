import AppKit
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    var preferences: Preferences
    let preview: PreviewViewModel
    private(set) var hasAccessibility = PermissionService.hasAccessibility
    private(set) var hasScreenRecording = PermissionService.hasScreenRecording
    private(set) var launchAtLogin = LoginItemService.isEnabled
    private(set) var errorMessage: String?

    init(preferences: Preferences, preview: PreviewViewModel) {
        self.preferences = preferences
        self.preview = preview
    }

    func refresh() {
        hasAccessibility = PermissionService.hasAccessibility
        hasScreenRecording = PermissionService.hasScreenRecording
        launchAtLogin = LoginItemService.isEnabled
    }

    func requestAccessibility() {
        PermissionService.requestAccessibility()
        preview.start()
    }

    func requestScreenRecording() {
        PermissionService.requestScreenRecording()
    }

    /// Call after a setting changed that the preview has to act on right away.
    func preferencesChanged() {
        preview.applyPreferences()
    }

    var version: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Version \(version) (\(build))"
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LoginItemService.setEnabled(enabled)
            errorMessage = nil
        } catch {
            errorMessage = "„Beim Anmelden starten“ ließ sich nicht ändern."
        }
        launchAtLogin = LoginItemService.isEnabled
    }

    /// macOS only hands a new Screen Recording grant to the app after a restart.
    func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            Task { @MainActor in NSApp.terminate(nil) }
        }
    }

    func quit() {
        NSApp.terminate(nil)
    }
}
