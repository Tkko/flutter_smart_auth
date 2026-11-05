<div align="center">

# Smart Auth

**Android SMS autofill, phone number hints and passkeys for Flutter.**

[![Pub](https://img.shields.io/pub/v/smart_auth.svg)](https://pub.dev/packages/smart_auth)
[![CI](https://github.com/Tkko/flutter_smart_auth/actions/workflows/ci.yml/badge.svg)](https://github.com/Tkko/flutter_smart_auth/actions/workflows/ci.yml)
[![Stars](https://img.shields.io/github/stars/Tkko/flutter_smart_auth.svg?style=flat&logo=github&colorB=deeppink&label=stars)](https://github.com/Tkko/flutter_smart_auth)
[![Style](https://img.shields.io/badge/style-effective_dart-40c4ff.svg)](https://github.com/tenhobi/effective_dart)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](LICENSE)

[Install](#install) · [Usage](#usage) · [Requirements](#requirements) · [Example](example/lib/main.dart) · [pub.dev](https://pub.dev/packages/smart_auth) · [Changelog](CHANGELOG.md)

<b>🚀 Have a project in mind? <a href="https://www.linkedin.com/in/thornike/">Let's work together on LinkedIn</a>.</b>

<b>Enjoying this package? Help keep it maintained.</b>

<a href="https://ko-fi.com/tornike_dev"><img width="100" height="56" src="https://user-images.githubusercontent.com/26390946/161375565-e7d64410-bbcf-4a28-896b-7514e106478e.png" alt="Support on Ko-fi"></a>
<a href="https://www.buymeacoffee.com/tornike.dev"><img width="100" height="56" src="https://user-images.githubusercontent.com/26390946/161375563-69c634fd-89d2-45ac-addd-931b03996b34.png" alt="Buy Me a Coffee"></a>

</div>

<br>

| SMS autofill | Phone number hint | User consent dialog |
| :---: | :---: | :---: |
| <img src="https://user-images.githubusercontent.com/26390946/155599527-fe934f2c-5124-4754-bbf6-bb97d55a77c0.gif" width="180" height="400" alt="SMS autofill demo" /> | <img src="https://github.com/user-attachments/assets/efff8893-4ac4-4601-98b5-1fb10ae365a3" width="180" height="400" alt="Phone number hint" /> | <img src="https://github.com/user-attachments/assets/60ace6bc-6c28-43cf-ae1d-60f56aaae8d2" width="180" height="400" alt="User consent dialog" /> |

> Looking for a PIN / OTP input field? See [Pinput](https://github.com/Tkko/Flutter_Pinput).

## Features

- **SMS autofill** with the [SMS Retriever API](https://developers.google.com/identity/sms-retriever/overview) and the [SMS User Consent API](https://developers.google.com/identity/sms-retriever/user-consent/overview)
- **Phone number hint** through the [Phone Number Hint API](https://developers.google.com/identity/phone-number-hint/android)
- **Credential Manager** ([docs](https://developer.android.com/identity/sign-in/credential-manager)):
  - get saved passwords and passkeys: `getCredential`
  - save a password: `createPasswordCredential`
  - create a passkey: `createPublicKeyCredential`
  - speed up the account selector on Android 14+: `prepareGetCredential`, `getPreparedCredential`
  - clear state on sign out: `clearCredentialState`

**Platform:** Android only.

## Install

```bash
flutter pub add smart_auth
```

```dart
import 'package:smart_auth/smart_auth.dart';

final smartAuth = SmartAuth.instance;
```

## Usage

Every method returns a `SmartAuthResult`: check `hasData`, `isCanceled` or read the error.

### Phone number hint

Shows the user's SIM-based phone numbers as a hint. No extra permission, no Google account, and not tied to a sign-in flow. [Docs](https://developers.google.com/identity/phone-number-hint/android)

```dart
final res = await smartAuth.requestPhoneNumberHint();
if (res.hasData) {
  // Use the phone number
} else {
  // Handle the error
}
```

### SMS with User Consent

The user confirms access to a single SMS in a system dialog. No app signature needed. [API overview](https://developers.google.com/identity/sms-retriever/user-consent/overview)

```dart
final res = await smartAuth.getSmsWithUserConsentApi();
if (res.hasData) {
  // The code is null when the SMS arrived but no code could be extracted
  final code = res.requireData.code;
  if (code == null) return;
  // Use the code
} else if (res.isCanceled) {
  // The user dismissed the dialog
} else {
  // Handle the error
}
```

<details>
<summary>Verification flow</summary>

1. The user starts SMS verification, typing a phone number or picking one with `requestPhoneNumberHint`.
2. Your app asks your server to verify the number (user ID, phone number, or both).
3. At the same time, the app calls `getSmsWithUserConsentApi` to show the consent dialog.
4. Your server sends an SMS with a one-time code.
5. When the SMS arrives, the plugin extracts the code from it. Send it back to your server.
6. Your server verifies the code and records the account as verified.

</details>

### SMS Retriever

Fully automatic, with no user interaction and no extra permissions. The SMS must contain your app's hash. [API overview](https://developers.google.com/identity/sms-retriever/overview)

```dart
final res = await smartAuth.getSmsWithRetrieverApi();
if (res.hasData) {
  // The code is null when the SMS arrived but no code could be extracted
  final code = res.requireData.code;
  if (code == null) return;
  // Use the code
} else {
  // Handle the error
}
```

<details>
<summary>Verification flow</summary>

<img src="https://github.com/user-attachments/assets/7daa8895-14d4-460f-b9e7-4710446788d3" alt="SMS Retriever flow" />

1. The user starts SMS verification, typing a phone number or picking one with `requestPhoneNumberHint`.
2. Your app asks your server to verify the number (user ID, phone number, or both).
3. At the same time, the app calls `getSmsWithRetrieverApi` to start listening for the SMS.
4. Your server sends an SMS with a one-time code and a hash that identifies your app.
5. Google Play services uses the hash to route the message to your app.
6. The plugin extracts the code from the message. Send it back to your server.
7. Your server verifies the code and records the account as verified.

</details>

Get your app's hash with `getAppSignature` and have your backend end every SMS with it (the message must be short, contain the code and end with the 11-character hash). The hash differs between debug and release builds.

```dart
final res = await smartAuth.getAppSignature();
if (res.hasData) {
  print(res.data); // e.g. kg+TZ3A5qzS
}
```

```
Your ExampleApp code is: 123456
kg+TZ3A5qzS
```

### Remove listeners

The plugin removes listeners after it receives a code. To stop earlier, for example in `dispose`:

```dart
smartAuth.removeUserConsentApiListener();
// or
smartAuth.removeSmsRetrieverApiListener();
```

### Credential Manager

Get, save and clear passwords and passkeys. `isCanceled` is true when the user dismisses the dialog. [Docs](https://developer.android.com/identity/sign-in/credential-manager)

```dart
// Show saved passwords and passkeys
final result = await smartAuth.getCredential(
  passwordOption: SmartAuthPasswordOption(),
  publicKeyOptions: [SmartAuthPublicKeyOption(requestJson: requestJsonFromServer)],
);
final credential = result.data;
// credential.type is password or publicKey
// password:  credential.id, credential.password
// passkey:   credential.authenticationResponseJson

// Save a password
await smartAuth.createPasswordCredential(id: 'user@example.com', password: 'secret');

// Create a passkey, send registrationResponseJson to your server
final created = await smartAuth.createPublicKeyCredential(requestJson: requestJsonFromServer);

// Android 14+: fetch the data first to show the account selector faster
final prepared = await smartAuth.prepareGetCredential(passwordOption: SmartAuthPasswordOption());
if (prepared.hasData) {
  final credential = await smartAuth.getPreparedCredential();
}

// On sign out
await smartAuth.clearCredentialState();
```

- `prepareGetCredential` and `getPreparedCredential` need Android 14 or higher. Below that they fail with `UNSUPPORTED`.
- Only privileged apps can see which credentials `prepareGetCredential` found. The `has*` fields of `SmartAuthPreparedCredential` are `null` for other apps. It still makes the next `getPreparedCredential` faster.

<details>
<summary>Error codes</summary>

Failed results contain one of these codes in `error`:

| Code | Meaning |
| :--- | :--- |
| `NO_CREDENTIAL` | Nothing to show, the user has no matching saved credentials |
| `INVALID_REQUEST` | The request is incomplete, e.g. `getCredential` without any option |
| `NO_ACTIVITY` | There is no foreground activity to show the dialog on |
| `UNSUPPORTED` | The method needs a newer Android version |
| `NO_PREPARED_CREDENTIAL` | `getPreparedCredential` was called before `prepareGetCredential` |
| `GET_CREDENTIAL_FAILED`, `CREATE_CREDENTIAL_FAILED`, `PREPARE_GET_CREDENTIAL_FAILED`, `CLEAR_CREDENTIAL_STATE_FAILED` | The Credential Manager reported an error |

</details>

## Requirements

Flutter 3.44 or above. The plugin is tested with Flutter 3.47.

| Capability | Google Play services | Android version |
| :--- | :---: | :--- |
| SMS Retriever, SMS User Consent, Phone Number Hint | Required | 7.0+ (API 24) |
| Credential Manager | Required on Android 13 and below | 7.0+ (API 24) |
| `prepareGetCredential`, `getPreparedCredential` | – | 14+ (API 34) |

**Added by this package**

| Requirement | Minimum |
| :--- | :--- |
| `compileSdk` | 35 or above (it doesn't drop any devices) |
| JDK that runs Gradle | 17 or above (JDK 25 doesn't work with Gradle 8.14) |
| Java source and target | 11 or above |

```groovy
// android/app/build.gradle
android {
    compileSdk = 35

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
}
```

<details>
<summary>Android build tools</summary>

AGP, Gradle and Kotlin versions are dictated by your Flutter version. Flutter checks them when building and tells you what to upgrade, and a project created with `flutter create` already has them. For example Flutter 3.47 requires:

| Tool | Minimum |
| :--- | :--- |
| Android Gradle Plugin (AGP) | 8.11.1 (Flutter will move to 9.0.1) |
| Gradle | 8.14 (Flutter will move to 9.1.0) |
| Kotlin | 2.2.20 (Flutter will move to 2.3.20) |

The plugin also works with AGP 9, where Kotlin is built in, see the [migration guide](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers). With AGP 9 you don't need the `kotlin-gradle-plugin` classpath or the `org.jetbrains.kotlin.android` plugin, and `kotlinOptions` is deprecated.

</details>

## Migrating

**To 4.x:** the Dart API is unchanged. The new requirements are Flutter 3.44 / Dart 3.12, `compileSdk` 35 or above, and the AGP, Gradle and Kotlin versions your Flutter version requires (see [Requirements](#requirements)). The plugin's own `minSdkVersion` is 21.

**From 2.x to 3.x:**

| 2.x | 3.x |
| :--- | :--- |
| `SmartAuth()` | `SmartAuth.instance` |
| `getSmsCode()` returning `SmsCodeResult` | `getSmsWithRetrieverApi()` / `getSmsWithUserConsentApi()` returning `SmartAuthResult<SmartAuthSms>` |
| `res.succeed && res.codeFound`, `res.code` | `res.hasData`, `res.data?.code` |
| `getAppSignature()` returning `String?` | returns `SmartAuthResult<String>`, read the value with `res.data` |
| `removeSmsListener()` | `removeSmsRetrieverApiListener()` / `removeUserConsentApiListener()` |

## Contributing

PRs are welcome. Read the [contributing guide](CONTRIBUTING.md) first, and see the [example app](example/lib/main.dart) for full usage.

---

<div align="center">

Made by [Tornike](https://www.linkedin.com/in/thornike/) · [MIT License](LICENSE)

If this package helps you, a ⭐ on GitHub means a lot.

</div>
