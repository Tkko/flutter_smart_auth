#### 3.0.0-beta.1 · 19/12/2024

- Upgraded Android Dependencies [PR](https://github.com/Tkko/flutter_smart_auth/pull/28) - with help
  of [OneXeor](https://github.com/OneXeor) 🙏
- Kotlin version 2.0.0
- gradle plugin 8.3.2
- android sdk 35
- core-ktx 1.15.0
- Java 21
- Migrated to Pigeon
- Added new Credentials
  Manager [API](https://developers.google.com/identity/android-credential-manager)
    - `requestPhoneNumberHint`
- Removed deprecated SmartLock API
    - `getCredential`
    - `saveCredential`
    - `deleteCredential`

#### 2.0.0 · 21/01/2024

- Fixed RECEIVER_EXPORTED exception in android SDK
  34 [PR](https://github.com/Tkko/flutter_smart_auth/pull/16)
- Fix "Namespace not specified" error when upgrading to AGP
  8.0 [PR](https://github.com/Tkko/flutter_smart_auth/pull/11)
- Updated readme
- Formatted example app

#### 1.1.1 · 24/07/2023

- Fixed AGP 4.2<= compatibility
- Updated SDK constraints
- Updated default SMS code matcher regex length to 8 digits

#### 1.1.0 · 12/05/2023

- Upgraded Gradle to 7.2.0
- Added GitHub Actions
    - Static Analysis

#### 1.0.8 · 29/12/2022

- Fixed Error receiving broadcast Intent

## 1.0.6

- Improved doc**s

## 1.0.5

- Remove downcast of Activity => FlutterActivity

## 1.0.4

- Replaced dart.io with foundation.dart

## 1.0.3

- Fake support of all operating systems, because other packages is depended on this one

## 1.0.1

- Fixed reinitializing listeners
- Fixed Typos

## 0.9.1

Initial Release

- Android Autofill**
    - SMS Retriever [API](https://developers.google.com/identity/sms-retriever/overview?hl=en)
    - SMS User
      Consent [API](https://developers.google.com/identity/sms-retriever/user-consent/overview)
- Showing Hint Dialog
- Getting Saved Credential
- Saving Credential
- Deleting Credential