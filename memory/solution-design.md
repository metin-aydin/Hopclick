# Çözüm tasarımı (tartışma aşaması, sürüm 2 — araştırma sonrası 2026-11-19)

Ayrıntılı mevcut araç analizi: [[prior-art]].

## Sorunun nedeni

Etkin olmayan uygulamanın penceresine tıklanınca WindowServer önce uygulamayı etkinleştirir; tıklamanın hedefe
gidip gitmemesi görünümün `acceptsFirstMouse(for:)` dönüşüne bağlıdır, çoğu `false` döner. Odak sistem genelinde
tektir. Kritik: `activate()` asenkron; fare bırakılmadan uygulama gerçekten etkin ve **tıklanan pencere odaklı**
değilse tık yine yutulur.

## İki çekirdek yöntem (ikisi de sahada denenmiş)

| | Tut-ve-bırak (PirouzSR) | Yut-ve-yeniden-gönder (laiglk) |
|---|---|---|
| Olay | Orijinal olay callback'te bekletilip değiştirmeden döner | Olay yutulur, sonra `tapPostEvent` ile bir kez gönderilir |
| Sentetik tık | Yok → çift eylem imkânsız | Var → yineleme koruması gerekir |
| Bekleme | Tap thread'i ≤200 ms bloklanır | Asenkron, AX ayrı kuyrukta, ≤250 ms |
| Sürükleme/mouseUp | Doğal sırada | Kuyruğa alınıp sırayla iletilmeli |
| Karmaşıklık | Düşük | Yüksek |

**Öneri: tut-ve-bırak**, PirouzSR'nin ölçülmüş derslerini uygulayarak (tıklanan pencere odaklı olana kadar bekle,
main/focused isteğini 30 ms'de yinele, diğer ekranlardaki yerinden edilen pencereleri geri raise et, tap watchdog).

## Önerilen Hopclick kapsamı (mevcut araçlarda eksik olanlar)

1. Kapsam ayarı: **Ekranlar arası** (varsayılan) / **Her yerde** (aynı ekranda başka uygulama) .
2. İsteğe bağlı **ekrana girince odak** modu (AutoRaise `requireScreenChange` benzeri), varsayılan kapalı.
3. Uygulama bazlı dışlama listesi + menüden "Bu uygulamada devre dışı".
4. Developer ID imza + notarize + otomatik güncelleme (Sparkle) — mevcutların hepsi ad-hoc imzalı.
5. Erişilebilirlik izni için rehberli ilk açılış ekranı; izin gelince yeniden başlatmadan çalışma.
6. Türkçe + İngilizce arayüz; menü çubuğu simgesi; oturum açılınca başlat (`SMAppService`).

## Dokunulmayacak tıklar

⌘/⌃/⌥/⇧-tık, sağ tık, açık menü, menü çubuğu, Dock ve yığınları, bildirimler, Mission Control, sistem UI,
panel/popover/HUD, ekranı kaplayan backdrop pencereleri, dışlanan uygulamalar.

## İzinler ve dağıtım

Erişilebilirlik izni yeterli (Ekran Kaydı gerekmez; pencere başlıkları okunmaz). App Sandbox ile çalışmaz → Mac App
Store yok; GitHub Releases.
