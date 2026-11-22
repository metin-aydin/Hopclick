import ApplicationServices
import CoreGraphics

/// Small typed helpers around the Accessibility C API.
enum AX {
    /// Upper bound for a single Accessibility round trip to another process, so a hung application can never stall
    /// the mouse for long.
    static let messagingTimeout: Float = 0.08

    static func application(_ pid: pid_t, timeout: Float = messagingTimeout) -> AXUIElement {
        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(element, timeout)
        return element
    }

    static let systemWide: AXUIElement = {
        let element = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(element, messagingTimeout)
        return element
    }()

    static func attribute<T>(_ element: AXUIElement, _ name: String, as: T.Type = T.self) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }

    @discardableResult
    static func set(_ element: AXUIElement, _ name: String, _ value: CFTypeRef) -> Bool {
        AXUIElementSetAttributeValue(element, name as CFString, value) == .success
    }

    @discardableResult
    static func raise(_ element: AXUIElement) -> Bool {
        AXUIElementPerformAction(element, kAXRaiseAction as CFString) == .success
    }

    static func windows(of app: AXUIElement) -> [AXUIElement] {
        attribute(app, kAXWindowsAttribute, as: [AXUIElement].self) ?? []
    }

    /// Window frame in global top-left coordinates (Accessibility uses the same space as Core Graphics).
    static func frame(of window: AXUIElement) -> CGRect? {
        guard let posValue = attribute(window, kAXPositionAttribute, as: AXValue.self),
              let sizeValue = attribute(window, kAXSizeAttribute, as: AXValue.self) else { return nil }
        var origin = CGPoint.zero, size = CGSize.zero
        guard AXValueGetValue(posValue, .cgPoint, &origin), AXValueGetValue(sizeValue, .cgSize, &size) else {
            return nil
        }
        return CGRect(origin: origin, size: size)
    }

    /// The process that owns the Accessibility element under `point`, i.e. what the user really sees there
    /// (a Dock icon, a notification, Mission Control) even when it is drawn inside a full-display window.
    static func pidOfElement(at point: CGPoint) -> pid_t? {
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &element) == .success,
              let element else { return nil }
        var pid: pid_t = 0
        return AXUIElementGetPid(element, &pid) == .success ? pid : nil
    }
}
