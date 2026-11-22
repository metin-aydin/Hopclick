import AppKit
import ApplicationServices
import HopclickCore

/// Brings a specific window and its application to the front and waits until the window really is the focused one.
///
/// Measured 2026-11-22 (Finder, Claude): while the target activates, its main thread is busy and every Accessibility
/// call to it waits. Setting `AXFrontmost` took 80–211 ms and often returned `kAXErrorCannotComplete` although the
/// activation went through; reading it took 28–74 ms. The activation notification reached Hopclick after 4–100 ms.
/// So "frontmost" comes from that notification (no round trip), and the polling calls use a short timeout.
enum Activator {
    /// Hard limit for holding a mouse-down. The window server disables an event tap whose callback runs for about
    /// a second, so this stays far below that while covering almost every application's activation (13–40 ms).
    static let clickBudget: CFTimeInterval = 0.2
    /// Hover focus holds no click, so it can wait longer and keep overriding the window the application focuses
    /// by itself (its last-used one, often on the other display).
    static let hoverBudget: CFTimeInterval = 0.6
    /// How often the focus request is repeated while waiting: an application that is being activated focuses its own
    /// last-used window shortly afterwards, which would override a single request.
    static let pollInterval: useconds_t = 15_000
    static let repeatInterval: CFTimeInterval = 0.03
    /// Timeout for the calls made while polling, so a busy application costs one short wait, not the full one.
    static let pollTimeout: Float = 0.025

    private static let restoreQueue = DispatchQueue(label: "app.hopclick.restore", qos: .userInitiated)

    struct Outcome: CustomStringConvertible {
        var ready: Bool
        var matchedWindow: Bool
        var ms: Int
        /// Last observed state when not ready.
        var frontmost: Bool
        var focusedIsTarget: Bool?

        var description: String {
            let focused = focusedIsTarget.map { $0 ? "target" : "other" } ?? "unknown"
            return "ready=\(ready) in \(ms) ms (window matched: \(matchedWindow), frontmost: \(frontmost), " +
                "focused window: \(focused))"
        }
    }

    /// Activates `target`. Returns once the clicked window is its application's focused window and the application is
    /// frontmost, or when `budget` runs out. `frontmostPID` reads Hopclick's own record of the active application.
    /// Safe to call from the event tap thread.
    @discardableResult
    static func activate(_ target: WindowInfo, restoring displaced: [WindowInfo], budget: CFTimeInterval,
                         frontmostPID: () -> pid_t?) -> Outcome {
        let start = CFAbsoluteTimeGetCurrent()
        let deadline = start + budget
        let app = AX.application(target.pid)
        let window = AX.windows(of: app).first { AX.frame(of: $0).map { Geometry.sameFrame($0, target.bounds) } ?? false }

        focus(window, in: app)
        let result = AXUIElementSetAttributeValue(app, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        // kAXErrorCannotComplete is the timeout of a busy application that is activating; only a refusal needs the
        // other way in.
        if result != .success, result != .cannotComplete {
            NSRunningApplication(processIdentifier: target.pid)?.activate(options: [])
        }

        let poll = AX.application(target.pid, timeout: pollTimeout)
        let pollWindow = window
        if let pollWindow { AXUIElementSetMessagingTimeout(pollWindow, pollTimeout) }
        var outcome = Outcome(ready: false, matchedWindow: window != nil, ms: 0, frontmost: false, focusedIsTarget: nil)
        var lastRequest = CFAbsoluteTimeGetCurrent()
        while true {
            outcome.frontmost = frontmostPID() == target.pid
                || AX.attribute(poll, kAXFrontmostAttribute, as: Bool.self) == true
            if outcome.frontmost {
                if let pollWindow {
                    let focused: AXUIElement? = AX.attribute(poll, kAXFocusedWindowAttribute)
                    outcome.focusedIsTarget = focused.map { CFEqual($0, pollWindow) }
                    if outcome.focusedIsTarget == true { outcome.ready = true }
                } else {
                    outcome.ready = true
                }
            }
            if outcome.ready || CFAbsoluteTimeGetCurrent() >= deadline { break }
            usleep(pollInterval)
            if CFAbsoluteTimeGetCurrent() - lastRequest >= repeatInterval, outcome.focusedIsTarget != true {
                focus(pollWindow, in: poll)
                lastRequest = CFAbsoluteTimeGetCurrent()
            }
        }
        outcome.ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)

        if !displaced.isEmpty { restore(displaced) }
        return outcome
    }

    /// Makes `window` the application's main and focused window and raises it. `AXRaise` alone only changes the
    /// stacking order; AppKit applications drop a click that arrives at a window that is not their key window.
    private static func focus(_ window: AXUIElement?, in app: AXUIElement) {
        guard let window else { return }
        AX.set(window, kAXMainAttribute, kCFBooleanTrue)
        AX.set(window, kAXFocusedAttribute, kCFBooleanTrue)
        AX.raise(window)
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
