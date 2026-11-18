#!/bin/sh
# build/Hopclick.app'ten sürükle-bırak kurulumlu disk görüntüsü üretir: build/Hopclick-<sürüm>.dmg
# Kullanım: scripts/make-dmg.sh <sürüm>
set -eu
cd "$(dirname "$0")/.."
version="${1:-$(cat VERSION)}"
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
/usr/bin/ditto build/Hopclick.app "$stage/Hopclick.app"
ln -s /Applications "$stage/Applications"
rm -f "build/Hopclick-$version.dmg"
hdiutil create -volname "Hopclick $version" -srcfolder "$stage" -fs HFS+ -format UDZO -ov \
  "build/Hopclick-$version.dmg" >/dev/null
echo "build/Hopclick-$version.dmg"
