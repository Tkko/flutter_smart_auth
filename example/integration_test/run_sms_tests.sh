#!/usr/bin/env bash
# Runs the SMS and phone number hint integration tests on an Android emulator.
# The tests print markers on stdout; this script reacts by sending SMS
# messages to the emulator with `adb emu sms send`.
#
# Usage: integration_test/run_sms_tests.sh [emulator-id]   (default emulator-5554)
#
# On shared CI emulators the app sometimes never gets past the splash screen
# after it is installed, so no test ever reports and the run hangs until the
# job is killed. A watchdog notices that no test has started a while after the
# install, stops the run and starts it again. A real test failure is not retried.
set -euo pipefail

cd "$(dirname "$0")/.."
device="${1:-emulator-5554}"

package="dev.tornike.smart_auth_example"
# How long the first test may take to report once the app is installed. A
# healthy emulator needs a few seconds.
startup_timeout="${STARTUP_TIMEOUT:-120}"
attempts="${ATTEMPTS:-3}"
sender="5551234"
other_sender="5559876"

# The console treats a newline as a new command, so keep messages on one line.
send_sms() {
  adb -s "$device" emu sms send "$1" "$2" </dev/null
}

# adb reads stdin, which here is the test output: without this it would swallow
# the lines the loop below is waiting for.
device_shell() {
  adb -s "$device" shell "$@" </dev/null
}

# Taps a button of the consent dialog by its label.
tap_dialog_button() {
  device_shell uiautomator dump --windows /sdcard/ui.xml >/dev/null
  local coords
  coords=$(device_shell cat /sdcard/ui.xml \
    | grep -o "text=\"$1\"[^>]*bounds=\"\[[0-9,]*\]\[[0-9,]*\]\"" \
    | grep -o '\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]' | head -n 1 \
    | sed 's/\]\[/,/; s/[][]//g' | tr ',' ' ' \
    | awk '{print int(($1+$3)/2), int(($2+$4)/2)}' || true)
  if [ -n "$coords" ]; then
    device_shell input tap $coords
  else
    echo "Dialog button not found: $1"
  fi
}

# Dismisses the phone number hint dialog. Only presses Back while the dialog
# has focus: it can die on its own on CI emulators, and a stray Back would
# then send the app to the background and stall the rest of the run.
dismiss_hint() {
  for _ in 1 2 3 4 5; do
    if device_shell dumpsys window 2>/dev/null \
      | grep -E 'mCurrentFocus|mFocusedWindow' | grep -q PhoneNumberHintActivity; then
      device_shell input keyevent KEYCODE_BACK
      break
    fi
    sleep 2
  done
}

run_attempt() {
  local flag="$1"
  local started="$flag.started"
  # The default reporter buffers prints until a test finishes, but these markers
  # must reach adb while the test is still waiting for the SMS or dialog.
  flutter test integration_test/smart_auth_test.dart -d "$device" --reporter expanded \
    --dart-define=SMS_TESTS=true --dart-define=HINT_TESTS=true 2>&1 | while IFS= read -r line; do
    echo "$line"
    # The first test that reports (not the initial "loading" line) means the
    # app is up, so the watchdog is not needed any more.
    if [[ "$line" =~ \+[0-9]+:\ (.*) && "${BASH_REMATCH[1]}" != loading* && ! -e "$started" ]]; then
      touch "$started"
      if [ -n "${watchdog_pid:-}" ]; then
        kill "$watchdog_pid" 2>/dev/null || true
      fi
    fi
    case "$line" in
      *"Installing build/app/outputs/flutter-apk/"*)
        # Silenced like the other background jobs: they must not hold the
        # pipe open after the run ends.
        (
          sleep "$startup_timeout"
          if [ ! -e "$started" ]; then
            touch "$flag"
            pkill -f "integration_test/smart_auth_test.dart" || true
          fi
        ) >/dev/null 2>&1 &
        watchdog_pid=$!
        ;;
      *SMS_SIGNATURE=*)
        signature="${line##*SMS_SIGNATURE=}"
        # Give the retriever time to start listening.
        sleep 4
        send_sms "$sender" "<#> Your code is 123456 $signature"
        ;;
      *SMS_UNSIGNED_CHECK=*)
        signature="${line##*SMS_UNSIGNED_CHECK=}"
        sleep 4
        send_sms "$sender" "<#> Your code is 111111"
        sleep 3
        send_sms "$sender" "<#> Your code is 222222 $signature"
        ;;
      *HINT_READY*)
        sleep 4
        dismiss_hint
        ;;
      *HINT_SMS_READY=*)
        signature="${line##*HINT_SMS_READY=}"
        sleep 4
        send_sms "$sender" "<#> Your code is 888888 $signature"
        sleep 2
        dismiss_hint
        ;;
      *SMS_CONSENT_READY*)
        sleep 2
        send_sms "$sender" "Your code is 654321"
        sleep 3
        tap_dialog_button Allow
        ;;
      *SMS_CONSENT_DENY_READY*)
        sleep 2
        send_sms "$sender" "Your code is 333333"
        sleep 3
        tap_dialog_button Deny
        ;;
      *SMS_CONSENT_OTHER_SENDER_READY*)
        sleep 2
        send_sms "$other_sender" "Your code is 111111"
        sleep 3
        send_sms "$sender" "Your code is 444444"
        sleep 3
        tap_dialog_button Allow
        ;;
      *SMS_CONSENT_ANY_SENDER_READY*)
        sleep 2
        send_sms "$other_sender" "Your code is 555555"
        sleep 3
        tap_dialog_button Allow
        ;;
      *SMS_CONSENT_ROTATE_READY*)
        sleep 2
        send_sms "$sender" "Your code is 666666"
        sleep 3
        device_shell settings put system accelerometer_rotation 0
        device_shell settings put system user_rotation 1
        sleep 3
        # Finish rotating before tapping: each rotation recreates the dialog,
        # which can lose a tap that lands around the same time.
        device_shell settings put system user_rotation 0
        sleep 3
        tap_dialog_button Allow
        ;;
      *SMS_CONSENT_BACKGROUND_READY*)
        sleep 2
        send_sms "$sender" "Your code is 777777"
        sleep 3
        device_shell input keyevent KEYCODE_HOME
        sleep 2
        device_shell monkey -p "$package" -c android.intent.category.LAUNCHER 1 >/dev/null
        sleep 3
        tap_dialog_button Allow
        ;;
    esac
  done
}

for attempt in $(seq 1 "$attempts"); do
  hung="$(mktemp "${TMPDIR:-/tmp}/sms-hung.XXXXXX")"
  rm -f "$hung"
  status=0
  # The shell would print a job report for the run the watchdog kills, so its
  # own stderr is dropped here; the test output goes to stdout.
  run_attempt "$hung" 2>/dev/null || status=$?
  rm -f "$hung.started"
  if [ ! -e "$hung" ]; then
    exit "$status"
  fi
  rm -f "$hung"
  echo "Attempt $attempt of $attempts: the app did not start, trying again."
  device_shell am force-stop "$package" >/dev/null 2>&1 || true
done
echo "The app did not start after $attempts attempts."
exit 1
