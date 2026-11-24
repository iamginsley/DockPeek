import SwiftUI

@main
struct DockPeekApp: App {
    @State private var settings: SettingsViewModel

    init() {
        let preview = PreviewViewModel()
        _settings = State(initialValue: SettingsViewModel(preview: preview))
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
    }

    var body: some Scene {
        MenuBarExtra("DockPeek", systemImage: "rectangle.on.rectangle") {
            SettingsView(viewModel: settings)
        }
        .menuBarExtraStyle(.window)
    }
}
