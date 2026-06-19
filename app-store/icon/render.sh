#!/usr/bin/env bash
# Render AppIcon.svg -> the app's 1024 asset (opaque, no alpha — Apple rejects alpha).
# Uses headless Chrome because ImageMagick's builtin SVG renderer drops gradients.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
svg="$here/AppIcon.svg"
out="$here/../../ios/Skymarshal/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
tmp="$(mktemp -d)"

printf '<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;padding:0}svg{display:block}</style></head><body>%s</body></html>' "$(cat "$svg")" > "$tmp/icon.html"
"$chrome" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
  --screenshot="$tmp/icon.png" --window-size=1024,1024 "file://$tmp/icon.html"
magick "$tmp/icon.png" -alpha remove -alpha off -colorspace sRGB -strip "$out"
echo "wrote $out"
sips -g pixelWidth -g pixelHeight -g hasAlpha "$out" | tail -3
rm -rf "$tmp"
