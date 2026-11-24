import AppKit
import ServiceManagement

/// Menu bar icon with settings and permission shortcuts.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let permissions: PermissionsManager
    private let coordinator: PreviewCoordinator

    init(permissions: PermissionsManager, coordinator: PreviewCoordinator) {
        self.permissions = permissions
        self.coordinator = coordinator
        super.init()

        statusItem.button?.image = NSImage(systemSymbolName: "dock.rectangle", accessibilityDescription: "DockPeek")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    // Rebuilt on every open so permission and toggle states are always current.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let toggle = item("Fenstervorschau im Dock", action: #selector(togglePreview))
        toggle.state = coordinator.isEnabled ? .on : .off
        menu.addItem(toggle)

        menu.addItem(.separator())

        if permissions.isAccessibilityGranted {
            menu.addItem(disabledItem("Bedienungshilfen: erlaubt"))
        } else {
            menu.addItem(item("Bedienungshilfen erlauben …", action: #selector(openAccessibility)))
        }
        if permissions.isScreenRecordingGranted {
            menu.addItem(disabledItem("Bildschirmaufnahme: erlaubt"))
        } else {
            menu.addItem(item("Bildschirmaufnahme erlauben (für Vorschaubilder) …", action: #selector(openScreenRecording)))
        }

        menu.addItem(.separator())

        let login = item("Bei Anmeldung starten", action: #selector(toggleLaunchAtLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(item("DockPeek beenden", action: #selector(quit), key: "q"))
    }

    // MARK: - Actions

    @objc private func togglePreview() {
        coordinator.isEnabled.toggle()
    }

    @objc private func openAccessibility() {
        permissions.openAccessibilitySettings()
    }

    @objc private func openScreenRecording() {
        permissions.openScreenRecordingSettings()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Helpers

    private func item(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: key)
        menuItem.target = self
        return menuItem
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        menuItem.isEnabled = false
        return menuItem
    }
}
