#!/bin/bash
# Capture App Store screenshots for one simulator device.
#
#   ios/scripts/capture_screenshots.sh "iPhone 17 Pro Max" iphone-6.9
#   ios/scripts/capture_screenshots.sh "iPad Pro 13-inch (M5)" ipad-13
#   ios/scripts/capture_screenshots.sh <UDID> iphone-6.9
#
# Boots the simulator, pins the status bar to the canonical 9:41 /
# full-battery look, runs SkymarshalUITests/ScreenshotTest, and exports
# the captures to ios/screenshots-appstore/<label>/.
#
# The hero frame types a live search, which needs the simulator's SOFTWARE
# keyboard. If "Connect Hardware Keyboard" is on, search typing is skipped
# (the test stays green; frame 01 just shows the un-searched list). Disable
# it once with:
#   defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false
#
# The story needs a signed-in Bluesky session. Either:
#   - point at a simulator (by UDID) whose keychain already holds a
#     Skymarshal session, or
#   - export SKY_TEST_HANDLE and SKY_TEST_APP_PASSWORD (or drop them in
#     app-store/DEMO_ACCOUNT.env, gitignored) and the test types them into
#     the native login fields. Credentials are never hardcoded or committed;
#     they ride in via TEST_RUNNER_* environment variables only.
set -euo pipefail

DEVICE="${1:?simulator device name or UDID}"
LABEL="${2:?output folder label}"

IOS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_DIR="$(cd "$IOS_DIR/.." && pwd)"
OUT_DIR="$IOS_DIR/screenshots-appstore/$LABEL"
RESULT_BUNDLE="$(mktemp -d)/capture.xcresult"

cd "$IOS_DIR"

# Optional demo credentials. DEMO_ACCOUNT.env is gitignored; env vars win.
if [ -z "${SKY_TEST_HANDLE:-}" ] && [ -f "$REPO_DIR/app-store/DEMO_ACCOUNT.env" ]; then
  # shellcheck disable=SC1091
  source "$REPO_DIR/app-store/DEMO_ACCOUNT.env"
fi

# A bare name can resolve to a different device per runtime — and the
# newest runtime may be a beta that hangs on boot. Resolve the name through
# xcodebuild's own destination list (only devices it will actually accept)
# and pin the lowest-OS match, i.e. the most stable released runtime.
if [[ ! "$DEVICE" =~ ^[0-9A-Fa-f-]{36}$ ]]; then
  RESOLVED=$( (xcodebuild -project Skymarshal.xcodeproj -scheme Skymarshal \
      -showdestinations 2>/dev/null || true) \
    | { grep -F "name:$DEVICE }" || true; } | { grep "platform:iOS Simulator" || true; } \
    | sed -E 's/.*OS:([0-9.]+).*id:([0-9A-Fa-f-]{36}).*/\1 \2/;s/.*id:([0-9A-Fa-f-]{36}).*OS:([0-9.]+).*/\2 \1/' \
    | sort -V | head -1 | awk '{print $2}')
  if [ -z "$RESOLVED" ]; then
    echo "no simulator destination named '$DEVICE'" >&2
    exit 1
  fi
  echo "resolved '$DEVICE' -> $RESOLVED"
  DEVICE="$RESOLVED"
fi

xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" >/dev/null

xcrun simctl status_bar "$DEVICE" override \
  --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiBars 3 --operatorName ""

# Export attachments even when the test fails — the named snaps are
# the only useful failure diagnostics this side of an attached Xcode.
# xcodebuild only forwards TEST_RUNNER_-prefixed variables from its
# environment — command-line build settings never reach the runner.
export TEST_RUNNER_SKY_TEST_HANDLE="${SKY_TEST_HANDLE:-}"
export TEST_RUNNER_SKY_TEST_APP_PASSWORD="${SKY_TEST_APP_PASSWORD:-}"
TEST_STATUS=0
xcodebuild -project Skymarshal.xcodeproj -scheme Skymarshal \
  -destination "platform=iOS Simulator,id=$DEVICE" \
  -only-testing:SkymarshalUITests/ScreenshotTest \
  -resultBundlePath "$RESULT_BUNDLE" \
  -derivedDataPath build \
  test || TEST_STATUS=$?

xcrun simctl status_bar "$DEVICE" clear

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
EXPORT_DIR="$(mktemp -d)"
# Both the .xcresult and the export staging are large and disposable once
# the named PNGs are copied out — drop them on exit so reruns don't fill
# the disk.
trap 'rm -rf "$(dirname "$RESULT_BUNDLE")" "$EXPORT_DIR"' EXIT
xcrun xcresulttool export attachments --path "$RESULT_BUNDLE" --output-path "$EXPORT_DIR" >/dev/null

# manifest.json maps exported file names back to the XCTAttachment
# names ("01-search", ...). Copy them out under those names.
python3 - "$EXPORT_DIR" "$OUT_DIR" <<'PY'
import json, re, shutil, sys
from pathlib import Path

export_dir, out_dir = Path(sys.argv[1]), Path(sys.argv[2])
manifest = json.loads((export_dir / "manifest.json").read_text())
count = 0
for test in manifest:
    for att in test.get("attachments", []):
        name = att.get("suggestedHumanReadableName") or att["exportedFileName"]
        # exported names look like "01-search_0_<UUID>.png" — keep the
        # attachment name we set in ScreenshotTest. XCTest also auto-attaches
        # debug descriptions, UI snapshots, and a screen recording; only our
        # NN-name shots (and 9N debug snaps) are wanted.
        stem = Path(name).stem.split("_0_")[0]
        if not re.match(r"^\d\d-", stem):
            continue
        src = export_dir / att["exportedFileName"]
        dst = out_dir / (stem + Path(att["exportedFileName"]).suffix)
        shutil.copy(src, dst)
        count += 1
        print(f"  {dst.name}")
print(f"{count} screenshots -> {out_dir}")
PY

exit "$TEST_STATUS"
