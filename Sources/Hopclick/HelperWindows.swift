import ApplicationServices
import Foundation
import HopclickCore

/// Remembers which layer-0 windows are helpers rather than real windows (see `WindowInfo.isHelper`).
///
/// The window list cannot tell them apart (same layer, alpha, sharing state); only the Accessibility subrole can, and
/// Accessibility calls take 10–70 ms or time out (Chrome, 2026-11-23). A window's kind does not change, so each window
/// is looked up once, off the event tap thread, and the answer is cached by window number. Thread-safe.
final class HelperWindows {
    static let shared = HelperWindows()

    private let lock = NSLock()
    /// Per application: windows already looked up, and those found to be helpers.
    private var known: [pid_t: Set<UInt32>] = [:]
    private var helpers: [pid_t: Set<UInt32>] = [:]
    private var helperIDs: Set<UInt32> = []
    private let queue = DispatchQueue(label: "app.hopclick.helper-windows", qos: .utility)

    func isHelper(_ id: UInt32) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return helperIDs.contains(id)
    }

    /// Looks up `pid`'s on-screen windows that are not known yet, in the background.
    func classifyAsync(_ pid: pid_t?) {
        guard let pid else { return }
        queue.async { self.classify(pid, windows: WindowServer.onScreenWindows()) }
    }

    /// Looks up `pid`'s windows in `windows` that are not known yet. Blocks on Accessibility; never call it from the
    /// event tap thread. Returns true when it learned something new.
    @discardableResult
    func classify(_ pid: pid_t, windows: [WindowInfo]) -> Bool {
        let own = windows.filter { $0.pid == pid && $0.layer == 0 && $0.alpha > 0 }
        let current = Set(own.map(\.id))
        lock.lock()
        let alreadyKnown = (known[pid] ?? []).intersection(current)
        lock.unlock()
        let pending = own.filter { !alreadyKnown.contains($0.id) }
        guard !pending.isEmpty else {
            prune(pid, current: current)
            return false
        }

        let app = AX.application(pid)
        let axWindows = AX.windows(of: app).compactMap { element -> (CGRect, String?)? in
            AX.frame(of: element).map { ($0, AX.attribute(element, kAXSubroleAttribute, as: String.self)) }
        }
        // No answer (busy or not accessible): try again next time.
        guard !axWindows.isEmpty else { return false }

        var found: Set<UInt32> = []
        for window in pending {
            let match = axWindows.first { Geometry.sameFrame($0.0, window.bounds) }
            if match?.1 == kAXUnknownSubrole { found.insert(window.id) }
        }

        lock.lock()
        known[pid] = alreadyKnown.union(pending.map(\.id))
        let kept = (helpers[pid] ?? []).intersection(current).union(found)
        helpers[pid] = kept
        helperIDs = Set(helpers.values.joined())
        lock.unlock()
        if !found.isEmpty { Log.hover.info("pid \(pid): \(found.count) helper window(s) ignored") }
        return !found.isEmpty
    }

    /// Forgets windows that are gone, so window numbers reused later are looked up again.
    private func prune(_ pid: pid_t, current: Set<UInt32>) {
        lock.lock()
        defer { lock.unlock() }
        if let ids = known[pid], !ids.isSubset(of: current) { known[pid] = ids.intersection(current) }
        if let ids = helpers[pid], !ids.isSubset(of: current) {
            helpers[pid] = ids.intersection(current)
            helperIDs = Set(helpers.values.joined())
        }
    }
}
