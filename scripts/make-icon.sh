#!/bin/sh
# Renders Resources/AppIcon.svg into Resources/AppIcon.icns. Needs rsvg-convert (brew install librsvg).
# Run it after editing the SVG and commit both files, so scripts/bundle.sh needs no extra tools.
set -eu

cd "$(dirname "$0")/.."

set_dir="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$set_dir"
for size in 16 32 128 256 512; do
    rsvg-convert -w "$size" -h "$size" Resources/AppIcon.svg -o "$set_dir/icon_${size}x${size}.png"
    rsvg-convert -w $((size * 2)) -h $((size * 2)) Resources/AppIcon.svg -o "$set_dir/icon_${size}x${size}@2x.png"
done
iconutil -c icns "$set_dir" -o Resources/AppIcon.icns
rm -rf "$(dirname "$set_dir")"
echo "Wrote $(pwd)/Resources/AppIcon.icns"
