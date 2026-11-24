import SwiftUI

/// The menu bar panel: feature switches, the two permissions, launch at login and quit.
struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            features

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
        VStack(alignment: .leading, spacing: 2) {
            Text("DockPeek")
                .font(.headline)
            if !viewModel.hasAccessibility {
                Text("Wartet auf Zugriff")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 10) {
            FeatureToggle(
                title: "Fenster-Vorschau",
                detail: "Zeigt alle Fenster einer App, wenn du über ihr Dock-Symbol fährst.",
                isOn: $viewModel.preview.isEnabled
            )
            FeatureToggle(
                title: "Klick minimiert",
                detail: "Ein Klick auf das Symbol der App im Vordergrund minimiert ihr Fenster.",
                isOn: $viewModel.minimizer.isEnabled
            )
        }
        .disabled(!viewModel.hasAccessibility)
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

private struct FeatureToggle: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(.switch)
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
