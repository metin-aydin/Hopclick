import CoreGraphics

/// One on-screen window as reported by the window server, in global Core Graphics coordinates
/// (origin at the top-left of the main display, y grows downwards).
public struct WindowInfo: Equatable, Sendable {
    public let id: UInt32
    public let pid: Int32
    public let layer: Int
    public let bounds: CGRect
    public let alpha: Double
    public let ownerName: String
    /// A layer-0 window that Accessibility reports as not a real window (subrole `AXUnknown`). Chrome keeps several:
    /// toolbar and popup hosts, some left on a display where Chrome shows no window at all.
    public var isHelper: Bool

    public init(id: UInt32, pid: Int32, layer: Int, bounds: CGRect, alpha: Double = 1, ownerName: String = "",
                isHelper: Bool = false) {
        self.id = id
        self.pid = pid
        self.layer = layer
        self.bounds = bounds
        self.alpha = alpha
        self.ownerName = ownerName
        self.isHelper = isHelper
    }

    /// Ordinary document/app windows live on layer 0.
    public var isOrdinary: Bool { layer == 0 && alpha > 0 && !isHelper }
}

/// Window-server layers that matter for the click policy.
public enum WindowLayer {
    /// The main menu bar (`kCGMainMenuWindowLevel`).
    public static let mainMenu = 24
    /// Menu bar extras (`kCGStatusWindowLevel`).
    public static let status = 25
    /// Open pop-up and context menus (`kCGPopUpMenuWindowLevel`).
    public static let popUpMenu = 101
    /// Anything at or above this level is a cursor or system overlay that never takes clicks for an app window.
    public static let cursorAndAbove = 2000
}

public enum Geometry {
    /// The display rectangle that contains `point`, if any.
    public static func display(containing point: CGPoint, in displays: [CGRect]) -> CGRect? {
        displays.first { $0.contains(point) }
    }

    /// The display that shows the largest part of `bounds`.
    public static func display(mostlyCovering bounds: CGRect, in displays: [CGRect]) -> CGRect? {
        var best: (CGRect, CGFloat)?
        for display in displays {
            let overlap = display.intersection(bounds)
            guard !overlap.isNull else { continue }
            let area = overlap.width * overlap.height
            if area > 0, area > (best?.1 ?? 0) { best = (display, area) }
        }
        return best?.0
    }

    /// A window above the ordinary layer that covers a whole display is a backdrop (the Dock, Notification Center),
    /// not something the user aimed at; the click target is looked for behind it.
    public static func isBackdrop(_ window: WindowInfo, displays: [CGRect]) -> Bool {
        window.layer > 0 && displays.contains { window.bounds.insetBy(dx: -1, dy: -1).contains($0) }
    }

    /// Two rectangles are the same window frame when they differ by at most `tolerance` points on every edge.
    public static func sameFrame(_ a: CGRect, _ b: CGRect, tolerance: CGFloat = 2) -> Bool {
        abs(a.minX - b.minX) <= tolerance && abs(a.minY - b.minY) <= tolerance
            && abs(a.width - b.width) <= tolerance && abs(a.height - b.height) <= tolerance
    }
}
