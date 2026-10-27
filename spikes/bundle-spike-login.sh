#!/bin/sh
# Wraps the SpikeLogin target into an ad-hoc signed SpikeLogin.app with its own bundle id.
set -eu

cd "$(dirname "$0")/.."

swift build -c release --arch arm64 --product SpikeLogin
bin="$(swift build -c release --arch arm64 --show-bin-path)/SpikeLogin"

app=spikes/SpikeLogin.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$bin" "$app/Contents/MacOS/SpikeLogin"
sed -e 's/<string>Nadi<\/string>/<string>SpikeLogin<\/string>/' \
    -e 's/io\.github\.theyudhiztira\.nadi/io.github.theyudhiztira.nadi.spike/' \
    Resources/Info.plist > "$app/Contents/Info.plist"

codesign --force -s - "$app"
echo "Built $(pwd)/$app"
