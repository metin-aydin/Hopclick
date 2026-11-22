# Proje durumu

## 2026-11-19 — Başlangıç

- Kullanıcı isteği: çoklu monitörde ekran değiştirince yeni ekrandaki pencereye ilk tıklamanın yalnız odak için
  harcanması sorununu çözmek. Önce çözüm tartışılacak, karar netleşince kullanıcı GitHub'da depo açıp klonlatacak.
- README görsellerle desteklenecek; uygulama açıklaması ve logo dahil (bkz. [[branding]]).
- Bu klasörde şimdilik yalnız `CLAUDE.md`, `AGENTS.md`, `memory/` var.

## Klonlama notu

Depo açılınca bu klasör boş olmadığı için doğrudan `git clone <url> .` çalışmaz. Yol: geçici klasöre klonla,
`.git`'i ve depo dosyalarını buraya taşı, ardından hafıza dosyalarını ilk commit'e ekle.

## 2026-11-19 — Araştırma

Kullanıcı önce mevcut araç olup olmadığını araştırmamı istedi. Bulundu: PirouzSR/ClickThrough sorunu birebir
çözüyor (yalnız ekranlar arası, ayarsız, ad-hoc imzalı, 2 aylık). Ayrıntı [[prior-art]], güncel tasarım
[[solution-design]]. Kullanıcıya soruldu: mevcut aracı mı kullanalım, yoksa MultiMac'i eksikleri kapatarak mı
yazalım.

## Açık sorular (ilk turda soruldu)

1. Çekirdek davranış: "tıklamayı yut → pencereyi öne al → tıklamayı yeniden gönder" (önerilen) ve/veya
   "fare ekran değiştirince altındaki pencereye odak ver".
2. Kapsam: yalnız ekranlar arası geçişte mi, yoksa aynı ekranda başka uygulamaya tıklarken de mi?
3. Teknoloji: Swift + menü çubuğu uygulaması, macOS 13+ (önerilen).
4. Dağıtım: GitHub Releases, Developer ID imzalı + notarize (App Store sandbox'ı event tap'e izin vermez).

## 2026-11-19 — Karar: kendimiz yazıyoruz, isim değişecek

