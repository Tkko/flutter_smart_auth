#!/usr/bin/env bash
# Runs the SMS integration tests on an Android emulator.
# The tests print markers on stdout; this script reacts by sending SMS
# messages to the emulator with `adb emu sms send`.
#
# Usage: integration_test/run_sms_tests.sh [emulator-id]   (default emulator-5554)
set -euo pipefail

cd "$(dirname "$0")/.."
device="${1:-emulator-5554}"

flutter test integration_test/smart_auth_test.dart -d "$device" \
  --dart-define=SMS_TESTS=true 2>&1 | while IFS= read -r line; do
  echo "$line"
  case "$line" in
    *SMS_SIGNATURE=*)
      signature="${line##*SMS_SIGNATURE=}"
      sleep 2
      adb -s "$device" emu sms send 5551234 "<#> Your code is 123456
$signature"
      ;;
    *SMS_CONSENT_READY*)
      sleep 2
      adb -s "$device" emu sms send 5551234 "Your code is 654321"
      # Accept the consent dialog.
      sleep 3
      adb -s "$device" shell uiautomator dump /sdcard/ui.xml >/dev/null
      adb -s "$device" shell cat /sdcard/ui.xml \
        | grep -o 'text="Allow"[^>]*bounds="\[[0-9,]*\]\[[0-9,]*\]"' \
        | grep -o '\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]' | head -1 \
        | tr -d '[]' | tr ',' ' ' \
        | awk '{print int(($1+$3)/2), int(($2+$4)/2)}' \
        | xargs -r adb -s "$device" shell input tap
      ;;
  esac
done
