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
    private let hoverQueue = DispatchQueue(label: "app.hopclick.hover", qos: .userInitiated)

    /// Pointer must rest on the new display this long before hover focus acts, so passing through does nothing.
    private static let hoverDelay: TimeInterval = 0.15

    init(config: EngineConfig) {
        self.config = config
        frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.withLock { self?.frontmostPID = app?.processIdentifier }
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
        guard case let .activate(target, clickDisplay) = ClickPolicy.decide(context),
              shouldActivate(target, at: point, config: config) else { return }

        let displaced = ClickPolicy.windowsToRestore(targetPID: target.pid, clickDisplay: clickDisplay,
                                                     windows: windows, displays: displays)
        Activator.activate(target, restoring: displaced)
    }

    /// Checks that cannot be made from the window list alone.
    private func shouldActivate(_ target: WindowInfo, at point: CGPoint, config: EngineConfig) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: target.pid),
              app.activationPolicy != .prohibited else { return false }
        if let id = app.bundleIdentifier, config.excludedBundleIDs.contains(id) { return false }
        // The Dock, notifications and Mission Control draw inside full-display windows that the window list looks
        // through; the Accessibility hit test tells what is really under the pointer.
        if let owner = AX.pidOfElement(at: point), owner != target.pid { return false }
        return true
    }

    // MARK: Hover focus

    private func setHoverMonitor(_ on: Bool) {
        if on, hoverMonitor == nil {
            hoverDisplay = Geometry.display(containing: currentPointer(), in: WindowServer.displays())
            hoverMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
                self?.pointerMoved()
            }
        } else if !on, let monitor = hoverMonitor {
            NSEvent.removeMonitor(monitor)
            hoverMonitor = nil
            hoverWork?.cancel()
        }
    }

    private func pointerMoved() {
        let display = Geometry.display(containing: currentPointer(), in: WindowServer.displays())
        guard display != hoverDisplay else { return }
        hoverDisplay = display
        hoverWork?.cancel()
        guard let display else { return }
        let work = DispatchWorkItem { [weak self] in self?.hoverSettled(on: display) }
        hoverWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.hoverDelay, execute: work)
    }

    private func hoverSettled(on display: CGRect) {
        let point = currentPointer()
        let (config, frontmost) = withLock { (self.config, self.frontmostPID) }
        guard config.enabled, config.hoverFocus, NSEvent.pressedMouseButtons == 0,
              display.contains(point) else { return }
        hoverQueue.async { [ownPID] in
            let windows = WindowServer.onScreenWindows()
            let displays = WindowServer.displays()
            let context = ClickContext(point: point, windows: windows, displays: displays, frontmostPID: frontmost,
                                       ownPID: ownPID, scope: .acrossDisplays)
            guard case let .activate(target, clickDisplay) = ClickPolicy.decide(context),
                  self.shouldActivate(target, at: point, config: config) else { return }
            let displaced = ClickPolicy.windowsToRestore(targetPID: target.pid, clickDisplay: clickDisplay,
                                                         windows: windows, displays: displays)
            Activator.activate(target, restoring: displaced)
        }
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
