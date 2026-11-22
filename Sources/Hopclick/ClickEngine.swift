import AppKit
import HopclickCore

/// Decides, per left mouse-down, whether the window under the pointer has to be activated first, and does it.
/// Also runs the optional "focus the display under the pointer" mode.
final class ClickEngine {
    private let lock = NSLock()
    private var config: EngineConfig
    private var frontmostPID: pid_t?
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    private lazy var tap = EventTap { [weak self] event in self?.handleMouseDown(event) }
    private var watchdog: Timer?
    private var hoverMonitor: Any?
    private var hoverDisplay: CGRect?
    private var hoverWork: DispatchWorkItem?
    /// Hover focus still owes an activation for the display the pointer entered last.
    private var hoverArmed = false
    /// Bumped on every display crossing, so a late result of an older attempt cannot disarm a newer crossing.
    private var hoverGeneration = 0
    private let hoverQueue = DispatchQueue(label: "app.hopclick.hover", qos: .userInitiated)

    /// Pointer must rest this long on the new display before hover focus acts, so passing through does nothing.
    private static let hoverDelay: TimeInterval = 0.15

    init(config: EngineConfig) {
        self.config = config
        frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.withLock { self?.frontmostPID = app?.processIdentifier }
            HelperWindows.shared.classifyAsync(app?.processIdentifier)
        }
    }

    var isRunning: Bool { tap.isRunning }

    func update(_ config: EngineConfig) {
        withLock { self.config = config }
        apply()
    }

    /// Starts or stops the tap and the hover monitor to match the configuration and the permission state.
    /// Returns false when the tap is wanted but could not be created (permission missing).
    @discardableResult
    func apply() -> Bool {
        let config = withLock { self.config }
        guard config.enabled, AXIsProcessTrusted() else {
            stop()
            return !config.enabled
        }
        guard tap.start() else { return false }
        HelperWindows.shared.classifyAsync(withLock { frontmostPID })
        if watchdog == nil {
            watchdog = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                self?.tap.reenableIfNeeded()
            }
        }
        setHoverMonitor(config.hoverFocus)
        return true
    }

    private func stop() {
        tap.stop()
        watchdog?.invalidate()
        watchdog = nil
        setHoverMonitor(false)
    }

    // MARK: Click-through

    /// Runs on the event tap thread while the mouse-down is held.
    private func handleMouseDown(_ event: CGEvent) {
        let (config, frontmost) = withLock { (self.config, self.frontmostPID) }
        guard config.enabled else { return }
        let modifiers = event.flags.intersection([.maskCommand, .maskControl])
        guard modifiers.isEmpty else { return }

        let point = event.location
        let windows = WindowServer.onScreenWindows()
        let displays = WindowServer.displays()
        let context = ClickContext(point: point, windows: windows, displays: displays, frontmostPID: frontmost,
                                   ownPID: ownPID, scope: config.scope)
        let decision = ClickPolicy.decide(context)
        // Accessibility is too slow to ask here; learn about new windows for the next click.
        HelperWindows.shared.classifyAsync(frontmost)
        if case let .activate(target, _) = decision { HelperWindows.shared.classifyAsync(target.pid) }
        guard case let .activate(target, clickDisplay) = decision else {
            if case let .pass(reason) = decision {
                Log.click.debug("pass: \(reason.rawValue, privacy: .public)")
            }
            return
        }
        if let veto = veto(target, at: point, config: config) {
            Log.click.info("pass: \(veto, privacy: .public) (pid \(target.pid))")
            return
        }

        let displaced = ClickPolicy.windowsToRestore(targetPID: target.pid, clickDisplay: clickDisplay,
                                                     windows: windows, displays: displays)
        let outcome = Activator.activate(target, restoring: displaced, budget: Activator.clickBudget,
                                         frontmostPID: currentFrontmostPID)
        Log.click.notice("activated pid \(target.pid) \(outcome.description, privacy: .public)")
    }

    /// Checks that cannot be made from the window list alone. Returns why the window must not be activated, or nil.
    private func veto(_ target: WindowInfo, at point: CGPoint, config: EngineConfig) -> String? {
        guard let app = NSRunningApplication(processIdentifier: target.pid) else { return "noRunningApplication" }
        if app.activationPolicy == .prohibited { return "activationProhibited" }
        if let id = app.bundleIdentifier, config.excludedBundleIDs.contains(id) { return "excluded" }
        // The Dock, notifications and Mission Control draw inside full-display windows that the window list looks
        // through; the Accessibility hit test tells what is really under the pointer.
        if let owner = AX.pidOfElement(at: point), owner != target.pid { return "elementOwnedBy(\(owner))" }
        return nil
    }

    // MARK: Hover focus
    //
    // Main thread only. Crossing onto another display arms hover focus; every time the pointer then rests on that
    // display it tries again, until a window is activated or focus already is on that display. A single attempt right
    // after the crossing missed whenever the pointer was still travelling over the desktop, the menu bar or the Dock.

    private func setHoverMonitor(_ on: Bool) {
        if on, hoverMonitor == nil {
            hoverDisplay = Geometry.display(containing: currentPointer(), in: WindowServer.displays())
            hoverArmed = false
            hoverMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
                self?.pointerMoved()
            }
            Log.hover.info("hover monitor on (installed: \(self.hoverMonitor != nil))")
        } else if !on, let monitor = hoverMonitor {
            NSEvent.removeMonitor(monitor)
            hoverMonitor = nil
            hoverWork?.cancel()
            hoverArmed = false
            Log.hover.info("hover monitor off")
        }
    }

    private func pointerMoved() {
        let display = Geometry.display(containing: currentPointer(), in: WindowServer.displays())
        if display != hoverDisplay {
            hoverDisplay = display
            hoverArmed = display != nil
            hoverGeneration &+= 1
            if hoverArmed { Log.hover.debug("pointer entered another display") }
        }
        hoverWork?.cancel()
        guard hoverArmed, let display else { return }
        let generation = hoverGeneration
        let work = DispatchWorkItem { [weak self] in self?.hoverSettled(on: display, generation: generation) }
        hoverWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.hoverDelay, execute: work)
    }

    private func hoverSettled(on display: CGRect, generation: Int) {
        let point = currentPointer()
        let (config, frontmost) = withLock { (self.config, self.frontmostPID) }
        guard config.enabled, config.hoverFocus, display.contains(point) else { return }
        guard NSEvent.pressedMouseButtons == 0 else {
            Log.hover.debug("retry later: mouse button down")
            return
        }
        hoverQueue.async { [ownPID] in
            var windows = WindowServer.onScreenWindows()
            let displays = WindowServer.displays()
            // No click is held here, so new windows of the two applications involved can be looked up first.
            var learned = false
            if let frontmost { learned = HelperWindows.shared.classify(frontmost, windows: windows) }
            if let under = ClickPolicy.topmostWindow(at: point, windows: windows, displays: displays),
               under.pid != frontmost {
                learned = HelperWindows.shared.classify(under.pid, windows: windows) || learned
            }
            if learned { windows = WindowServer.onScreenWindows() }
            let context = ClickContext(point: point, windows: windows, displays: displays, frontmostPID: frontmost,
                                       ownPID: ownPID, scope: .acrossDisplays)
            switch ClickPolicy.decide(context) {
            case let .pass(reason):
                switch reason {
                case .sameDisplay, .alreadyFrontWindow, .ownApplication:
                    Log.hover.info("done: \(reason.rawValue, privacy: .public)")
                    self.disarmHover(generation)
                case .focusDisplayUnknown:
                    let own = windows.filter { $0.pid == frontmost }.prefix(4)
                        .map { "L\($0.layer) a\($0.alpha) \(NSStringFromRect($0.bounds))" }.joined(separator: "; ")
                    Log.hover.info("""
                        retry later: focusDisplayUnknown (frontmost \(frontmost ?? -1), its windows: \(own, privacy: .public), \
                        displays: \(displays.map { NSStringFromRect($0) }.joined(separator: "; "), privacy: .public))
                        """)
                default:
                    // Desktop, menu bar, Dock, an overlay: try again when the pointer rests over something else.
                    Log.hover.info("retry later: \(reason.rawValue, privacy: .public)")
                }
            case let .activate(target, clickDisplay):
                if let veto = self.veto(target, at: point, config: config) {
                    Log.hover.info("retry later: \(veto, privacy: .public) (pid \(target.pid))")
                    return
                }
                let displaced = ClickPolicy.windowsToRestore(targetPID: target.pid, clickDisplay: clickDisplay,
                                                             windows: windows, displays: displays)
                let outcome = Activator.activate(target, restoring: displaced, budget: Activator.hoverBudget,
                                                 frontmostPID: self.currentFrontmostPID)
                Log.hover.notice("activated pid \(target.pid) \(outcome.description, privacy: .public)")
                self.disarmHover(generation)
            }
        }
    }

    /// Stops retrying, unless the pointer has crossed displays again since the attempt started.
    private func disarmHover(_ generation: Int) {
        DispatchQueue.main.async {
            if self.hoverGeneration == generation { self.hoverArmed = false }
        }
    }

    /// The active application as last reported by the activation notification. Thread-safe.
    private func currentFrontmostPID() -> pid_t? {
        withLock { frontmostPID }
    }

    /// Pointer location in global Core Graphics coordinates.
    private func currentPointer() -> CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }

    @discardableResult
    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
