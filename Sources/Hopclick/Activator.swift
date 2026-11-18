import AppKit
import ApplicationServices
import HopclickCore

/// Brings a specific window and its application to the front and waits until the window really is the focused one.
enum Activator {
    /// Hard limit for holding a mouse-down. The window server disables an event tap whose callback runs for about
    /// a second, so this stays far below that while covering almost every application's activation (13–40 ms).
    static let budget: CFTimeInterval = 0.2
    /// How often the focus request is repeated while waiting: an application that is being activated focuses its own
    /// last-used window shortly afterwards, which would override a single request.
    static let pollInterval: useconds_t = 15_000
    static let repeatInterval: CFTimeInterval = 0.03

    private static let restoreQueue = DispatchQueue(label: "app.hopclick.restore", qos: .userInitiated)

    /// Activates `target`. Returns once the clicked window is its application's focused window and the application is
    /// frontmost, or when the budget runs out. Safe to call from the event tap thread.
    @discardableResult
    static func activate(_ target: WindowInfo, restoring displaced: [WindowInfo]) -> Bool {
        let deadline = CFAbsoluteTimeGetCurrent() + budget
        let app = AX.application(target.pid)
        let window = AX.windows(of: app).first { AX.frame(of: $0).map { Geometry.sameFrame($0, target.bounds) } ?? false }

        focus(window, in: app)
        if !AX.set(app, kAXFrontmostAttribute, kCFBooleanTrue) {
            NSRunningApplication(processIdentifier: target.pid)?.activate(options: [])
        }

        var lastRequest = CFAbsoluteTimeGetCurrent()
        var ready = false
        while CFAbsoluteTimeGetCurrent() < deadline {
            if isReady(app, window: window) { ready = true; break }
            usleep(pollInterval)
            if CFAbsoluteTimeGetCurrent() - lastRequest >= repeatInterval {
                focus(window, in: app)
                lastRequest = CFAbsoluteTimeGetCurrent()
            }
        }

        if !displaced.isEmpty { restore(displaced) }
        return ready
    }

    /// Makes `window` the application's main and focused window and raises it. `AXRaise` alone only changes the
    /// stacking order; AppKit applications drop a click that arrives at a window that is not their key window.
    private static func focus(_ window: AXUIElement?, in app: AXUIElement) {
        guard let window else { return }
        AX.set(window, kAXMainAttribute, kCFBooleanTrue)
        AX.set(window, kAXFocusedAttribute, kCFBooleanTrue)
        AX.raise(window)
    }

    private static func isReady(_ app: AXUIElement, window: AXUIElement?) -> Bool {
        guard AX.attribute(app, kAXFrontmostAttribute, as: Bool.self) == true else { return false }
        guard let window else { return true }
        guard let focused: AXUIElement = AX.attribute(app, kAXFocusedWindowAttribute) else { return false }
        return CFEqual(focused, window)
    }

    /// Activation raises the application's windows on every display. The window the user had on top of each other
    /// display is raised back, a few times, because the activated application raises its windows a little later.
    /// Raising another application's window does not change which application is active.
    private static func restore(_ windows: [WindowInfo]) {
        let start = DispatchTime.now()
        for delay in [0, 40, 130, 310] {
            restoreQueue.asyncAfter(deadline: start + .milliseconds(delay)) {
                for info in windows {
                    let app = AX.application(info.pid)
                    if let element = AX.windows(of: app).first(where: {
                        AX.frame(of: $0).map { Geometry.sameFrame($0, info.bounds) } ?? false
                    }) {
                        AX.raise(element)
                    }
                }
            }
        }
    }
}
