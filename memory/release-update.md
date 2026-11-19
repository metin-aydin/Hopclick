# Dallar, sürüm ve otomatik güncelleme (JumpDesk modeli, 2026-11-19)

Kullanıcı isteği: dallar `development` ve `master`; `master` varsayılan dal; ikisi de korumalı; otomatik güncelleme
JumpDesk'teki gibi. JumpDesk'in ayarları GitHub API'den okunup birebir uygulandı.

## Dal koruması (JumpDesk'le aynı)

- `master`: yalnız PR; onay sayısı 0; CI kontrolü `check` zorunlu ve dal güncel olmalı (strict); yöneticiler dahil;
  zorla gönderme ve silme kapalı; konuşmalar çözülmeden birleşmez.
- `development`: doğrudan push serbest; zorla gönderme ve silme kapalı; yöneticiler dahil.
- `Release tags` kural seti: `refs/tags/v*` silinemez, güncellenemez, non-fast-forward yok.
- `release` ortamı: yalnız `master` dalından çalışır (özel dal kuralı; `development` de korumalı olduğu için
  "korunan dallar" seçeneği yeterli değildi). `release.yml`'deki işler ayrıca `github.ref == refs/heads/master`
  koşuluyla korunur (elle başlatma da yalnız master'dan); macOS imza gizli değerleri burada (`CSC_LINK` base64 p12,
  `CSC_KEY_PASSWORD`, `APPLE_ID`, `APPLE_APP_SPECIFIC_PASSWORD`, `APPLE_TEAM_ID`). Değerleri kullanıcı girer.
  2026-11-19: `APPLE_TEAM_ID` = Burrow'daki ekip (`JTRUY8Y2ZF`) Claude tarafından eklendi. Parolalı dört değer
  (`CSC_LINK`, `CSC_KEY_PASSWORD`, `APPLE_ID`, `APPLE_APP_SPECIFIC_PASSWORD`) Burrow'daki gibi kullanıcı tarafından
  `.github/scripts/set-release-secrets.sh <DeveloperID.p12>` ile girilir (gizli istem, stdin ile `gh secret set`).
  Claude parola/anahtar girmez; imza malzemesi bu Mac'te yok (Burrow'da `~/Downloads/apple-signing-*.zip` idi,
  sonra silindi, aslı kullanıcıda).
  2026-11-19 (sonra): kullanıcı zip'i yeniden Downloads'a koydu; `~/Downloads/hopclick-signing/` altına açıldı.
  Burrow'daki gibi .p12 parolaları bilinmediği için betik `developer-id.key cert.pem` kipinde kullanıcının terminal
  sekmesinde başlatıldı (anahtar-sertifika eşleşmesi geçti); parolaları kullanıcı yazdı. **Beş gizli değer de
  `release` ortamında** (20:33 UTC, `gh secret list --env release`). Açılan klasör ve zip Downloads'tan silindi.
- Birleştirmeden sonra dal silinmez. Sonraki tur: `git checkout development && git pull && git merge --ff-only origin/master`.

## Sürüm akışı (`.github/workflows/release.yml`)

`master`'a her push'ta: `dev/next-version.mjs` (VERSION dosyası son `v*` etiketinden büyükse o, değilse yama +1) →
sürüm notu birleştirilen PR açıklamasından (`dev/release-notes.mjs`), boşsa commit başlıklarından → taslak sürüm →
macOS'ta evrensel (arm64+x86_64) derleme, Developer ID imza, hardened runtime, notarize + staple → `Hopclick-X.Y.Z.zip`
(güncelleyici için) ve `Hopclick-X.Y.Z.dmg` yüklenir → sürüm yayımlanır; hata olursa taslak silinir. Gizli değer
eksikse yayın durur (imzasız uygulama kendini güncelleyemez).

## Uygulama içi güncelleme (`Sources/Hopclick/Updater.swift`)

Electron'daki electron-updater yerine yerli ve bağımlılıksız: açılıştan 15 sn sonra ve 6 saatte bir (ayar açıksa)
`api.github.com/repos/metin-aydin/Hopclick/releases/latest` okunur; yeni sürüm menüde "Güncelleme Var" olarak görünür,
simgede nokta çıkar. Kullanıcı onaylayınca zip indirilir, `ditto` ile açılır, indirilen uygulama sıkı doğrulanır
(`SecStaticCodeCheckValidity`: tüm mimariler, iç içe kod, strict, iptal denetimi; gereksinim: aynı bundle id, aynı
Team ID, `notarized`), yerine kopyalandıktan sonra `codesign --verify --deep --strict -R` ile yeniden doğrulanır,
başarısızsa eski uygulama geri konur, uygulama kapanınca küçük bir kabuk betiği eski
paketi değiştirip yenisini açar. İmzasız/ad-hoc derlemede kurulum yapılmaz, sürüm sayfası açılır.
