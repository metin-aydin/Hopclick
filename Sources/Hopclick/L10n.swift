import Foundation

/// Interface strings in English and Turkish. Turkish menu and button titles capitalise every word
/// (conjunctions and suffixes stay lower case); sentences are written normally.
enum L10n {
    private static var turkish: Bool {
        switch Settings.shared.language {
        case .english: return false
        case .turkish: return true
        case .system: return Locale.preferredLanguages.first?.hasPrefix("tr") ?? false
        }
    }

    private static func t(_ en: String, _ tr: String) -> String { turkish ? tr : en }

    static var enabled: String { t("Hopclick Enabled", "Hopclick Etkin") }
    static var scope: String { t("Works On", "Çalışma Alanı") }
    static var scopeAcross: String { t("Clicks on Another Display", "Başka Ekrandaki Tıklamalar") }
    static var scopeEverywhere: String { t("Every Inactive Window", "Etkin Olmayan Tüm Pencereler") }
    static var hoverFocus: String { t("Focus Display Under Pointer", "İmlecin Geçtiği Ekrana Odaklan") }
    static func disableIn(_ app: String) -> String { t("Disable in \(app)", "\(app) İçin Kapat") }
    static func enableIn(_ app: String) -> String { t("Enable in \(app)", "\(app) İçin Aç") }
    static var excludedApps: String { t("Excluded Apps", "Hariç Tutulan Uygulamalar") }
    static var noExcludedApps: String { t("None", "Yok") }
    static var clickToRemove: String { t("Click an app to enable it again", "Yeniden açmak için uygulamaya tıklayın") }
    static var launchAtLogin: String { t("Open at Login", "Oturum Açılınca Başlat") }
    static var autoUpdate: String { t("Check for Updates Automatically", "Güncellemeleri Kendiliğinden Denetle") }
    static var checkForUpdates: String { t("Check for Updates…", "Güncellemeleri Denetle…") }
    static var checking: String { t("Checking for Updates…", "Güncellemeler Denetleniyor…") }
    static func updateAvailable(_ v: String) -> String {
        t("Install Update \(v) and Relaunch", "\(v) Güncellemesini Kur ve Yeniden Başlat")
    }
    static func downloading(_ v: String) -> String { t("Downloading \(v)…", "\(v) İndiriliyor…") }
    static var language: String { t("Language", "Dil") }
    static var languageSystem: String { t("System", "Sistem") }
    static var grantPermission: String { t("Grant Accessibility Permission…", "Erişilebilirlik İzni Ver…") }
    static var permissionMissing: String {
        t("Waiting for Accessibility permission", "Erişilebilirlik izni bekleniyor")
    }
    static func about(_ v: String) -> String { t("Hopclick \(v)", "Hopclick \(v)") }
    static var openGitHub: String { t("Hopclick on GitHub", "GitHub'da Hopclick") }
    static var quit: String { t("Quit Hopclick", "Hopclick'ten Çık") }

    static var upToDateTitle: String { t("Hopclick is up to date", "Hopclick güncel") }
    static func upToDateBody(_ v: String) -> String {
        t("Version \(v) is the latest version.", "\(v) en son sürüm.")
    }
    static var updateErrorTitle: String { t("Update failed", "Güncelleme başarısız") }
    static var updateManualBody: String {
        t("This copy cannot update itself. The download page will open.",
          "Bu kopya kendini güncelleyemiyor. İndirme sayfası açılacak.")
    }
    static var ok: String { t("OK", "Tamam") }

    static var welcomeTitle: String { t("Allow Hopclick to help your clicks", "Hopclick'e tıklamalarınız için izin verin") }
    static var welcomeBody: String {
        t("""
          Hopclick makes the first click on a window on another display do what you aimed at, instead of only \
          focusing it. To see which window is under the pointer and bring it forward, it needs Accessibility \
          permission.

          Turn on Hopclick in System Settings › Privacy & Security › Accessibility. Hopclick starts working \
          as soon as the permission is on; no restart is needed.
          """,
          """
          Hopclick, başka ekrandaki bir pencereye yaptığınız ilk tıklamanın yalnız odak değiştirmek yerine \
          hedeflediğiniz işi yapmasını sağlar. İmlecin altındaki pencereyi bulup öne alabilmek için \
          Erişilebilirlik izni gerekir.

          Sistem Ayarları › Gizlilik ve Güvenlik › Erişilebilirlik bölümünde Hopclick'i açın. İzin verilir \
          verilmez Hopclick çalışmaya başlar; yeniden başlatmanız gerekmez.
          """)
    }
    static var openSettings: String { t("Open System Settings", "Sistem Ayarlarını Aç") }
    static var later: String { t("Later", "Sonra") }
}
