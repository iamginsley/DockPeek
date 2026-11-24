import SwiftUI

@main
struct DockPeekApp: App {
    @State private var settings: SettingsViewModel
    private let minimizer: ClickToMinimize

    init() {
        let preferences = Preferences()
        let dock = DockObserver()
        let preview = PreviewViewModel(dock: dock, preferences: preferences)
        let minimizer = ClickToMinimize(dock: dock, preferences: preferences)
        self.minimizer = minimizer
        _settings = State(initialValue: SettingsViewModel(preferences: preferences, preview: preview))
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-DockPeekDemo") {
            DispatchQueue.main.async { preview.showDemo() }
            return
        }
        // -DockPeekDump <bundle id>: logs what DockPeek sees of that app's windows.
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-DockPeekDump"), index + 1 < arguments.count,
           let app = NSRunningApplication.runningApplications(withBundleIdentifier: arguments[index + 1]).first {
            let windows = WindowService.windows(of: app)
            log.info("Dump: \(windows.count) windows, minimized \(windows.filter(\.isMinimized).count)")
        }
        #endif
        preview.start()
        minimizer.start()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(viewModel: settings)
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsWindow(viewModel: settings)
        }
    }
}

private struct MenuBarLabel: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        // Three windows fanning out of a Dock icon, like the app icon (template image).
        Image(.menuBarIcon)
            .accessibilityLabel("DockPeek")
            .onAppear {
                #if DEBUG
                // -DockPeekSettings <page>: opens the settings at launch, for screenshots.
                if ProcessInfo.processInfo.arguments.contains("-DockPeekSettings") {
                    openSettings()
                    NSApp.activate()
                }
                #endif
            }
    }
}
