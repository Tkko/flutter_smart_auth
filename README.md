<div align="center">
 <h1 align="center" style="font-size: 70px;">Flutter Smart Auth From <a href="https://www.linkedin.com/in/thornike/" target="_blank">Tornike </a> & Great <a href="https://github.com/Tkko/Flutter_Pinput/graphs/contributors" target="_blank">Contributors</a> </h1>

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

[![Pub package](https://img.shields.io/pub/v/smart_auth.svg)](https://pub.dev/packages/smart_auth)
[![GitHub starts](https://img.shields.io/github/stars/tkko/flutter_smart_auth.svg?style=flat&logo=github&colorB=deeppink&label=stars)](https://github.com/tkko/flutter_smart_auth)
[![style: effective dart](https://img.shields.io/badge/style-effective_dart-40c4ff.svg)](https://github.com/tenhobi/effective_dart)
[![pub package](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

</div>

Flutter package for listening SMS code on Android, suggesting phone number, email, saving a credential.

If you need pin code input like shown below, take a look at [Pinput](https://github.com/Tkko/Flutter_Pinput) package, SmartAuth is already integrated into it and you can build highly customizable input, that your designers can't even draw in Figma 🤭

Bonus tip: 🤫 Tell your PM that you need a week to implement the feature and chill with your friends meanwhile.

`Note that only Android is supported, I faked other operating systems because other package is depended on this one and that package works on every system`

<img src="https://user-images.githubusercontent.com/26390946/155599527-fe934f2c-5124-4754-bbf6-bb97d55a77c0.gif" height="600"/>

## Features:

- Android Autofill
  - SMS Retriever [API](https://developers.google.com/identity/sms-retriever/overview?hl=en)
  - SMS User Consent [API](https://developers.google.com/identity/sms-retriever/user-consent/overview)
- Showing Hint Dialog
- Getting Saved Credential
- Saving Credential
- Deleting Credential

## Support

PRs Welcome

Discord [Channel](https://rebrand.ly/qwc3s0d)

[Example](https://github.com/Tkko/flutter_smart_auth/tree/master/example/lib)

Don't forget to give it a star ⭐

## Demo

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

Get SMS code

```dart
  void getSmsCode() async {
    final res = await smartAuth.getSmsCode();
    if (res.succeed) {
      debugPrint('SMS: ${res.code}');
    } else {
      debugPrint('SMS Failure:');
    }
  }
```

The plugin automatically removes listeners after receiving the code, if not you can remove them by calling the `removeSmsListener` method

```dart
  void removeSmsListener() {
    smartAuth.removeSmsListener();
  }
```

Request hints to the user

```dart
  void requestHint() async {
    final res = await smartAuth.requestHint(
      isPhoneNumberIdentifierSupported: true,
      isEmailAddressIdentifierSupported: true,
      showCancelButton: true,
    );
    debugPrint('requestHint: $res');
  }
```

<img src="https://user-images.githubusercontent.com/26390946/158823942-3f0a1d6f-c669-4517-978d-25fea38a871e.png" height="600" alt="Request Hint" />

Get saved credential

```dart
  // identifier Url
  final accountType = 'https://developers.google.com';
  // Value you want to save, phone number or email for example
  final credentialId = 'Credential Id';
  final credentialName = 'Credential Name';
  final profilePictureUri = 'https://profilePictureUri.com';
```

```dart
  void getCredential() async {
    final res = await smartAuth.getCredential(
      accountType: accountType,
      showResolveDialog: true,
    );
    debugPrint('getCredentials: $res');
  }
```

<img src="https://user-images.githubusercontent.com/26390946/158823952-90db7d68-b1f1-4110-82b3-4ba69306e95a.png"  height="600" alt="Get Credential" />

Save credential

```dart
  void saveCredential() async {
    final res = await smartAuth.saveCredential(
      id: credentialId,
      name: credentialName,
      accountType: accountType,
      profilePictureUri: profilePictureUri,
    );
    debugPrint('saveCredentials: $res');
  }
```

<img src="https://user-images.githubusercontent.com/26390946/158823965-f8a70d11-3a10-4270-bcd1-66e53c05d2e1.png" height="600" alt="Save Credential" />

Delete credential

```dart
  void deleteCredential() async {
    final res = await smartAuth.deleteCredential(
      id: credentialId,
      accountType: accountType,
    );
    debugPrint('removeCredentials: $res');
  }
```

## API

#### getAppSignature

```dart
  /// This method outputs hash that is required for SMS Retriever API [https://developers.google.com/identity/sms-retriever/overview?hl=en]
  /// SMS must contain this hash at the end of the text
  /// Note that hash for debug and release if different
  Future<String?> getAppSignature()
```

#### getSmsCode

```dart
  /// Starts listening to SMS that contains the App signature [getAppSignature] in the text
  /// returns code if it matches with matcher
  /// More about SMS Retriever API [https://developers.google.com/identity/sms-retriever/overview?hl=en]
  ///
  /// If useUserConsentApi is true SMS User Consent API will be used [https://developers.google.com/identity/sms-retriever/user-consent/overview]
  /// Which shows confirmations dialog to user to confirm reading the SMS content
  Future<SmsCodeResult> getSmsCode({
    // used to extract code from SMS
    String matcher = _defaultCodeMatcher,
    // Optional parameter for User Consent API
    String? senderPhoneNumber,
    // if true SMS User Consent API will be used otherwise plugin will use SMS Retriever API
    bool useUserConsentApi = false,
  })
```

#### removeSmsListener

```dart
  /// Removes listener for [getSmsCode]
  Future<void> removeSmsListener()

  /// Disposes [getSmsCode] if useUserConsentApi is false listener
  Future<bool> removeSmsRetrieverListener()

  /// Disposes [getSmsCode] if useUserConsentApi is true listener
  Future<bool> removeSmsUserConsentListener()
```

#### requestHint

```dart
  /// Opens dialog of user emails and/or phone numbers
  /// More about hint request [https://developers.google.com/identity/smartlock-passwords/android/retrieve-hints]
  /// More about parameters [https://developers.google.com/android/reference/com/google/android/gms/auth/api/credentials/HintRequest.Builder]
  Future<Credential?> requestHint({
    // Enables returning credential hints where the identifier is an email address,
    // intended for use with a password chosen by the user.
    bool? isEmailAddressIdentifierSupported,
    // Enables returning credential hints where the identifier is a phone number,
    // intended for use with a password chosen by the user or SMS verification.
    bool? isPhoneNumberIdentifierSupported,
    // The list of account types (identity providers) supported by the app.
    // typically in the form of the associated login domain for each identity provider.
    String? accountTypes,
    // Enables button to add account
    bool? showAddAccountButton,
    // Enables button to cancel request
    bool? showCancelButton,
    // Specify whether an ID token should be acquired for hints, if available for the selected credential identifier.This is enabled by default;
    // disable this if your app does not use ID tokens as part of authentication to decrease latency in retrieving credentials and credential hints.
    bool? isIdTokenRequested,
    // Specify a nonce value that should be included in any generated ID token for this request.
    String? idTokenNonce,
    //Specify the server client ID for the backend associated with this app.
    // If a Google ID token can be generated for a retrieved credential or hint,
    // and the specified server client ID is correctly configured to be associated with the app,
    // then it will be used as the audience of the generated token. If a null value is specified,
    // the default audience will be used for the generated ID token.
    String? serverClientId,
  })
```

#### getCredential

```dart
  /// Tries to suggest a zero-click sign-in account. Only call this if your app does not currently know who is signed in.
  /// If zero-click suggestion fails app show dialog of credentials to choose from
  /// More about this https://developers.google.com/android/reference/com/google/android/gms/auth/api/credentials/CredentialsApi?hl=en#save(com.google.android.gms.common.api.GoogleApiClient,%20com.google.android.gms.auth.api.credentials.Credential)
  Future<Credential?> getCredential({
    // Identifier url, should be you App's website url
    String? accountType,
    String? serverClientId,
    String? idTokenNonce,
    bool? isIdTokenRequested,
    bool? isPasswordLoginSupported,
    // If we can't get credential without user interaction,
    // we can show dialog to prompt user to choose credential
    bool showResolveDialog = false,
  })
```

#### saveCredential

```dart
  /// Saves a credential that was used to sign in to the app. If disableAutoSignIn was previously called and the save operation succeeds,
  /// auto sign-in will be re-enabled if the user's settings permit this.
  ///
  /// Note: On Android O and above devices save requests that require showing a save confirmation may be cancelled
  /// in favor of the active Autofill service's save dialog.
  /// This behavior may be overridden by using Auth.AuthCredentialsOptions.Builder.forceEnableSaveDialog().
  /// Please see the overview documentation for more details on providing the best user experience when targeting Android O and above.
  /// More about this https://developers.google.com/android/reference/com/google/android/gms/auth/api/credentials/CredentialsApi?hl=en#save(com.google.android.gms.common.api.GoogleApiClient,%20com.google.android.gms.auth.api.credentials.Credential)
  Future<bool> saveCredential({
    // Value you want to save
    required String id,
    // Identifier url, should be you App's website url
    String? accountType,
    String? name,
    String? password,
    String? profilePictureUri,
  })
```

#### deleteCredential

```dart
  /// Deletes a credential that is no longer valid for signing into the app.
  /// More about this https://developers.google.com/android/reference/com/google/android/gms/auth/api/credentials/CredentialsApi?hl=en#save(com.google.android.gms.common.api.GoogleApiClient,%20com.google.android.gms.auth.api.credentials.Credential)
  Future<bool> deleteCredential({
    // Value you want to save
    required String id,
    // Identifier url, should be you App's website url
    String? accountType,
    String? name,
    String? password,
    String? profilePictureUri,
  })
```
