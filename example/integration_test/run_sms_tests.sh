#!/usr/bin/env bash
# Runs the SMS and phone number hint integration tests on an Android emulator.
# The tests print markers on stdout; this script reacts by sending SMS
# messages to the emulator with `adb emu sms send`.
#
# Usage: integration_test/run_sms_tests.sh [emulator-id]   (default emulator-5554)
set -euo pipefail

cd "$(dirname "$0")/.."
device="${1:-emulator-5554}"

# The default reporter buffers prints until a test finishes, but these markers
# must reach adb while the test is still waiting for the SMS or dialog.
flutter test integration_test/smart_auth_test.dart -d "$device" --reporter expanded \
  --dart-define=SMS_TESTS=true --dart-define=HINT_TESTS=true 2>&1 | while IFS= read -r line; do
  echo "$line"
  case "$line" in
    *SMS_SIGNATURE=*)
      signature="${line##*SMS_SIGNATURE=}"
      # Give the retriever time to start listening.
      sleep 4
      # The console treats a newline as a new command, so keep it on one line.
      adb -s "$device" emu sms send 5551234 "<#> Your code is 123456 $signature"
      ;;
    *HINT_READY*)
      # Dismiss the phone number hint dialog. Only press Back while the dialog
      # has focus: it can die on its own on CI emulators, and a stray Back would
      # then send the app to the background and stall the rest of the run.
      sleep 4
      for _ in 1 2 3 4 5; do
        if adb -s "$device" shell dumpsys window 2>/dev/null \
          | grep -E 'mCurrentFocus|mFocusedWindow' | grep -q PhoneNumberHintActivity; then
          adb -s "$device" shell input keyevent KEYCODE_BACK
          break
        fi
        sleep 2
      done
      ;;
    *SMS_CONSENT_READY*)
      sleep 2
      adb -s "$device" emu sms send 5551234 "Your code is 654321"
      # Accept the consent dialog.
      sleep 3
      adb -s "$device" shell uiautomator dump --windows /sdcard/ui.xml >/dev/null
      coords=$(adb -s "$device" shell cat /sdcard/ui.xml \
        | grep -o 'text="Allow"[^>]*bounds="\[[0-9,]*\]\[[0-9,]*\]"' \
        | grep -o '\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]' | head -n 1 \
        | sed 's/\]\[/,/; s/[][]//g' | tr ',' ' ' \
        | awk '{print int(($1+$3)/2), int(($2+$4)/2)}' || true)
      if [ -n "$coords" ]; then
        adb -s "$device" shell input tap $coords
      fi
      ;;
  esac
done
