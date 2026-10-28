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

# The commit count as build number, so the version in the panel footer pins a bug report to a commit.
if build="$(git rev-list --count HEAD 2>/dev/null)"; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build" "$app/Contents/Info.plist"
fi

# Hardened runtime blocks DYLD_INSERT_LIBRARIES and unsigned library loads into the app.
codesign --force --options runtime -s - "$app"
echo "Built $(pwd)/$app"
