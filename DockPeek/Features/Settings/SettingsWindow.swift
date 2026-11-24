import SwiftUI

/// The settings window (⌘,): every feature has its own switch.
struct SettingsWindow: View {
    enum Page: String {
        case general, preview, clicks
    }

    @Bindable var viewModel: SettingsViewModel
    @State private var page = Self.initialPage

    var body: some View {
        TabView(selection: $page) {
            Tab("Allgemein", systemImage: "gearshape", value: Page.general) {
                GeneralSettings(viewModel: viewModel)
            }
            Tab("Vorschau", systemImage: "rectangle.on.rectangle", value: Page.preview) {
                PreviewSettings(viewModel: viewModel)
            }
            Tab("Klicks", systemImage: "cursorarrow.click", value: Page.clicks) {
                ClickSettings(viewModel: viewModel)
            }
        }
        .frame(width: 500, height: 450)
        .onAppear { viewModel.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Picks up permissions granted in System Settings meanwhile.
            viewModel.refresh()
        }
    }
}

extension SettingsWindow {
    /// `-DockPeekSettings <general|preview|clicks>` opens the settings on that page (Debug only).
    static var initialPage: Page {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-DockPeekSettings"), index + 1 < arguments.count,
           let page = Page(rawValue: arguments[index + 1]) {
            return page
        }
        #endif
        return .general
    }
}

private struct GeneralSettings: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                Toggle("Beim Anmelden starten", isOn: Binding(
                    get: { viewModel.launchAtLogin },
                    set: { viewModel.setLaunchAtLogin($0) }
                ))
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                PermissionRow(
                    title: "Bedienungshilfen",
                    detail: "Erkennt, über welchem Dock-Symbol die Maus ist, und holt Fenster nach vorn.",
                    isGranted: viewModel.hasAccessibility,
                    request: viewModel.requestAccessibility
                )
                PermissionRow(
                    title: "Bildschirmaufnahme",
                    detail: "Für Vorschaubilder und Aero Peek. Ohne sie zeigt DockPeek nur Titel und App-Symbole.",
                    isGranted: viewModel.hasScreenRecording,
                    request: viewModel.requestScreenRecording,
                    restart: viewModel.relaunch
                )
            } header: {
                Text("Freigaben")
            } footer: {
                Text("Alles bleibt auf deinem Mac. DockPeek sendet keine Daten.")
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("DockPeek", value: viewModel.version)
            }
        }
        .formStyle(.grouped)
    }
}

private struct PreviewSettings: View {
    @Bindable var viewModel: SettingsViewModel

    private var preferences: Preferences { viewModel.preferences }

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $viewModel.preferences.isPreviewEnabled) {
                    Text("Fenster-Vorschau")
                    Text("Zeigt alle Fenster einer App, wenn du über ihr Dock-Symbol fährst.")
                }
            }

            Section("Darstellung") {
                Picker("Größe der Vorschaubilder", selection: $viewModel.preferences.thumbnailSize) {
                    ForEach(ThumbnailSize.allCases) { size in
                        Text(size.title).tag(size)
                    }
                }
                .pickerStyle(.segmented)

                LabeledContent("Verzögerung") {
                    HStack {
                        Slider(value: $viewModel.preferences.previewDelay, in: Preferences.delayRange, step: 0.05) {
                            Text("Verzögerung")
                        } minimumValueLabel: {
                            Text("Sofort")
                        } maximumValueLabel: {
                            Text("1 s")
                        }
                        .labelsHidden()
                        Text(delayText)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 52, alignment: .trailing)
                    }
                }
                .accessibilityValue(delayText)
            }
            .disabled(!preferences.isPreviewEnabled)

            Section {
                Toggle(isOn: $viewModel.preferences.isPeekEnabled) {
                    Text("Aero Peek")
                    Text("Bleibst du kurz auf einem Vorschaubild, tritt alles andere in den Hintergrund und nur dieses Fenster ist zu sehen.")
                }
                Toggle(isOn: $viewModel.preferences.isBackgroundCaptureEnabled) {
                    Text("Inhalt minimierter Fenster zeigen")
                    Text("DockPeek nimmt dazu alle paar Sekunden die Fenster der aktiven App auf. Die Bilder bleiben nur im Arbeitsspeicher.")
                }
            } footer: {
                if !viewModel.hasScreenRecording {
                    Text("Braucht die Freigabe „Bildschirmaufnahme“ (Allgemein).")
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(!preferences.isPreviewEnabled || !viewModel.hasScreenRecording)
        }
        .formStyle(.grouped)
        .onChange(of: preferences.isPreviewEnabled) { viewModel.preferencesChanged() }
        .onChange(of: preferences.isBackgroundCaptureEnabled) { viewModel.preferencesChanged() }
    }

    private var delayText: String {
        preferences.previewDelay == 0
            ? "Sofort"
            : preferences.previewDelay.formatted(.number.precision(.fractionLength(2))) + " s"
    }
}

private struct ClickSettings: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $viewModel.preferences.isClickToMinimizeEnabled) {
                    Text("Klick minimiert")
                    Text("Ein Klick auf das Dock-Symbol der App im Vordergrund minimiert ihr Fenster. Ein zweiter Klick holt es zurück.")
                }
                Toggle(isOn: $viewModel.preferences.isMiddleClickCloseEnabled) {
                    Text("Mittelklick schließt")
                    Text("Ein Mittelklick auf ein Vorschaubild schließt das Fenster.")
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct PermissionRow: View {
    let title: String
    let detail: String
    let isGranted: Bool
    let request: () -> Void
    var restart: (() -> Void)?

    @State private var hasRequested = false

    var body: some View {
        LabeledContent {
            if isGranted {
                Label("Erteilt", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                HStack {
                    if hasRequested, let restart {
                        Button("Neu starten", action: restart)
                    }
                    Button("Erlauben …") {
                        hasRequested = true
                        request()
                    }
                }
            }
        } label: {
            Text(title)
            Text(detail)
        }
    }
}
