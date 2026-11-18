import AppKit
import HopclickCore
import Security

/// In-app updates from GitHub Releases, modelled on JumpDesk: checks 15 s after launch and every 6 hours (when
/// enabled), shows the new version in the menu, and on request downloads the release zip, verifies that it is signed by
/// the same developer team as the running app, swaps the app bundle and relaunches.
final class Updater {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(version: String)
        case downloading(version: String)
        case failed(String)
    }

    static let repo = "metin-aydin/Hopclick"
    static let releasesPage = URL(string: "https://github.com/\(repo)/releases/latest")!
    private static let latestAPI = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!
    private static let firstCheckDelay: TimeInterval = 15
    private static let checkInterval: TimeInterval = 6 * 60 * 60

    private(set) var state: State = .idle { didSet { onChange?() } }
    var onChange: (() -> Void)?
    private var assetURL: URL?
    private var timer: Timer?

    let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"

    var availableVersion: String? {
        if case let .available(v) = state { return v }
        return nil
    }

    func start() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.firstCheckDelay) { [weak self] in
            self?.autoCheck()
        }
        timer = Timer.scheduledTimer(withTimeInterval: Self.checkInterval, repeats: true) { [weak self] _ in
            self?.autoCheck()
        }
    }

    private func autoCheck() {
        guard Settings.shared.autoUpdateCheck else { return }
        check(userInitiated: false)
    }

    // MARK: Check

    func check(userInitiated: Bool) {
        if case .checking = state { return }
        if case .downloading = state { return }
        state = .checking
        var request = URLRequest(url: Self.latestAPI)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Hopclick/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async { self?.handleRelease(data: data, error: error, userInitiated: userInitiated) }
        }.resume()
    }

    private struct Release: Decodable {
        struct Asset: Decodable {
            let name: String
            let browser_download_url: URL
        }
        let tag_name: String
        let draft: Bool
        let prerelease: Bool
        let assets: [Asset]
    }

    private func handleRelease(data: Data?, error: Error?, userInitiated: Bool) {
        guard let data, let release = try? JSONDecoder().decode(Release.self, from: data),
              !release.draft, !release.prerelease else {
            state = .failed(error?.localizedDescription ?? "GitHub")
            if userInitiated { alert(L10n.updateErrorTitle, state.message) }
            return
        }
        let version = release.tag_name.hasPrefix("v") ? String(release.tag_name.dropFirst()) : release.tag_name
        guard Version.isNewer(version, than: currentVersion) else {
            state = .upToDate
            if userInitiated { alert(L10n.upToDateTitle, L10n.upToDateBody(currentVersion)) }
            return
        }
        assetURL = release.assets.first { $0.name == "Hopclick-\(version).zip" }?.browser_download_url
        state = .available(version: version)
    }

    // MARK: Install

    func install() {
        guard case let .available(version) = state else { return }
        guard let assetURL, let team = Self.teamIdentifier(of: Bundle.main.bundleURL),
              FileManager.default.isWritableFile(atPath: Bundle.main.bundleURL.deletingLastPathComponent().path)
        else {
            alert(L10n.updateErrorTitle, L10n.updateManualBody)
            NSWorkspace.shared.open(Self.releasesPage)
            return
        }
        state = .downloading(version: version)
        URLSession.shared.downloadTask(with: assetURL) { [weak self] file, _, error in
            let result = Result { () -> URL in
                guard let file else { throw UpdateError(error?.localizedDescription ?? "download") }
                return try Self.unpackAndVerify(zip: file, version: version, team: team)
            }
            DispatchQueue.main.async { self?.finishInstall(result, version: version) }
        }.resume()
    }

    private func finishInstall(_ result: Result<URL, Error>, version: String) {
        switch result {
        case let .failure(error):
            state = .failed(error.localizedDescription)
            alert(L10n.updateErrorTitle, error.localizedDescription)
            state = .available(version: version)
        case let .success(newApp):
            relaunch(replacingWith: newApp)
        }
    }

    private struct UpdateError: LocalizedError {
        let errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }

    /// Unzips the release and checks the new app: same bundle identifier, the expected version, and a valid signature
    /// from the same Developer ID team as the running copy.
    private static func unpackAndVerify(zip: URL, version: String, team: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("Hopclick-update-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let ditto = Process()
        ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        ditto.arguments = ["-x", "-k", zip.path, dir.path]
        try ditto.run()
        ditto.waitUntilExit()
        guard ditto.terminationStatus == 0 else { throw UpdateError("unzip failed") }

        let app = dir.appendingPathComponent("Hopclick.app")
        guard let bundle = Bundle(url: app), bundle.bundleIdentifier == Bundle.main.bundleIdentifier,
              bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String == version
        else { throw UpdateError("unexpected package contents") }

        var code: SecStaticCode?
        var requirement: SecRequirement?
        let text = "anchor apple generic and identifier \"\(bundle.bundleIdentifier!)\" "
            + "and certificate leaf[subject.OU] = \"\(team)\""
        guard SecStaticCodeCreateWithPath(app as CFURL, [], &code) == errSecSuccess, let code,
              SecRequirementCreateWithString(text as CFString, [], &requirement) == errSecSuccess,
              SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSCheckAllArchitectures), requirement)
                == errSecSuccess
        else { throw UpdateError("signature check failed") }
        return app
    }

    /// Developer ID team of a signed app; nil for unsigned or ad-hoc signed copies (development builds), which do
    /// not update themselves.
    static func teamIdentifier(of url: URL) -> String? {
        var code: SecStaticCode?
        var info: CFDictionary?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code,
              SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info)
                == errSecSuccess,
              let dict = info as? [String: Any] else { return nil }
        return dict[kSecCodeInfoTeamIdentifier as String] as? String
    }

    /// Replaces the running bundle once this process has exited, then opens the new copy. The bundle keeps its path
    /// and Developer ID requirement, so the Accessibility permission stays granted.
    private func relaunch(replacingWith newApp: URL) {
        let target = Bundle.main.bundleURL.path
        let script = """
        while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
        rm -rf "$2.old" && mv "$2" "$2.old" && /usr/bin/ditto "$3" "$2" && rm -rf "$2.old" \
          || { rm -rf "$2"; mv "$2.old" "$2"; }
        rm -rf "$(dirname "$3")"
        /usr/bin/open "$2"
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script, "hopclick-update", String(getpid()), target, newApp.path]
        do {
            try process.run()
            NSApp.terminate(nil)
        } catch {
            state = .failed(error.localizedDescription)
            alert(L10n.updateErrorTitle, error.localizedDescription)
        }
    }

    private func alert(_ title: String, _ body: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.addButton(withTitle: L10n.ok)
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

private extension Updater.State {
    var message: String {
        if case let .failed(text) = self { return text }
        return ""
    }
}
