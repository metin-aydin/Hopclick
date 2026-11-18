import AppKit

/// The menu bar icon: the logo's mark (two displays and a dotted hop) drawn as a template image so it follows the
/// menu bar's light and dark appearance.
enum StatusIcon {
    enum Variant { case normal, disabled, needsPermission }

    static func image(_ variant: Variant, badge: Bool) -> NSImage {
        let size = NSSize(width: 22, height: 16)
        let image = NSImage(size: size, flipped: true) { _ in
            NSColor.black.setStroke()
            NSColor.black.setFill()

            // Two displays.
            for x in [1.5, 12.5] {
                let screen = NSBezierPath(roundedRect: NSRect(x: x, y: 8.5, width: 8, height: 6), xRadius: 1.6,
                                          yRadius: 1.6)
                screen.lineWidth = 1.5
                screen.stroke()
            }
            // Dotted hop from the left display to the right one.
            for (x, y) in [(5.5, 6.0), (8.0, 3.2), (11.0, 2.2), (14.0, 3.2), (16.5, 6.0)] {
                NSBezierPath(ovalIn: NSRect(x: x - 1, y: y - 1, width: 2, height: 2)).fill()
            }
            if variant == .needsPermission {
                // A slash across the mark while the app cannot work.
                let slash = NSBezierPath()
                slash.move(to: NSPoint(x: 2, y: 15))
                slash.line(to: NSPoint(x: 20, y: 1))
                slash.lineWidth = 1.6
                slash.stroke()
            }
            if badge {
                NSBezierPath(ovalIn: NSRect(x: 17.5, y: 0, width: 4.5, height: 4.5)).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
