#!/bin/sh
# Hopclick.app paketini derler: build/Hopclick.app
# Kullanım: scripts/build-app.sh [sürüm]   (sürüm verilmezse VERSION dosyası)
# Ortam: UNIVERSAL=1 → arm64 + x86_64 evrensel ikili; SIGN_IDENTITY → imza kimliği (yoksa ad-hoc "-").
set -eu
cd "$(dirname "$0")/.."
version="${1:-$(cat VERSION)}"
build_number="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
identity="${SIGN_IDENTITY:--}"

if [ "${UNIVERSAL:-0}" = "1" ]; then
  swift build -c release --arch arm64 --arch x86_64
  bin_dir=".build/apple/Products/Release"
else
  swift build -c release
  bin_dir=".build/release"
fi

app="build/Hopclick.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/Hopclick" "$app/Contents/MacOS/Hopclick"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
sed -e "s/__VERSION__/$version/" -e "s/__BUILD__/$build_number/" Resources/Info.plist > "$app/Contents/Info.plist"
plutil -lint "$app/Contents/Info.plist" >/dev/null

if [ "$identity" = "-" ]; then
  codesign --force --sign - --identifier app.hopclick.Hopclick "$app"
else
  codesign --force --options runtime --timestamp --sign "$identity" --identifier app.hopclick.Hopclick "$app"
fi
codesign --verify --strict "$app"
echo "$app ($version, $build_number, imza: $identity)"
