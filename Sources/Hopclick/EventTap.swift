import CoreGraphics
import Foundation

/// A left-button event tap on its own high-priority thread.
///
/// The tap never swallows, rewrites or synthesises an event. It only holds a mouse-down for the few milliseconds it
/// takes to activate the window underneath and then returns the user's original event, so one physical click can
/// never turn into two actions.
final class EventTap {
    private let onMouseDown: (CGEvent) -> Void
    private var port: CFMachPort?
    private var source: CFRunLoopSource?
    private var runLoop: CFRunLoop?
    private(set) var isRunning = false

    /// Mouse-up and dragged events are in the mask only to keep ordering: events outside the mask bypass the tap, so a
    /// fast click's mouse-up could otherwise overtake the mouse-down being held.
    private static let mask: CGEventMask =
        (1 << CGEventType.leftMouseDown.rawValue)
        | (1 << CGEventType.leftMouseUp.rawValue)
        | (1 << CGEventType.leftMouseDragged.rawValue)

    init(onMouseDown: @escaping (CGEvent) -> Void) {
        self.onMouseDown = onMouseDown
    }

    deinit { stop() }

    /// Returns false when the system refuses the tap, which means Accessibility permission is missing.
    @discardableResult
    func start() -> Bool {
        guard !isRunning else { return true }
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                           eventsOfInterest: Self.mask, callback: tapCallback,
                                           userInfo: Unmanaged.passUnretained(self).toOpaque())
        else { return false }
        self.port = port
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        self.source = source
        isRunning = true

        let ready = DispatchSemaphore(value: 0)
        let thread = Thread { [weak self] in
            guard let self, let source else { ready.signal(); return }
            self.runLoop = CFRunLoopGetCurrent()
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: port, enable: true)
            ready.signal()
            CFRunLoopRun()
        }
        thread.name = "app.hopclick.eventtap"
        thread.qualityOfService = .userInteractive
        thread.start()
        ready.wait()
        return true
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        if let port {
            CGEvent.tapEnable(tap: port, enable: false)
            CFMachPortInvalidate(port)
        }
        if let runLoop, let source {
            CFRunLoopRemoveSource(runLoop, source, .commonModes)
            CFRunLoopStop(runLoop)
        }
        port = nil
        source = nil
        runLoop = nil
    }

    /// The system disables a tap that times out and reports it only with the next event, so a watchdog re-arms it.
    func reenableIfNeeded() {
        guard isRunning, let port, !CGEvent.tapIsEnabled(tap: port) else { return }
        CGEvent.tapEnable(tap: port, enable: true)
    }

    fileprivate func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let port { CGEvent.tapEnable(tap: port, enable: true) }
        case .leftMouseDown:
            onMouseDown(event)
        default:
            break
        }
        return Unmanaged.passUnretained(event)
    }
}

private let tapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    return Unmanaged<EventTap>.fromOpaque(userInfo).takeUnretainedValue().handle(type, event)
}
