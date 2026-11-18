#!/bin/sh
# assets/logo.svg dosyasından uygulama simgesini (Resources/AppIcon.icns) ve README logosunu üretir.
# SVG gölge filtreleri için Google Chrome'un başsız modu kullanılır; çıktılar depoya eklenir, CI bunu çalıştırmaz.
set -eu
cd "$(dirname "$0")/.."
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
"$CHROME" --headless=new --disable-gpu --hide-scrollbars --default-background-color=00000000 \
  --window-size=1024,1024 --screenshot="$work/1024.png" "file://$PWD/assets/logo.svg" >/dev/null 2>&1
set_dir="$work/AppIcon.iconset"
mkdir -p "$set_dir"
for size in 16 32 128 256 512; do
  sips -z $size $size "$work/1024.png" --out "$set_dir/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z $double $double "$work/1024.png" --out "$set_dir/icon_${size}x${size}@2x.png" >/dev/null
done
mkdir -p Resources docs/images
iconutil -c icns "$set_dir" -o Resources/AppIcon.icns
sips -z 256 256 "$work/1024.png" --out docs/images/logo.png >/dev/null
echo "Resources/AppIcon.icns ve docs/images/logo.png güncellendi"
