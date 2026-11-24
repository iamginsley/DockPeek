import ApplicationServices

/// One window of an application, as listed by the Accessibility API.
struct WindowInfo: Identifiable {
    let id: CGWindowID
    let element: AXUIElement
    let title: String
    let isMinimized: Bool
}
