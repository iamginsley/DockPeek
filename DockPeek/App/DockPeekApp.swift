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
