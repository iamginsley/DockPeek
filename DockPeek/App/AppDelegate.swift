import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let permissions = PermissionsManager()
    private let coordinator = PreviewCoordinator()
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItemController = StatusItemController(permissions: permissions, coordinator: coordinator)

        permissions.requestMissingPermissions()
        // Dock observation needs the Accessibility permission; start as soon as it is granted.
        permissions.whenAccessibilityGranted { [weak self] in
            self?.coordinator.start()
        }
    }
}
