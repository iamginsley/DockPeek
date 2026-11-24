import ApplicationServices
import Foundation

/// Private but long-stable API (used by AltTab, DockDoor, Rectangle, …) that maps an
/// Accessibility window element to its `CGWindowID`, which ScreenCaptureKit needs.
@_silgen_name("_AXUIElementGetWindow")
@discardableResult
func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: inout CGWindowID) -> AXError

extension AXUIElement {
    // MARK: Reading

    func rawValue(_ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, attribute as CFString, &value) == .success else { return nil }
        return value
    }

    func string(_ attribute: String) -> String? {
        rawValue(attribute) as? String
    }

    func bool(_ attribute: String) -> Bool? {
        (rawValue(attribute) as? NSNumber)?.boolValue
    }

    func url(_ attribute: String) -> URL? {
        rawValue(attribute) as? URL
    }

    func element(_ attribute: String) -> AXUIElement? {
        guard let value = rawValue(attribute), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement) // swiftlint:disable:this force_cast — type ID checked above
    }

    func elements(_ attribute: String) -> [AXUIElement] {
        (rawValue(attribute) as? [AXUIElement]) ?? []
    }

    func point(_ attribute: String) -> CGPoint? {
        guard let value = axValue(attribute) else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(value, .cgPoint, &point) ? point : nil
    }

    func size(_ attribute: String) -> CGSize? {
        guard let value = axValue(attribute) else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(value, .cgSize, &size) ? size : nil
    }

    // MARK: Convenience

    var role: String? { string(kAXRoleAttribute) }
    var subrole: String? { string(kAXSubroleAttribute) }
    var title: String? { string(kAXTitleAttribute) }

    /// Frame in Accessibility coordinates (origin top-left of the primary screen).
    var frame: CGRect? {
        guard let origin = point(kAXPositionAttribute), let size = size(kAXSizeAttribute) else { return nil }
        return CGRect(origin: origin, size: size)
    }

    var windowID: CGWindowID? {
        var id: CGWindowID = 0
        guard _AXUIElementGetWindow(self, &id) == .success, id != 0 else { return nil }
        return id
    }

    // MARK: Writing

    @discardableResult
    func set(_ attribute: String, _ value: CFTypeRef) -> Bool {
        AXUIElementSetAttributeValue(self, attribute as CFString, value) == .success
    }

    @discardableResult
    func perform(_ action: String) -> Bool {
        AXUIElementPerformAction(self, action as CFString) == .success
    }

    // MARK: Private

    private func axValue(_ attribute: String) -> AXValue? {
        guard let value = rawValue(attribute), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        return (value as! AXValue) // swiftlint:disable:this force_cast — type ID checked above
    }
}
