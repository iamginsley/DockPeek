import SwiftUI

@main
struct DockPeekApp: App {
    @State private var settings: SettingsViewModel

    init() {
        let dock = DockObserver()
        let preview = PreviewViewModel(dock: dock)
        let minimizer = ClickToMinimize(dock: dock)
        _settings = State(initialValue: SettingsViewModel(preview: preview, minimizer: minimizer))
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
        MenuBarExtra("DockPeek", systemImage: "rectangle.on.rectangle") {
            SettingsView(viewModel: settings)
        }
        .menuBarExtraStyle(.window)
    }
}
