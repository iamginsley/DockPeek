import SwiftUI

/// The menu bar panel: one switch, the two permissions, launch at login and quit.
struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if !viewModel.hasAccessibility {
                PermissionRow(
                    symbol: "hand.point.up.left",
                    text: "Damit DockPeek erkennt, über welchem Dock-Symbol der Mauszeiger ist, und Fenster nach vorn holen kann, braucht es Zugriff auf die „Bedienungshilfen“.",
                    action: viewModel.requestAccessibility
                )
            }
            if !viewModel.hasScreenRecording {
                PermissionRow(
                    symbol: "rectangle.dashed.badge.record",
                    text: "Für Vorschaubilder der Fenster braucht DockPeek „Bildschirm- und Systemaudioaufnahme“. Ohne sie zeigt es nur die Fenstertitel.",
                    action: viewModel.requestScreenRecording,
                    restart: viewModel.relaunch
                )
            }

            Divider()

            footer
        }
        .padding(16)
        .frame(width: 320)
        .onAppear { viewModel.refresh() }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("DockPeek")
                    .font(.headline)
                Text(status)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Toggle("Fenster-Vorschau", isOn: $viewModel.preview.isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .disabled(!viewModel.hasAccessibility)
        }
    }

    private var status: String {
        if !viewModel.hasAccessibility { return "Wartet auf Zugriff" }
        return viewModel.preview.isEnabled
            ? "Zeigt die Fenster, wenn du über ein Dock-Symbol fährst."
            : "Fenster-Vorschau ist aus."
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Toggle("Beim Anmelden starten", isOn: Binding(
                    get: { viewModel.launchAtLogin },
                    set: { viewModel.setLaunchAtLogin($0) }
                ))
                .toggleStyle(.checkbox)
                Spacer()
                Button("Beenden", action: viewModel.quit)
                    .keyboardShortcut("q")
            }
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}

private struct PermissionRow: View {
    let symbol: String
    let text: String
    let action: () -> Void
    var restart: (() -> Void)?

    @State private var hasRequested = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(text)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: symbol)
                    .foregroundStyle(.tint)
            }
            HStack {
                Button("Erlauben …") {
                    hasRequested = true
                    action()
                }
                .buttonStyle(.borderedProminent)
                if hasRequested, let restart {
                    Button("Neu starten", action: restart)
                }
            }
            .controlSize(.regular)
        }
    }
}
