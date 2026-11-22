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
   `AXFrontmost = true` (yalnız `.cannotComplete` dışı bir hatada `NSRunningApplication.activate`). 15 ms'de bir
   yoklanır, 30 ms'de bir odak isteği yinelenir. Bütçe: tıklama 200 ms, hover 600 ms. Hazır koşulu: frontmost VE
   `AXFocusedWindow == tıklanan pencere`. "Frontmost" önce `ClickEngine.frontmostPID`'den (didActivate bildirimi,
   IPC yok), yoksa AX'ten okunur; yoklama çağrılarının zaman aşımı 25 ms. Sonuç `Activator.Outcome` loglanır
   (window matched / frontmost / focused window: target|other|unknown).
   **Ölçüm (2026-11-22, tek ekran, Finder/Claude):** etkinleşen uygulamanın ana thread'i meşgulken her AX çağrısı
   bekler. `AXFrontmost` set 80–211 ms sürdü ve çoğu kez −25204 (`cannotComplete`) döndü ama etkinleştirme oldu;
   okuma 28–74 ms. didActivate bildirimi 4–100 ms'de geldi. Run loop'u olmayan thread'de
   `NSWorkspace.frontmostApplication` bayat kalır (kullanma). macOS 14+'te arka plan sürecinin `activate()`'i
   yok sayılabilir. Chrome'un katman 0, alfa 1, hiçbir ekrana düşmeyen çok sayıda yardımcı penceresi var
   (y=−330 vb.) → `focusDisplay` düzeltmesinin nedeni bu (doğrulandı).
5. Diğer ekranlarda yerinden edilen pencereler 0/40/130/310 ms'de yeniden `AXRaise` edilir (ayrı kuyrukta).
6. Orijinal olay değiştirilmeden döner. Watchdog her saniye tap'i yeniden etkinleştirir.

## Hover modu ("İmlecin Geçtiği Ekrana Odaklan", varsayılan kapalı)

`NSEvent.addGlobalMonitorForEvents(.mouseMoved)`, yalnız ana thread. İmleç başka ekrana geçince hover "silahlanır"
(`hoverArmed`); her `mouseMoved`'da 150 ms'lik zamanlayıcı yeniden kurulur, yani imleç **durunca** denenir. Karar
`.acrossDisplays` kapsamıyla verilir. Silah yalnız etkinleştirme yapılınca veya sonuç `sameDisplay` /
`alreadyFrontWindow` / `ownApplication` olunca iner; masaüstü, menü çubuğu, Dock, overlay, AX vetosu, basılı fare
tuşu "sonra yeniden dene" demektir. `hoverGeneration` her ekran geçişinde artar; eski denemenin geç sonucu yeni
geçişin silahını indiremez.

**2026-11-22 hatası (düzeltildi):** eski kod ekran değişince yalnız bir kez, geçişten 150 ms sonra deniyordu ve
`hoverDisplay`'i sonuçtan bağımsız güncelliyordu. İmleç o anda masaüstü/menü çubuğu/Dock üstündeyse veya hâlâ
hareket ediyorsa deneme boşa gidiyor, aynı ekranda pencereye gelince bir daha denenmiyordu → "her zaman çalışmıyor".
Bilinçli yan etki: klavyeyle diğer ekrandaki uygulamaya geçip imleci silahlı ekranda hafif oynatmak, silah inmediyse
odağı geri alabilir (silah ilk başarılı etkinleştirmede iner, o yüzden pratikte nadir).

## Loglama (2026-11-22)

`Sources/Hopclick/Log.swift`: `Logger(subsystem: "app.hopclick.Hopclick", category: "click" | "hover")`.
Etkinleştirmeler `notice` (diske yazılır), pas/yeniden deneme nedenleri `info`, ayrıntı `debug` (bunlar varsayılan
olarak yalnız bellekte; `log show` göstermez). Canlı izleme:
`/usr/bin/log stream --level debug --predicate 'subsystem == "app.hopclick.Hopclick"'`. **Tuzak:** zsh'te `log`
yerleşik komuttur ("too many arguments"), tam yol `/usr/bin/log` yazılmalı. info/debug'ı kalıcı yapmak için
(sudo): `sudo log config --subsystem app.hopclick.Hopclick --mode persist:debug`. 0.1.0'da hiç log yoktu; sistem
logunda Hopclick izi çıkmaması bundandı.

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

## Tuzak: eski `.build` önbelleği

Klasör `MultiMac`'ten `Hopclick`'e taşındığı için `.build` içindeki PCH eski yolu gösteriyordu ("PCH was compiled
with module cache path …/MultiMac/…"). Çözüm: `rm -rf .build` (2026-11-22).

## Yardımcı pencereler (`HelperWindows`, 2026-11-23)

Chrome (büyük olasılıkla tam ekran araç çubuğu/popup barındırıcıları) katman 0, alfa 1, ekranda görünen, CG
özellikleriyle (SharingState, StoreType, MemoryUsage) gerçek pencerelerden **ayırt edilemeyen** pencereler tutuyor;
bazıları Chrome'un hiç penceresi olmayan ekranda (ör. Claude'un ana ekranında (0,63,1920×41)). Chrome öndeyken
`focusDisplay` bunları alıp odağı yanlış ekranda sanıyordu → diğer ekrana geçince `done: sameDisplay`, hiçbir şey
olmuyordu. Ayırt eden tek şey AX alt rolü: yardımcılar `AXUnknown`, gerçekler `AXStandardWindow`.
AX çağrıları Chrome'da 10–70 ms, zaman aşımı 25 ms verilse bile ilk temas 236 ms sürebiliyor, sık −25204 dönüyor;
`AXFocusedWindow` Chrome'da çoğu kez cevapsız, `AXMainWindow` daha güvenilir. Bu yüzden tap yolunda AX yok:
`HelperWindows` pencere numarasına göre önbellek tutar (tür pencere ömrü boyunca değişmez). Sınıflandırma:
didActivate bildiriminde ve her mouse-down'da arka planda (`classifyAsync`), hover denemesinde eşzamanlı (öndeki
uygulama + imleç altındaki pencerenin uygulaması). `WindowServer.onScreenWindows` `isHelper`'ı doldurur;
`isOrdinary` yardımcıları dışlar, `topmostWindow` onların arkasına bakar. AX karşılığı olmayan CG pencereleri
yardımcı sayılmaz (temkinli).
Açık: Chrome'un AX karşılığı olmayan üst pencereleri (ör. (1728,30,1920×158), sekme şeridi bölgesi) hedef olunca
`window matched: false` → yalnız uygulama öne alınır, Chrome diğer ekrandaki penceresini odaklayabilir.
