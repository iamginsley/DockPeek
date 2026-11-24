import ApplicationServices
import CoreGraphics

/// Private but long-standing call that maps an Accessibility window to its window server ID.
/// Fine outside the Mac App Store; DockDoor, AltTab and others rely on it too.
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError

/// Small typed helpers around the Accessibility C API.
enum AX {
    static func attribute<T>(_ element: AXUIElement, _ name: String, as type: T.Type = T.self) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }

    static func elements(_ element: AXUIElement, _ name: String) -> [AXUIElement] {
        attribute(element, name, as: [AXUIElement].self) ?? []
    }

    static func point(_ element: AXUIElement, _ name: String = kAXPositionAttribute) -> CGPoint? {
        guard let value = attribute(element, name, as: AXValue.self) else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(value, .cgPoint, &point) ? point : nil
    }

    static func size(_ element: AXUIElement, _ name: String = kAXSizeAttribute) -> CGSize? {
        guard let value = attribute(element, name, as: AXValue.self) else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(value, .cgSize, &size) ? size : nil
    }

    /// Frame in Accessibility coordinates (origin top-left of the primary display).
    static func frame(_ element: AXUIElement) -> CGRect? {
        guard let origin = point(element), let size = size(element) else { return nil }
        return CGRect(origin: origin, size: size)
    }

    static func windowID(_ element: AXUIElement) -> CGWindowID? {
        var id: CGWindowID = 0
        return _AXUIElementGetWindow(element, &id) == .success && id != 0 ? id : nil
    }

    @discardableResult
    static func set(_ element: AXUIElement, _ name: String, _ value: CFTypeRef) -> Bool {
        AXUIElementSetAttributeValue(element, name as CFString, value) == .success
    }

    @discardableResult
    static func perform(_ element: AXUIElement, _ action: String) -> Bool {
        AXUIElementPerformAction(element, action as CFString) == .success
    }
}
