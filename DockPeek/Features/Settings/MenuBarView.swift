import SwiftUI

/// The menu bar panel: the two main switches, the way to the settings, and quit.
struct MenuBarView: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("DockPeek")
                .font(.headline)

            if viewModel.hasAccessibility {
                VStack(alignment: .leading, spacing: 10) {
                    SwitchRow(title: "Fenster-Vorschau", isOn: $viewModel.preferences.isPreviewEnabled)
                    SwitchRow(title: "Klick minimiert", isOn: $viewModel.preferences.isClickToMinimizeEnabled)
                }
                .onChange(of: viewModel.preferences.isPreviewEnabled) { viewModel.preferencesChanged() }
            } else {
                Label {
                    Text("DockPeek braucht Zugriff auf die „Bedienungshilfen“, um das Dock zu sehen.")
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "hand.point.up.left")
                        .foregroundStyle(.tint)
                }
                Button("Erlauben …", action: viewModel.requestAccessibility)
                    .buttonStyle(.borderedProminent)
            }

            Divider()

            HStack {
                Button("Einstellungen …") {
                    openSettings()
                    NSApp.activate()
                }
                .keyboardShortcut(",")
                Spacer()
                Button("Beenden", action: viewModel.quit)
                    .keyboardShortcut("q")
            }
        }
        .padding(16)
        .frame(width: 280)
        .onAppear { viewModel.refresh() }
    }
}

/// Label on the left, switch aligned to the right edge, like in Control Center.
private struct SwitchRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer(minLength: 12)
            Toggle(title, isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }
}
