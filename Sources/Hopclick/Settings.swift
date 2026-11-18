import Foundation
import HopclickCore

enum AppLanguage: String, CaseIterable {
    case system, english, turkish
}

/// User preferences, stored in UserDefaults. Read and written on the main thread; the click engine gets an immutable
/// `EngineConfig` copy whenever something changes.
final class Settings {
    static let shared = Settings()
    private let d = UserDefaults.standard

    private enum Key {
        static let enabled = "enabled"
        static let scope = "scope"
        static let hoverFocus = "hoverFocus"
        static let excluded = "excludedBundleIDs"
        static let autoUpdate = "autoUpdateCheck"
        static let language = "language"
        static let launched = "hasLaunchedBefore"
    }

    private init() {
        d.register(defaults: [
            Key.enabled: true,
            Key.scope: Scope.acrossDisplays.rawValue,
            Key.hoverFocus: false,
            Key.excluded: [String](),
            Key.autoUpdate: true,
            Key.language: AppLanguage.system.rawValue
        ])
    }

    var enabled: Bool {
        get { d.bool(forKey: Key.enabled) }
        set { d.set(newValue, forKey: Key.enabled) }
    }

    var scope: Scope {
        get { Scope(rawValue: d.string(forKey: Key.scope) ?? "") ?? .acrossDisplays }
        set { d.set(newValue.rawValue, forKey: Key.scope) }
    }

    /// Focus the window under the pointer when it moves onto another display, before any click.
    var hoverFocus: Bool {
        get { d.bool(forKey: Key.hoverFocus) }
        set { d.set(newValue, forKey: Key.hoverFocus) }
    }

    var excludedBundleIDs: [String] {
        get { d.stringArray(forKey: Key.excluded) ?? [] }
        set { d.set(Array(Set(newValue)).sorted(), forKey: Key.excluded) }
    }

    var autoUpdateCheck: Bool {
        get { d.bool(forKey: Key.autoUpdate) }
        set { d.set(newValue, forKey: Key.autoUpdate) }
    }

    var language: AppLanguage {
        get { AppLanguage(rawValue: d.string(forKey: Key.language) ?? "") ?? .system }
        set { d.set(newValue.rawValue, forKey: Key.language) }
    }

    /// True only on the very first launch; used to register the login item once by default.
    func consumeFirstLaunch() -> Bool {
        if d.bool(forKey: Key.launched) { return false }
        d.set(true, forKey: Key.launched)
        return true
    }

    var engineConfig: EngineConfig {
        EngineConfig(enabled: enabled, scope: scope, hoverFocus: hoverFocus, excludedBundleIDs: Set(excludedBundleIDs))
    }
}

struct EngineConfig {
    var enabled: Bool
    var scope: Scope
    var hoverFocus: Bool
    var excludedBundleIDs: Set<String>
}
