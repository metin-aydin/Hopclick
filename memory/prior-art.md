# Mevcut araçlar (araştırma: 2026-11-19)

Kaynak kodlar okundu (gh api ile, çalıştırılmadı). Hepsi MIT lisanslı.

## PirouzSR/ClickThrough — en yakın ve en olgun (Swift, macOS 13+)
https://github.com/PirouzSR/ClickThrough — 2026-09 açıldı, 0 yıldız, ~10 commit, ad-hoc imzalı (notarize yok).
Tam olarak bizim sorunu hedefliyor: **yalnız ekranlar arası tıklamalara** dokunur; tek ekranda hiçbir şey yapmaz.
Ayar yok (yalnız Aç/Kapat). Yöntem: **tıklamayı yutmaz, sentetik tık üretmez**:
1. `cgSessionEventTap`, `headInsertEventTap`, `defaultTap`; tap kendi thread'inde çalışır.
2. Tık odaklı ekranla aynı ekrandaysa dokunma (çoğu tık, ~0,3 ms).
3. Değilse imleç altındaki sıradan pencereyi bul, `NSRunningApplication.activate` + `AXRaise` + `kAXMain` +
   `kAXFocused`; **callback içinde bekle** (bütçe 200 ms) ta ki uygulamanın `kAXFocusedWindow`'u tıklanan pencere
   olsun; sonra **orijinal olayı değiştirmeden** döndür.
Ölçülmüş dersler (README):
- `activate()` yalnız istek; fare bırakılmadan uygulama gerçekten etkin olmazsa tık yine kaybolur → beklemek şart.
- `kAXFrontmost` yetmez; tıklanan pencerenin odaklı pencere olması beklenmeli.
- Etkinleşen uygulama kendi son penceresini öne alır (diğer ekrandaki) → main/focused isteği her 30 ms tekrarlanır.
- `AXRaise` yalnız z-sırası; AppKit uygulamaları için ayrıca main+focused yapılmalı (0/3 → 12/12).
- Etkinleştirme uygulamanın diğer ekranlardaki pencerelerini de öne alır → diğer ekranlardaki önceki en üst
  pencere 0/40/130/310 ms'de yeniden raise edilir.
- Tap süre aşımında sistemce kapatılır (1000 ms tamam, 1500 ms kapattı); "disabled" olayı ancak sonraki olayda
  gelir → her saniye watchdog ile yeniden etkinleştirme.
- Dokunulmayanlar: ⌘/⌃-tık, açık menü, menü çubuğu, Dock ve Dock yığınları, bildirimler (NC AX ağacı),
  Mission Control, sistem UI, sıradan olmayan pencereler (panel, popover, HUD), ekranı kaplayan backdrop pencereleri
  (Dock/NC/imleç penceresi "içinden bakılır").
- Maliyet: etkinleştiren tık 13–40 ms.

## laiglk/ClickThrough — alternatif yöntem (Swift, Fransızca arayüz, prototip 0.1)
https://github.com/laiglk/ClickThrough — 4 commit, 2 yıldız. **Her yerde** çalışır (aynı uygulamanın iki penceresi
dahil). Yöntem: ilk tık **yutulur**, AX çözümleme ayrı kuyrukta (tap callback'inde senkron AX yok), en çok 250 ms
bekletilir, sonra `tapPostEvent` ile **bir kez** yeniden gönderilir; mouseUp/drag olayları sıraya alınıp ardından
iletilir; kendi olaylarını işaretleyip yineleme engellenir. Uygulama bazlı dışlama, giriş açılışında başlatma,
sayaç. Sağ tık, değiştirici tuşlu tık, çoklu tık, masaüstü, pencere düğmeleri, modal sheet dışlanır.

## dainank/apple-click-through — Hammerspoon Lua betiği
https://github.com/dainank/apple-click-through — 21 yıldız, 27 commit, WIP. Tıkta `win:focus()` çağırıp olayı
geçirir (bekleme yok). İmleç tipine göre atlama (yeniden boyutlandırma, sürükleme), tam ekranda kapanma, menü
öğesi atlama. Açık sorunlar: metin alanı sorunu, her tıkta AXFocused yazınca pencerelerin zıplaması.

## sbmpost/AutoRaise — fareyle odak (hover), 2,8k yıldız
https://github.com/sbmpost/AutoRaise — tıklama değil, üzerine gelince raise/focus. `requireScreenChange`
seçeneği: yalnız fare altındaki pencere odaklı pencereden farklı ekrandaysa raise/focus. `delay`,
`requireMouseStop`, `ignoreApps`, `stayFocusedBundleIds`, `warpOnlyAcrossScreens`. Stage Manager'la iyi çalışmaz.

## Diğer
- BetterTouchTool: "Activate/Bring to Front Window Under Cursor" eylemi (tık göndermez).
- ⌘-tık: etkin olmayan penceredeki denetime etkinleştirmeden tıklar (yerleşik, sınırlı).
- Geliştirici tarafı: `acceptsFirstMouse(for:)` → true (yalnız kendi uygulamanda işe yarar).