Kullanıcı: "yazalım ama adını değiştirelim, daha akılda canlandırıcı bir isim olsun". "MultiMac" adı bırakılacak.
Önerilen adaylar (GitHub çakışması 2026-11-19'da tarandı, macOS repo sayısı):
- **Hopclick** (öneri) — tık ekrandan ekrana "zıplar"; JumpDesk ile aile hissi. 0 çakışma.
- ClickBridge — ekranlar arası köprü. 0 çakışma (logo kemeri Burrow'a benzeyebilir).
- Landfall — tık hedefe "iner". 1 alakasız repo.
- Baton — odak devri; 20 repo, kalabalık.
- FirstClick — düz; Hyprland eklentisi hypr-firstclick var.
Kullanıcının seçimi bekleniyor. Seçilince CLAUDE.md başlığı, branding.md ve tüm hafıza yeni adla güncellenir.

## 2026-11-19 — Karar: ad **Hopclick**

Kullanıcı Hopclick'i seçti. CLAUDE.md, MEMORY.md, solution-design.md güncellendi. Logo işareti fikri: iki ekran
arasında kavisli zıplama oku + imleç (bkz. [[branding]]). Sıradaki adım: kullanıcı GitHub'da `Hopclick` deposunu
açıp URL'yi verecek; klasör boş olmadığı için geçici klasöre klonlanıp buraya taşınacak.

## 2026-11-19 — Depo kuruldu, 0.1.0 yazıldı

- Depo `github.com/metin-aydin/Hopclick` (public, boştu) geçici klasöre klonlandı, `.git` bu klasöre taşındı.
- Kullanıcı istekleri: Dock'ta simge olmasın (LSUIElement + accessory), dallar `development` ve `master`, `master`
  varsayılan, ikisi korumalı, güncelleme sistemi JumpDesk gibi (bkz. [[release-update]]).
- Yazılanlar: Swift uygulaması ([[implementation-notes]]), logo `assets/logo.svg` (onaylanan çizim: iki ekran,
  noktalı zıplama yayı, sağ ekranda imleç), `Resources/AppIcon.icns`, README + `docs/images/*.svg` görselleri
  (önce/sonra, nasıl çalışır, menü), CI ve sürüm iş akışları, PR şablonu, MIT lisansı.
- Kullanıcının yapması gereken: `release` ortamına imza gizli değerlerini girmek (JumpDesk'tekiyle aynı 5 değer).
  Girilmeden `master`'a birleşen PR'ın sürüm işi "Secret … is missing" hatasıyla durur.
- İlk push sonrası: CI (`check`) master ve development'ta geçti. Release işi beklendiği gibi "Secret CSC_LINK is
  missing" ile durdu, taslak sürüm silindi.
- Otomatik güvenlik incelemesi 2 bulgu verdi, düzeltildi: güncelleme imza denetimi sıkılaştırıldı; release işleri ve
  ortamı yalnız master'a kısıtlandı. Düzeltme `development`'a gönderildi; master'a PR ile girecek.

## 2026-11-19 — İlk PR

- PR #1 "Hopclick 0.1.0" (development → master) açıldı; açıklaması 0.1.0 sürüm notu (İngilizce, kullanıcıya yönelik).
- `release` ortamında gizli değer yok (API ile denetlendi). Kullanıcı değerleri girmeden PR birleştirilmemeli;
  birleşirse sürüm işi "Secret … missing" ile durur, taslak silinir (zarar yok, tekrar denenebilir: workflow_dispatch).
- Birleştirme kararı kullanıcıda.
- Kullanıcı "Burrow'daki bilgileri kullan" dedi: APPLE_TEAM_ID eklendi, kalan dört değer için betik eklendi; kullanıcı çalıştıracak.
- Beş release gizli değeri tamam (kullanıcı betikle girdi). İlk `gh pr merge` otomatik izin denetimince reddedildi;
  kullanıcı "Evet, birleştir" deyince PR #1 merge commit ile birleştirildi.

## 2026-11-19 — 0.1.0 yayımlandı

- https://github.com/metin-aydin/Hopclick/releases/tag/v0.1.0 : `Hopclick-0.1.0.dmg` + `.zip`. İndirilen zip'te
  `spctl`: accepted, Notarized Developer ID, ekip JTRUY8Y2ZF; `stapler validate` geçti.
- Kullanıcı isteğiyle depo açıklaması (README'deki tanıtım, İngilizce) ve konular (macos, menu-bar-app,
  multi-monitor, multiple-displays, click-through, accessibility, focus, swift, productivity) `gh repo edit` ile yazıldı.
- `development` master ile eşitlendi (ff). Açık: gerçek çoklu monitörde izin verilmiş davranış testi; uygulama içi
  güncellemenin ilk gerçek denemesi 0.1.1 çıkınca olacak.

## 2026-11-22 — Hover modu "her zaman çalışmıyor"

- Kullanıcı: "Focus Display Under Pointer" diğer monitöre geçince her zaman çalışmıyor; loglara bakarak incele.
- Kullanıcının ayarları: `enabled=1`, `hoverFocus=1`, `scope=everywhere`; çalışan kopya `/Applications/Hopclick.app` (0.1.0).
- Bulgu: Hopclick hiç log yazmıyordu (3 saatlik sistem logunda iz yok). Kodda kök neden bulundu: tek seferlik deneme
  (ayrıntı [[implementation-notes]] "Hover modu"). Düzeltme + `os.Logger` loglama eklendi, `swift test` 16/16 geçti,
  `build/Hopclick.app` (0.1.1-dev, ad-hoc) derlendi. Commit yapılmadı; kullanıcının gerçek monitörde denemesi bekleniyor.
- Kullanıcı yeni derlemeyi `build/Hopclick.app`'tan açtı (pid 80951). İlk 3 dakikada `notice` log yok: ya henüz
  etkinleştirme olmadı ya da ad-hoc imza yüzünden Erişilebilirlik izni yeniden verilmeli. Canlı log izlemesi önerildi.
- Kullanıcının canlı logu (2026-11-22 22:32): ilk hover etkinleştirmesi Chrome (pid 3922) `ready=false in 221 ms`,
  ardından imleç her durduğunda `retry later: focusDisplayUnknown`. Tıklamada Claude (pid 18502) de `ready=false 243 ms`.
- Kök neden 2: `ClickPolicy.focusDisplay` öndeki uygulamanın *ilk* sıradan penceresini alıyordu; o pencere hiçbir ekrana
  düşmüyorsa yedeğe geçmeden nil dönüyordu. Düzeltildi: ekrana düşmeyen pencereler atlanıyor (2 yeni test, 18/18).
  Varsayım (Chrome'un ekran dışı penceresi) henüz doğrulanmadı; `focusDisplayUnknown` logu artık öndeki pid'in
  pencerelerini ve ekranları yazıyor. Doğrulama sırasında yalnız 1 ekran bağlıydı, yeniden üretilemedi.
- Açık: `ready=false` — Chrome/Claude 200 ms'lik bütçede `AXFrontmost` + `AXFocusedWindow == hedef` koşulunu
  sağlamıyor. Pencere eşleşmesi (CG sınırı ↔ AX çerçevesi) veya Electron/Chrome'un odak bildirimi şüpheli; incelenmedi.
- `ready=false` incelendi (kullanıcı "önce ready=false'a bak" dedi). Neden: bekleme döngüsü, etkinleşmekte olan
  uygulamaya yapılan ve bloke olan AX çağrılarıyla bütçeyi tüketiyordu. Düzeltme: frontmost sinyali didActivate
  bildiriminden, yoklama zaman aşımı 25 ms, hover bütçesi 600 ms, ayrıntılı Outcome logu. 18/18 test,
  `build/Hopclick.app` yeniden derlendi. Çoklu monitörde henüz denenmedi; commit yok. Özel API
  (`_SLPSSetFrontProcessWithOptions`, AutoRaise/yabai) gerekirse bir sonraki seçenek, kullanıcıya sorulmadı.
- 2026-11-23: kullanıcı yeni derlemeyi iki monitörde deneyeceğini söyledi; logu bekleniyor.
- 2026-11-23 kullanıcı logu (3 ekran: ana 1728, sağ 1920, sol 1600): tüm etkinleştirmeler `ready=true` (10–180 ms,
  uç değerler 356/704 ms); `focusDisplayUnknown` yok. Yeni hata: Chrome'u öne aldıktan sonra Claude ekranına dönünce
  `done: sameDisplay`. Neden ve çözüm: Chrome yardımcı pencereleri → `HelperWindows` (bkz. [[implementation-notes]]).
  19/19 test, `build/Hopclick.app` derlendi; kullanıcı denemesi bekleniyor, commit yok.
- 2026-11-23 01:40 kullanıcı logu (HelperWindows'lu derleme): 40 ekran geçişinin hepsinde Chrome ↔ Claude
  etkinleştirmesi oldu, hepsi `ready=true` (6–160 ms). Arada görülen `done: sameDisplay` satırları aynı geçişteki
  ikinci duruşun zararsız sonucu (etkinleştirme zaten yapılmış). Hover sorunu çözüldü sayılır. Açık: Chrome sekme
  şeridi bölgesi (`window matched: false`), uzun süreli kullanım. Commit henüz yok.
- 2026-11-23: kullanıcı isteği "son build'i sil, push'la, master'a merge'le, yeni sürüm yayımlansın". `build/` silindi
  (çalışan geliştirme kopyası kapatıldı; /Applications'taki 0.1.0 güncellemeyle 0.1.1'e geçecek). development → master
  PR'ı açılıp CI geçince birleştirilecek; VERSION 0.1.0 kaldığı için sürüm betiği 0.1.1 üretir.
