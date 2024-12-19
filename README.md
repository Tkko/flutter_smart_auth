<div align="center">
 <h1 align="center" style="font-size: 70px;">Flutter Smart Auth</h1>

<!--  Donations -->
 <a href="https://ko-fi.com/flutterman">
  <img width="300" src="https://user-images.githubusercontent.com/26390946/161375567-9e14cd0e-1675-4896-a576-a449b0bcd293.png">
 </a>
 <div align="center">
   <a href="https://www.buymeacoffee.com/fman">
    <img width="150" alt="buymeacoffee" src="https://user-images.githubusercontent.com/26390946/161375563-69c634fd-89d2-45ac-addd-931b03996b34.png">
  </a>
   <a href="https://ko-fi.com/flutterman">
    <img width="150" alt="Ko-fi" src="https://user-images.githubusercontent.com/26390946/161375565-e7d64410-bbcf-4a28-896b-7514e106478e.png">
  </a>
 </div>
<!--  Donations -->

<h3 align="center" style="font-size: 35px;">Need anything Flutter related? Reach out
on <a href="https://www.linkedin.com/in/thornike/">LinkedIn</a>
</h3>

[![Pub package](https://img.shields.io/pub/v/smart_auth.svg)](https://pub.dev/packages/smart_auth)
[![GitHub starts](https://img.shields.io/github/stars/tkko/flutter_smart_auth.svg?style=flat&logo=github&colorB=deeppink&label=stars)](https://github.com/tkko/flutter_smart_auth)
[![style: effective dart](https://img.shields.io/badge/style-effective_dart-40c4ff.svg)](https://github.com/tenhobi/effective_dart)
[![pub package](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

</div>


Flutter package for listening SMS code on Android, suggesting phone number, email, saving a
credential.

If you need pin code input like shown below, take a look at
the [Pinput](https://github.com/Tkko/Flutter_Pinput) package.

<img src="https://user-images.githubusercontent.com/26390946/155599527-fe934f2c-5124-4754-bbf6-bb97d55a77c0.gif" height="500"/>

## Features:

- Android Autofill
    - SMS Retriever [API](https://developers.google.com/identity/sms-retriever/overview?hl=en)
    - SMS User Consent [API](https://developers.google.com/identity/sms-retriever/user-consent/overview)
- Showing Phone number hints [API](https://developers.google.com/identity/android-credential-manager)

## Support

PRs Welcome

Discord [Channel](https://rebrand.ly/qwc3s0d)

[Example](https://github.com/Tkko/flutter_smart_auth/blob/main/example/lib/main.dart)

Don't forget to give it a star ⭐

## Requirements

#### 1. Set kotlin version to 2.0.0 or above and gradle plugin version to 8.3.2

If you are
using [legacy imperative apply](https://docs.flutter.dev/release/breaking-changes/flutter-gradle-plugin-apply)

```
// android/build.gradle
buildscript {
    ext.kotlin_version = '2.0.0'
    ...others

    dependencies {
        classpath 'com.android.tools.build:gradle:8.3.2'
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"
    }
}
```

If you are using
new [declarative plugin approach](https://docs.gradle.org/8.5/userguide/plugins.html#sec:plugins_block)

```
// android/settings.gradle
plugins {
    id "org.jetbrains.kotlin.android" version "2.0.0" apply false
    id "com.android.application" version "8.3.2" apply false
    ...others
}
```

#### 2. Set gradle version to 8.9.0 or above - [more about gradle versions](https://developer.android.com/build/releases/gradle-plugin)

```
// android/gradle/wrapper/gradle-wrapper.properties
distributionUrl=https\://services.gradle.org/distributions/gradle-8.4-all.zip
```

#### 3. Set Java version to 21

```
// android/app/build.gradle
compileOptions {
    sourceCompatibility = JavaVersion.VERSION_21
    targetCompatibility = JavaVersion.VERSION_21
}

kotlinOptions {
    jvmTarget = JavaVersion.VERSION_21.toString()
}
```

## Getting Started

Create instance of SmartAuth

```dart

final smartAuth = SmartAuth();
```

Get the App signature

```dart
  void getAppSignature() async {
  final res = await smartAuth.getAppSignature();
  debugPrint('Signature: $res');
}
```

Get SMS with User Consent API

```dart
  void listenSms() async {
  final res = await smartAuth.listenSms();
  if (res.succeed) {
    debugPrint('SMS: ${res.code}');
  } else {
    debugPrint('SMS Failure:');
  }
}
```

Get SMS with SMS Retriever API

```dart
  void listenSmsRetriever() async {
  final res = await smartAuth.listenSmsRetriever();
  if (res.succeed) {
    debugPrint('SMS: ${res.code}');
  } else {
    debugPrint('SMS Failure:');
  }
}
```

The plugin automatically removes listeners after receiving the code, if not you can remove them by
calling the `removeUserConsentApiListener` or `removeSmsRetrieverApiListener` methods

```dart
  void removeSmsListener() {
  smartAuth.removeUserConsentApiListener();
  smartAuth.removeSmsRetrieverApiListener();
}
```

Request phone number hint

```dart
  void requestPhoneNumberHint() async {
  final res = await smartAuth.requestPhoneNumberHint();
  debugPrint('requestHint: $res');
}
```