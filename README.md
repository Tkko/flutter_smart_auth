
<div align="center">
 <h1 align="center" style="font-size: 70px;">Flutter Pinput From <a href="https://www.linkedin.com/in/thornike/" target="_blank">Tornike </a> & Great <a href="https://github.com/Tkko/Flutter_Pinput/graphs/contributors" target="_blank">Contributors</a> </h1>

<a href="https://www.buymeacoffee.com/fman" target="_blank"><img src="https://img.buymeacoffee.com/button-api/?text=Thank me with a coffee&emoji=&slug=fman&button_colour=40DCA5&font_colour=ffffff&font_family=Poppins&outline_colour=000000&coffee_colour=FFDD00"></a>

</div>


Flutter for listening SMS code on Android, suggesting phone number, email, saving credential

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
  void getAppSignatue() async {
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
Plugin automatically removes listeners after recieving the code, if not you can remove by calling `removeSmsListener` method

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
  /// returns code if it macthes with matcher
  /// More about SMS Retriever API  [https://developers.google.com/identity/sms-retriever/overview?hl=en]
  ///
  /// If useUserConsntApi is true SMS User Consent API will be used [https://developers.google.com/identity/sms-retriever/user-consent/overview]
  /// Which shows confirmations dialog to user to confiirm reading the SMS content
  Future<SmsCodeResult> getSmsCode({
    // used to extract code from SMS
    String matcher = _defaultCodeMatcher,
    // Optional parameter for User Consnt API
    String? senderPhoneNumber,
    // if true SMS User Consent API will be used otherwise plugin will use SMS Retriever API
    bool useUserConsntApi = false,
  })
```


#### removeSmsListener

```dart
  /// Removes listener for [getSmsCode]
  Future<void> removeSmsListener()

  /// Disposes [getSmsCode] if useUserConsntApi is false listener
  Future<bool> removeSmsRetrieverListener()

  /// Disposes [getSmsCode] if useUserConsntApi is true listener
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
  /// If zero-click suggestion fails app show dialog of credentials to chooze from
  /// More about this https://developers.google.com/android/reference/com/google/android/gms/auth/api/credentials/CredentialsApi?hl=en#save(com.google.android.gms.common.api.GoogleApiClient,%20com.google.android.gms.auth.api.credentials.Credential)
  Future<Credential?> getCredential({
    // Identifier url, should be you App's website url
    String? accountType,
    String? serverClientId,
    String? idTokenNonce,
    bool? isIdTokenRequested,
    bool? isPasswordLoginSupported,
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

