#!/bin/sh
# Packs Nadi.app into dist/Nadi-<version>.zip, plus a SHA-256 file.
# Run scripts/bundle.sh first. The version comes from the app's Info.plist.
# A ZIP, not a DMG: macOS 27 refuses to copy an app that Apple has not notarized from a disk image into
# Applications, while an app unpacked from a ZIP installs and only asks for Open Anyway on first launch.
set -eu

cd "$(dirname "$0")/.."

app=Nadi.app
[ -d "$app" ] || { echo "No $app. Run scripts/bundle.sh first." >&2; exit 1; }
version="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$app/Contents/Info.plist")"

name="Nadi-$version"
mkdir -p dist
zip="dist/$name.zip"
rm -f "$zip" "$zip.sha256"

# ditto keeps the code signature and extended attributes intact, which plain `zip` does not.
ditto -c -k --keepParent "$app" "$zip"

# Written from inside dist/ so `shasum -c` works next to the downloaded file.
(cd dist && shasum -a 256 "$name.zip" > "$name.zip.sha256")
echo "Wrote $(pwd)/$zip"
cat "$zip.sha256"
