#!/usr/bin/env bash
# Build once, then install + screenshot the app on several simulator sizes.
# Output: screenshots/<device>.png plus screenshots/contact-sheet.png
#
#   scripts/screenshots.sh                         # default device set
#   scripts/screenshots.sh "iPhone 16e" "iPhone Air"
#   REF_APP=path/to/Other.app scripts/screenshots.sh   # also shoot a reference
#       build (e.g. the RN app) on each device, placed left of ours
set -euo pipefail
cd "$(dirname "$0")/.."

DEVICES=("$@")
if [ ${#DEVICES[@]} -eq 0 ]; then
  DEVICES=("iPhone 16e" "iPhone 17" "iPhone 17 Pro" "iPhone Air" "iPhone 17 Pro Max")
fi
BUNDLE_ID=fi.steelfinger.rhythmace
OUT=screenshots
mkdir -p "$OUT"

xcodegen generate >/dev/null
xcodebuild -project RhythmAce.xcodeproj -scheme RhythmAce \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath build \
  -quiet build
APP=build/Build/Products/Debug-iphonesimulator/RhythmAce.app

udid_for() {
  xcrun simctl list devices available -j | python3 -c '
import json, sys
name = sys.argv[1]
for runtime, devs in sorted(json.load(sys.stdin)["devices"].items(), reverse=True):
    for d in devs:
        if d["name"] == name:
            print(d["udid"]); sys.exit()
' "$1"
}

SHOTS=()
# shoot <udid> <app> <file> <settle seconds>
shoot() {
  xcrun simctl terminate "$1" "$BUNDLE_ID" 2>/dev/null || true
  # Installs occasionally fail right after boot; retry once.
  xcrun simctl install "$1" "$2" 2>/dev/null || { sleep 3; xcrun simctl install "$1" "$2"; }
  xcrun simctl launch "$1" "$BUNDLE_ID" >/dev/null
  sleep "$4"
  xcrun simctl io "$1" screenshot "$3" >/dev/null 2>&1
  echo "$name → $3"
  SHOTS+=("$3")
}

for name in "${DEVICES[@]}"; do
  udid=$(udid_for "$name")
  if [ -z "$udid" ]; then echo "skip: no simulator named '$name'"; continue; fi
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  # Fixed status bar so screenshots are comparable
  xcrun simctl status_bar "$udid" override --time 9:41 --batteryLevel 100 \
    --batteryState charged --wifiBars 3 --cellularBars 4 2>/dev/null || true
  if [ -n "${REF_APP:-}" ]; then
    shoot "$udid" "$REF_APP" "$OUT/${name// /-}-ref.png" 6
  fi
  shoot "$udid" "$APP" "$OUT/${name// /-}.png" 3
done

# Side-by-side contact sheet, all scaled to the same height
if [ ${#SHOTS[@]} -gt 0 ]; then
  swift scripts/contact-sheet.swift "$OUT/contact-sheet.png" "${SHOTS[@]}"
  echo "contact sheet → $OUT/contact-sheet.png"
fi
