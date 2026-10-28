#!/bin/sh
# Builds a release binary and wraps it into Nadi.app, ad-hoc signed.
set -eu

cd "$(dirname "$0")/.."

swift build -c release --arch arm64
bin="$(swift build -c release --arch arm64 --show-bin-path)/Nadi"

app=Nadi.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/Nadi"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"

# Hardened runtime blocks DYLD_INSERT_LIBRARIES and unsigned library loads into the app.
codesign --force --options runtime -s - "$app"
echo "Built $(pwd)/$app"
