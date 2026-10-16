#!/usr/bin/env bash
# PocketFlow host key injector — real Mac Cmd+C/V/Space through RustDesk.
#
# Android apps cannot inject global keys. This watches logcat for inject requests
# and runs them as the adb shell user so Cmd+C copies on the Mac (IME-only "paste"
# only uses the phone clipboard).
#
# Usage (Mac, USB or wireless adb connected):
#   ./tools/pocketflow-keyinject.sh
# Leave running while you use RustDesk. Ctrl+C to stop.

set -euo pipefail

ADB="${ADB:-adb}"
if ! command -v "$ADB" >/dev/null 2>&1; then
  if [[ -x "$HOME/Library/Android/sdk/platform-tools/adb" ]]; then
    ADB="$HOME/Library/Android/sdk/platform-tools/adb"
  else
    echo "adb not found" >&2
    exit 1
  fi
fi

DEV="$("$ADB" devices | awk '/device$/{print $1; exit}')"
if [[ -z "${DEV:-}" ]]; then
  echo "No adb device connected" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "PocketFlow key inject on $DEV"
echo "Watching logcat tag PocketFlowInject — keep this running."

exec "$ADB" -s "$DEV" logcat -v brief -s PocketFlowInject:I \
  | python3 -u "$ROOT/tools/pocketflow_keyinject.py" "$ADB" "$DEV"
