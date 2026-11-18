import AppKit
import ApplicationServices
import HopclickCore

/// Menu bar agent: no Dock icon (LSUIElement), one status item whose menu is the whole interface.
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = Settings.shared
    private lazy var engine = ClickEngine(config: settings.engineConfig)
    private let updater = Updater()
    private var statusItem: NSStatusItem!
    private var permissionTimer: Timer?
    private var hasPermission = AXIsProcessTrusted()

    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--unregister-login-item") {
            LoginItem.set(false)
            NSApp.terminate(nil)
            return
        }
        if terminateIfAlreadyRunning() { return }
        // Keep the app out of the Dock and the app switcher even if the Info.plist key were missing.
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        // Only an installed copy registers itself, so a development build never becomes a login item.
        if LoginItem.isInstalledCopy, settings.consumeFirstLaunch() { LoginItem.set(true) }

        updater.onChange = { [weak self] in self?.refreshIcon() }
        updater.start()

        if !hasPermission { showWelcome() }
        startPermissionWatch()
        engine.apply()
        refreshIcon()

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in self?.engine.apply() }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil,
                                                          queue: .main) { [weak self] _ in self?.engine.apply() }
    }

    /// A second copy (e.g. opened again from Finder) quits and leaves the running one alone.
    private func terminateIfAlreadyRunning() -> Bool {
        guard let id = Bundle.main.bundleIdentifier else { return false }
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: id)
            .filter { $0.processIdentifier != getpid() }
        guard !others.isEmpty else { return false }
        NSApp.terminate(nil)
        return true
    }

    // MARK: Permission

    /// Accessibility permission can be granted at any time; it is polled so the app starts working without a restart.
    private func startPermissionWatch() {
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self else { return }
            let trusted = AXIsProcessTrusted()
            guard trusted != self.hasPermission else { return }
            self.hasPermission = trusted
            self.engine.apply()
            self.refreshIcon()
        }
    }

    private func showWelcome() {
        let alert = NSAlert()
        alert.icon = NSApp.applicationIconImage
        alert.messageText = L10n.welcomeTitle
        alert.informativeText = L10n.welcomeBody
        alert.addButton(withTitle: L10n.openSettings)
        alert.addButton(withTitle: L10n.later)
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn { requestPermission() }
    }

    @objc private func requestPermission() {
        // Adds Hopclick to the Accessibility list (switched off) so the user only has to flip the switch.
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Icon

    private func refreshIcon() {
        guard let button = statusItem?.button else { return }
        let variant: StatusIcon.Variant = !hasPermission ? .needsPermission : (settings.enabled ? .normal : .disabled)
        button.image = StatusIcon.image(variant, badge: updater.availableVersion != nil)
        button.appearsDisabled = variant != .normal
        button.toolTip = hasPermission ? "Hopclick" : "Hopclick — \(L10n.permissionMissing)"
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if !hasPermission {
            let info = NSMenuItem(title: L10n.permissionMissing, action: nil, keyEquivalent: "")
            info.isEnabled = false
            menu.addItem(info)
            menu.addItem(item(L10n.grantPermission, #selector(requestPermission)))
            menu.addItem(.separator())
        }

        menu.addItem(item(L10n.enabled, #selector(toggleEnabled), state: settings.enabled))
        menu.addItem(.separator())

        let scopeItem = NSMenuItem(title: L10n.scope, action: nil, keyEquivalent: "")
        let scopeMenu = NSMenu()
        scopeMenu.addItem(item(L10n.scopeAcross, #selector(setScope(_:)), state: settings.scope == .acrossDisplays,
                               represented: Scope.acrossDisplays.rawValue))
        scopeMenu.addItem(item(L10n.scopeEverywhere, #selector(setScope(_:)), state: settings.scope == .everywhere,
                               represented: Scope.everywhere.rawValue))
        scopeItem.submenu = scopeMenu
        menu.addItem(scopeItem)
        menu.addItem(item(L10n.hoverFocus, #selector(toggleHover), state: settings.hoverFocus))

        addExclusionItems(to: menu)
        menu.addItem(.separator())

        menu.addItem(item(L10n.launchAtLogin, #selector(toggleLogin), state: LoginItem.isEnabled))
        menu.addItem(item(L10n.autoUpdate, #selector(toggleAutoUpdate), state: settings.autoUpdateCheck))
        menu.addItem(updateItem())

        let languageItem = NSMenuItem(title: L10n.language, action: nil, keyEquivalent: "")
        let languageMenu = NSMenu()
        for (lang, title) in [(AppLanguage.system, L10n.languageSystem), (.english, "English"), (.turkish, "Türkçe")] {
            languageMenu.addItem(item(title, #selector(setLanguage(_:)), state: settings.language == lang,
                                      represented: lang.rawValue))
        }
        languageItem.submenu = languageMenu
        menu.addItem(languageItem)
        menu.addItem(.separator())

        menu.addItem(item(L10n.about(updater.currentVersion), #selector(openGitHub)))
        menu.addItem(item(L10n.quit, #selector(quit), key: "q"))
    }

    private func addExclusionItems(to menu: NSMenu) {
        // The app that was frontmost before the menu opened (menus do not activate Hopclick).
        if let front = NSWorkspace.shared.frontmostApplication, let id = front.bundleIdentifier,
           id != Bundle.main.bundleIdentifier {
            let name = front.localizedName ?? id
            let excluded = settings.excludedBundleIDs.contains(id)
            menu.addItem(item(excluded ? L10n.enableIn(name) : L10n.disableIn(name), #selector(toggleExclusion(_:)),
                              represented: id))
        }
        let excluded = settings.excludedBundleIDs
        guard !excluded.isEmpty else { return }
        let listItem = NSMenuItem(title: L10n.excludedApps, action: nil, keyEquivalent: "")
        let list = NSMenu()
        let hint = NSMenuItem(title: L10n.clickToRemove, action: nil, keyEquivalent: "")
        hint.isEnabled = false
        list.addItem(hint)
        for id in excluded {
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
            let name = url.map { FileManager.default.displayName(atPath: $0.path) } ?? id
            let entry = item(name.replacingOccurrences(of: ".app", with: ""), #selector(toggleExclusion(_:)),
                             represented: id)
            if let url {
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                icon.size = NSSize(width: 16, height: 16)
                entry.image = icon
            }
            list.addItem(entry)
        }
        listItem.submenu = list
        menu.addItem(listItem)
    }

    private func updateItem() -> NSMenuItem {
        switch updater.state {
        case .checking:
            let i = NSMenuItem(title: L10n.checking, action: nil, keyEquivalent: "")
            i.isEnabled = false
            return i
        case let .available(version):
            return item(L10n.updateAvailable(version), #selector(installUpdate))
        case let .downloading(version):
            let i = NSMenuItem(title: L10n.downloading(version), action: nil, keyEquivalent: "")
            i.isEnabled = false
            return i
        default:
            return item(L10n.checkForUpdates, #selector(checkForUpdates))
        }
    }

    private func item(_ title: String, _ action: Selector, state: Bool? = nil, represented: String? = nil,
                      key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        if let state { i.state = state ? .on : .off }
        i.representedObject = represented
        return i
    }

    // MARK: Actions

    private func settingsChanged() {
        engine.update(settings.engineConfig)
        refreshIcon()
    }

    @objc private func toggleEnabled() {
        settings.enabled.toggle()
        settingsChanged()
    }

    @objc private func setScope(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let scope = Scope(rawValue: raw) else { return }
        settings.scope = scope
        settingsChanged()
    }

    @objc private func toggleHover() {
        settings.hoverFocus.toggle()
        settingsChanged()
    }

    @objc private func toggleExclusion(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        var list = settings.excludedBundleIDs
        if let index = list.firstIndex(of: id) { list.remove(at: index) } else { list.append(id) }
        settings.excludedBundleIDs = list
        settingsChanged()
    }

    @objc private func toggleLogin() { LoginItem.set(!LoginItem.isEnabled) }

    @objc private func toggleAutoUpdate() { settings.autoUpdateCheck.toggle() }

    @objc private func checkForUpdates() { updater.check(userInitiated: true) }

    @objc private func installUpdate() { updater.install() }

    @objc private func setLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let lang = AppLanguage(rawValue: raw) else { return }
        settings.language = lang
        refreshIcon()
    }

    @objc private func openGitHub() {
        NSWorkspace.shared.open(URL(string: "https://github.com/\(Updater.repo)")!)
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
