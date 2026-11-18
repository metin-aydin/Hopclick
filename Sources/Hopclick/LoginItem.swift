import Foundation
import ServiceManagement

/// Start at login through `SMAppService` (macOS 13+). The app appears under System Settings › General › Login Items.
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// Running from /Applications or ~/Applications rather than a build folder or a mounted disk image.
    static var isInstalledCopy: Bool {
        let parent = Bundle.main.bundleURL.deletingLastPathComponent().path
        return parent == "/Applications" || parent == NSHomeDirectory() + "/Applications"
    }

    static func set(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Hopclick: login item change failed: \(error.localizedDescription)")
        }
    }
}
