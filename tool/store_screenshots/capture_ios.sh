#!/usr/bin/env bash
# Captures the app screens that need a running build (the map screens) from
# an iPhone Pro Max simulator, at 1320x2868, into tool/store_screenshots/raw/.
#
# macOS with Xcode. Run from the repository root:
#
#   tool/store_screenshots/capture_ios.sh            # slots 02-04
#   tool/store_screenshots/capture_ios.sh 01 05 06   # chosen slots
#
# Before you start: .env filled in (see .env.example), the Maps key in
# ios/Flutter/Secrets.xcconfig, and a dedicated test account (never a real
# user's) that you sign in with in the simulator. Set SIM_UDID to choose the
# simulator yourself.
set -euo pipefail

cd "$(dirname "$0")/../.."
raw=tool/store_screenshots/raw
mkdir -p "$raw"

udid=${SIM_UDID:-$(xcrun simctl list devices available | grep -m1 'Pro Max' | grep -oE '[0-9A-F-]{36}' || true)}
if [[ -z "$udid" ]]; then
  echo "No iPhone Pro Max simulator. Add one in Xcode (Window > Devices and Simulators)." >&2
  exit 1
fi

xcrun simctl boot "$udid" 2>/dev/null || true
open -a Simulator --args -CurrentDeviceUDID "$udid"
xcrun simctl bootstatus "$udid" -b >/dev/null
xcrun simctl status_bar "$udid" override \
  --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
# Sheung Wan, Hong Kong: the walks are written for Hong Kong.
xcrun simctl location "$udid" set 22.2860,114.1500

describe() {
  case "$1" in
    01) echo "Walk tab: pick 街头文化, 美食, 历史遗迹 and 90 分钟" ;;
    02) echo "Preview of a generated walk: map with its stops" ;;
    03) echo "Walk screen with a task card showing" ;;
    04) echo "Photo verdict dialog after an accepted task photo" ;;
    05) echo "Summary of a finished walk (story and photos visible)" ;;
    06) echo "History tab with a few finished walks" ;;
    *) echo "unknown slot $1" >&2; exit 1 ;;
  esac
}
slug() {
  case "$1" in
    01) echo setup ;; 02) echo preview ;; 03) echo walk-task ;;
    04) echo photo-check ;; 05) echo summary ;; 06) echo history ;;
  esac
}

slots=("$@")
[[ ${#slots[@]} -eq 0 ]] && slots=(02 03 04)

log=$(mktemp)
echo "Starting the app on the simulator (log: $log)..."
flutter run -d "$udid" --dart-define-from-file=.env >"$log" 2>&1 &
app=$!
trap 'kill $app 2>/dev/null || true; xcrun simctl status_bar "$udid" clear || true' EXIT

for slot in "${slots[@]}"; do
  echo
  echo "Slot $slot: $(describe "$slot")"
  read -r -p "Open that screen in the simulator, then press Enter (s to skip): " answer
  [[ "$answer" == "s" ]] && continue
  out="$raw/$slot-$(slug "$slot").png"
  xcrun simctl io "$udid" screenshot --type=png "$out" >/dev/null
  echo "Saved $out"
done

echo
echo "Done. Render the framed images with: flutter test tool/store_screenshots"
