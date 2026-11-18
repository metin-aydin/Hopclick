import AppKit
import CoreGraphics
import HopclickCore

/// Reads the window list and display layout from the window server. Thread-safe.
enum WindowServer {
    /// On-screen windows, front to back. Window titles are never read (that would need Screen Recording permission).
    static func onScreenWindows() -> [WindowInfo] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [] }
        return list.compactMap { info in
            guard let id = info[kCGWindowNumber as String] as? UInt32,
                  let pid = info[kCGWindowOwnerPID as String] as? Int32,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else { return nil }
            return WindowInfo(id: id, pid: pid, layer: layer, bounds: bounds,
                              alpha: (info[kCGWindowAlpha as String] as? Double) ?? 1,
                              ownerName: (info[kCGWindowOwnerName as String] as? String) ?? "")
        }
    }

    /// Active display frames in global Core Graphics coordinates (top-left origin), the same space as
    /// `CGEvent.location` and `kCGWindowBounds`.
    static func displays() -> [CGRect] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }
        // Mirrored displays share one frame; keep each frame once.
        var frames: [CGRect] = []
        for id in ids.prefix(Int(count)) {
            let frame = CGDisplayBounds(id)
            if !frames.contains(frame) { frames.append(frame) }
        }
        return frames
    }
}
