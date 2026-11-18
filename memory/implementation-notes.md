# Uygulama notları (2026-11-19, sürüm 0.1.0)

## Yapı

- `Package.swift` — SwiftPM, macOS 13+, Swift 5 dil kipi, üçüncü taraf bağımlılık yok. Xcode projesi yok;
  `.app` paketi `scripts/build-app.sh` ile elle kurulur (Info.plist'teki `__VERSION__`/`__BUILD__` yer tutucuları).
- `Sources/HopclickCore` — saf karar mantığı (AppKit/AX yok), birim testli: `ClickPolicy.decide`, `focusDisplay`,
  `windowsToRestore`, `Geometry`, `Version`.
- `Sources/Hopclick` — uygulama: `EventTap` (ayrı thread, aktif tap), `ClickEngine` (karar + hover modu),
  `Activator` (AX ile öne alma ve bekleme), `AX`, `WindowServer` (CGWindowList, ekranlar), `Updater`, `LoginItem`,
  `Settings` (UserDefaults), `L10n` (en/tr, kod içinde sözlük), `StatusIcon` (çizilmiş şablon simge), `AppDelegate`.
- Bundle id: `app.hopclick.Hopclick`. Ayarlar UserDefaults bu alan adında.

## Tıklama akışı

1. Tap maskesi leftMouseDown + leftMouseUp + leftMouseDragged (up/drag yalnız sıra korunsun diye; maskede olmayan
   olaylar tap'i atlar ve bekletilen down'u geçebilir).
2. ⌘/⌃ basılıysa dokunma. Pencere listesi + ekranlar okunur, `ClickPolicy.decide` çalışır.
3. `activate` kararında ek denetim: uygulama `.prohibited` değil, dışlama listesinde değil, ve
   `AXUIElementCopyElementAtPosition` ile imleç altındaki öğenin pid'i hedef pencerenin pid'iyle aynı (Dock, bildirim,
   Mission Control tam ekran pencere içinde çizilir; bu tek test hepsini yakalar — PirouzSR'nin Dock/NC'ye özel
   denetimlerinin yerine).
4. `Activator.activate`: AX penceresi CG sınırlarıyla eşlenir; window `AXMain`+`AXFocused`+`AXRaise`; uygulama
   `AXFrontmost = true` (olmazsa `NSRunningApplication.activate`). 15 ms'de bir yoklanır, 30 ms'de bir odak isteği
   yinelenir, en çok 200 ms. Hazır koşulu: uygulama frontmost VE `AXFocusedWindow == tıklanan pencere`.
5. Diğer ekranlarda yerinden edilen pencereler 0/40/130/310 ms'de yeniden `AXRaise` edilir (ayrı kuyrukta).
6. Orijinal olay değiştirilmeden döner. Watchdog her saniye tap'i yeniden etkinleştirir.

## Hover modu ("İmlecin Geçtiği Ekrana Odaklan", varsayılan kapalı)

`NSEvent.addGlobalMonitorForEvents(.mouseMoved)`; imleç başka ekrana geçip 150 ms orada kalırsa ve fare tuşu basılı
değilse, kapsam "ekranlar arası" kabul edilip aynı karar + etkinleştirme ayrı kuyrukta yapılır.

## İzin ve oturum öğesi

- İzin yoksa açılışta logolu karşılama uyarısı; "Sistem Ayarlarını Aç" → `AXIsProcessTrustedWithOptions(prompt)` +
  ayar sayfası. 2 sn'de bir `AXIsProcessTrusted` yoklanır; izin gelince yeniden başlatmadan çalışır.
- İlk açılışta oturum öğesi kaydı yalnız `/Applications` veya `~/Applications`'tan çalışan kopyada yapılır
  (geliştirme derlemesi bir kez kendini kaydetmişti; `--unregister-login-item` argümanı bunu siler).
- İkinci kopya açılırsa kendini kapatır.

## Doğrulananlar (2026-11-19, yerel)

- `swift test`: 16 test geçti. `UNIVERSAL=1 scripts/build-app.sh`: x86_64 + arm64. Açılınca süreç `UIElement`
  (Dock simgesi yok), karşılama uyarısı logolu görünüyor. `scripts/make-dmg.sh` çalışıyor (hdiutil "deprecated"
  uyarısı veriyor, çıktı sorunsuz).
- Henüz denenmedi: gerçek çoklu monitörde Erişilebilirlik izni verilmiş tıklama davranışı, CI'da imzalı sürüm.
