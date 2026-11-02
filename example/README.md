# smart_auth_example

Demonstrates how to use the smart_auth plugin.

## Android SMS and phone number hint tests

With a Google Play services emulator running, use
`bash integration_test/run_sms_tests.sh emulator-5554` from this directory.
The harness uses the expanded reporter so printed readiness markers reach adb
before each test finishes; GitHub's default reporter buffers those markers.

CI bounds the entire harness (including Flutter build/install and adb commands)
with GNU `timeout --verbose --signal=KILL 15m`. A timeout fails the step and
collects the test log, screenshot, and logcat before the 40-minute job limit.
The 60-second Dart future timeouts are not a host-process watchdog.

Run the host-side regression tests without an emulator using
`python3 integration_test/run_sms_tests_test.py`. They require GNU `timeout`
(`gtimeout` from Homebrew coreutils on macOS).

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://flutter.dev/docs/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://flutter.dev/docs/cookbook)

For help getting started with Flutter, view our
[online documentation](https://flutter.dev/docs), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
