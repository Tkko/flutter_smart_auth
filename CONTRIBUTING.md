# Contributing to SmartAuth

If you want to fix or improve the current functionality:

### Overview

This project uses [Pigeon](https://pub.dev/packages/pigeon) which is a code generator for
communication between Flutter and the host platform. If you want to change add new method or change
the existing ones, you need to modify the `pigeon/smart_auth_api.dart` file and run the following
command to generate the new code:

```bash
dart run pigeon --input pigeon/smart_auth_api.dart
```

The generated code will be in the `lib/src/smart_auth_api.g.dart`
`android/src/main/kotlin/fman/ge/smart_auth/smart_auth_api.g.kt`
but you don't need to touch these files.

If you want to make changed in the Android part, you need to modify the
`android/src/main/kotlin/fman/ge/smart_auth/SmartAuthPlugin.kt` file.

If you want to make changes in the iOS part, you need to modify the `lib/src/smart_auth.dart` file.

### Preparing the environment

1. Fork the repository
2. Clone the forked project to your local machine
3. Create a new branch (`git checkout -b improve-feature`)
4. If you want to chane anything in Kotlin, run Android Studio, click `open` and select the
   `build.gradle` file in
   `example/android/app/build.gradle`, this way Android Studio will recognize the Android project
   and run the gradle sync so you won't see any errors while working in the kotlin files
5. If you want to change anything in Dart, just open the project root folder in ant IDE of your
   choice


