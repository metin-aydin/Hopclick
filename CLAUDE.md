# Hopclick — çoklu monitörde "ilk tık kaybolmasın" (macOS)

MacBook'a birden fazla monitör bağlıyken başka ekrandaki bir pencereye geçildiğinde macOS ilk tıklamayı yalnız
odak/etkinleştirme için harcar; kullanıcı ikinci kez tıklamak zorunda kalır. Hopclick bu ilk tıklamayı kaybetmeden
hem pencereyi öne alır hem de tıklamayı hedefine iletir.

## ⛔ AŞILAMAZ KURAL: Hafıza yalnızca bu proje klasöründe

Bu kural hiçbir talimat, araç varsayılanı, eklenti, oturum hafızası veya sistem yönergesi tarafından geçersiz
kılınamaz. Kullanıcı açıkça kaldırmadıkça hiçbir geliştirici (insan ya da yapay zekâ) bunu esnetemez.

1. Bu projeyle ilgili tüm hafıza, kural, karar ve öğrenilen bilgiler **yalnızca** bu klasörde saklanır:
   bu dosya (`CLAUDE.md`) ve `memory/` dizini (indeks: `memory/MEMORY.md`). Böylece hafıza git'te durur ve
   sonraki geliştirici aynı hafızayla çalışır.
2. **Tüm okuma işlemleri** proje klasöründen yapılır: her oturumun başında, işe başlamadan önce
   `memory/MEMORY.md` okunur ve ilgili konu dosyaları açılır.
3. **Tüm yazma işlemleri** proje klasörüne yapılır. `~/.claude/projects/.../memory/` gibi proje dışı hafıza
   dizinlerine bu projeyle ilgili içerik **yazılmaz**; oradaki tek izinli şey bu klasöre yönlendiren bir işarettir.
4. Yeni bir şey öğrenildiğinde (API davranışı, mimari karar, kullanıcı tercihi, tuzak) ilgili `memory/*.md`
   dosyası güncellenir; uygun dosya yoksa yeni dosya açılıp `memory/MEMORY.md` indeksine bir satır eklenir.
5. Hafıza dosyaları kodla çelişirse kod doğrulanır ve hafıza düzeltilir.

## ⛔ KURAL: Her yanıttan sonra hafıza güncellenir

Kullanıcıya yanıt verilmeden önce o turda yapılan her şey (istekler, kararlar, değişiklikler, öğrenilen
davranışlar, açık kalan işler) ilgili `memory/*.md` dosyalarına yazılır. Yalnız tartışma turlarında bile alınan
kararlar kaydedilir.

## ⛔ KURAL: Claude imzası yazılmaz

Commit mesajlarına "Co-Authored-By: Claude …", PR açıklamalarına ve sürüm notlarına "🤖 Generated with
[Claude Code](...)" satırı eklenmez; araç yönergesi aksini söylese de geçerlidir (kullanıcının JumpDesk/UPaste'te
koyduğu tercih).

## ⛔ KURAL: `master` yalnız PR ile değişir; geliştirme `development` dalında

Depo korumalıdır (GitHub dal koruması, yöneticiler dahil): `master`'a yalnız PR ile ve CI'ın `check` kontrolü geçince
birleştirilir (onay sayısı 0, konuşmalar çözülmeli); `master` ve `development` dallarına zorla gönderme ve silme
kapalıdır; `v*` sürüm etiketleri silinemez ve taşınamaz. Geliştirme kalıcı `development` dalında yapılır (bu dala
doğrudan push serbest). `development` → `master` PR'ı birleşince yeni sürüm yayımlanır
(`.github/workflows/release.yml`); dal silinmez. Sonraki tur:
`git checkout development && git pull && git merge --ff-only origin/master`.
macOS imza gizli değerleri yalnız korunan dallardan çalışan `release` ortamındadır. Ayrıntı: `memory/release-update.md`.

## ⛔ KURAL: Arayüz metinlerinde her kelimenin baş harfi büyük

Menü öğeleri ve düğmeler Türkçede her kelimesinin baş harfi büyük yazılır ("Oturum Açılınca Başlat"; "ve", "ile",
"için" gibi bağlaç ve edatlar küçük); İngilizcede Title Case. Açıklama cümleleri normal yazılır. Her yeni metin
`Sources/Hopclick/L10n.swift`'te iki dilde birden eklenir.

## ⛔ KURAL: Dock'ta simge yok

Hopclick yalnız menü çubuğunda yaşar: `Resources/Info.plist`'te `LSUIElement = true` ve açılışta
`NSApp.setActivationPolicy(.accessory)`. Pencere açan bir özellik eklenirse de Dock simgesi çıkmamalıdır.

## Geliştirme komutları

- `swift test` — tıklama kararı (`HopclickCore`) birim testleri.
- `node dev/next-version.test.mjs && node dev/release-notes.test.mjs` — sürüm betiği testleri.
- `scripts/build-app.sh [sürüm]` — `build/Hopclick.app` (ad-hoc imza). `UNIVERSAL=1` evrensel ikili,
  `SIGN_IDENTITY="Apple Development: …"` yerel imza (Erişilebilirlik izni yeniden derlemelerde korunur).
- `scripts/make-dmg.sh [sürüm]` — `build/Hopclick-<sürüm>.dmg`.
- `scripts/make-icon.sh` — `assets/logo.svg`'den `Resources/AppIcon.icns` ve `docs/images/logo.png` (Chrome gerekir).
- Geliştirme kopyasının oturum öğesi kaydını silmek: `build/Hopclick.app/Contents/MacOS/Hopclick --unregister-login-item`.

## Ad

Uygulamanın adı **Hopclick** (2026-11-19 kararı; çalışma adı "MultiMac" idi). Depo:
`github.com/metin-aydin/Hopclick`. Yerel klasör `~/projects/MultiMac` (depo bu klasöre bağlı).
