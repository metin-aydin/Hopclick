import CoreGraphics

/// Which clicks Hopclick acts on.
public enum Scope: String, CaseIterable, Sendable {
    /// Only clicks on a different display than the one holding focus (the multi-monitor case).
    case acrossDisplays
    /// Any click on an inactive window, on any display.
    case everywhere
}

/// Everything the policy needs to decide about one mouse-down. Built from a window-server snapshot.
public struct ClickContext: Sendable {
    public var point: CGPoint
    /// On-screen windows, front to back.
    public var windows: [WindowInfo]
    /// Display frames in global Core Graphics coordinates.
    public var displays: [CGRect]
    public var frontmostPID: Int32?
    public var ownPID: Int32
    public var scope: Scope
    /// ⌘ or ⌃ held: macOS already gives these clicks a meaning (click without activating, context menu).
    public var commandOrControlHeld: Bool

    public init(point: CGPoint, windows: [WindowInfo], displays: [CGRect], frontmostPID: Int32?, ownPID: Int32,
                scope: Scope, commandOrControlHeld: Bool = false) {
        self.point = point
        self.windows = windows
        self.displays = displays
        self.frontmostPID = frontmostPID
        self.ownPID = ownPID
        self.scope = scope
        self.commandOrControlHeld = commandOrControlHeld
    }
}

public enum PassReason: String, Sendable {
    case modifierHeld
    case menuOpen
    case noDisplay
    case menuBar
    case noWindowUnderCursor
    case overlayWindow
    case ownApplication
    case sameDisplay
    case focusDisplayUnknown
    case alreadyFrontWindow
}

public enum ClickDecision: Equatable, Sendable {
    /// Leave the click to macOS.
    case pass(PassReason)
    /// Activate `window` (and its application) before the click is delivered.
    case activate(WindowInfo, clickDisplay: CGRect)
}

public enum ClickPolicy {
    public static func decide(_ c: ClickContext) -> ClickDecision {
        if c.commandOrControlHeld { return .pass(.modifierHeld) }
        if c.windows.contains(where: { $0.layer == WindowLayer.popUpMenu }) { return .pass(.menuOpen) }
        guard let clickDisplay = Geometry.display(containing: c.point, in: c.displays) else { return .pass(.noDisplay) }

        if c.windows.contains(where: {
            ($0.layer == WindowLayer.mainMenu || $0.layer == WindowLayer.status) && $0.bounds.contains(c.point)
        }) {
            return .pass(.menuBar)
        }

        guard let target = topmostWindow(at: c.point, windows: c.windows, displays: c.displays) else {
            return .pass(.noWindowUnderCursor)
        }
        guard target.isOrdinary else { return .pass(.overlayWindow) }
        if target.pid == c.ownPID { return .pass(.ownApplication) }

        if c.scope == .acrossDisplays {
            guard let focus = focusDisplay(frontmostPID: c.frontmostPID, windows: c.windows, displays: c.displays)
            else { return .pass(.focusDisplayUnknown) }
            if focus == clickDisplay { return .pass(.sameDisplay) }
        }

        if let front = c.frontmostPID, target.pid == front,
           frontWindow(of: front, in: c.windows)?.id == target.id {
            return .pass(.alreadyFrontWindow)
        }
        return .activate(target, clickDisplay: clickDisplay)
    }

    /// The window that would receive a click at `point`: the front-most visible window under it, looking through
    /// full-display backdrops, helper windows and the cursor/overlay layers.
    public static func topmostWindow(at point: CGPoint, windows: [WindowInfo], displays: [CGRect]) -> WindowInfo? {
        windows.first { w in
            w.alpha > 0 && w.layer >= 0 && w.layer < WindowLayer.cursorAndAbove && !w.isHelper
                && w.bounds.contains(point) && !Geometry.isBackdrop(w, displays: displays)
        }
    }

    /// The display that holds focus: the one showing most of the frontmost application's front window, or, when
    /// that application shows no window (Finder after a desktop click), the one with the topmost ordinary window.
    /// Windows that lie on no display are skipped: taking such a window as the front window left the focus display
    /// unknown, and hover focus then never acted (seen with Chrome frontmost, 2026-11-22).
    public static func focusDisplay(frontmostPID: Int32?, windows: [WindowInfo], displays: [CGRect]) -> CGRect? {
        func display(of window: WindowInfo) -> CGRect? {
            window.isOrdinary ? Geometry.display(mostlyCovering: window.bounds, in: displays) : nil
        }
        if let pid = frontmostPID,
           let found = windows.lazy.filter({ $0.pid == pid }).compactMap(display(of:)).first {
            return found
        }
        return windows.lazy.compactMap(display(of:)).first
    }

    public static func frontWindow(of pid: Int32, in windows: [WindowInfo]) -> WindowInfo? {
        windows.first { $0.pid == pid && $0.isOrdinary }
    }

    /// For each display other than `clickDisplay`, the window the user currently sees on top there, when it belongs to
    /// another application than `targetPID` and `targetPID` also has a window on that display. Activating the target
    /// raises all of its windows, so these are raised back afterwards.
    public static func windowsToRestore(targetPID: Int32, clickDisplay: CGRect, windows: [WindowInfo],
                                        displays: [CGRect]) -> [WindowInfo] {
        displays.filter { $0 != clickDisplay }.compactMap { display in
            let onDisplay = windows.filter {
                $0.isOrdinary && Geometry.display(mostlyCovering: $0.bounds, in: displays) == display
            }
            guard let top = onDisplay.first, top.pid != targetPID,
                  onDisplay.contains(where: { $0.pid == targetPID }) else { return nil }
            return top
        }
    }
}
