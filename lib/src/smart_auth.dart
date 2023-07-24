import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

part 'sms_code_result.dart';

part 'credential.dart';

const _defaultCodeMatcher = '\\d{4,8}';

class Methods {
  static const getAppSignature = 'getAppSignature';
  static const startSmsRetriever = 'startSmsRetriever';
  static const stopSmsRetriever = 'stopSmsRetriever';
  static const startSmsUserConsent = 'startSmsUserConsent';
  static const stopSmsUserConsent = 'stopSmsUserConsent';
  static const requestHint = 'requestHint';
  static const getCredential = 'getCredential';
  static const saveCredential = 'saveCredential';
  static const deleteCredential = 'deleteCredential';
}

/// Flutter package for listening SMS code on Android, suggesting phone number, email, saving a credential.
///
/// If you need pin code input like shown below, take a look at [Pinput](https:///github.com/Tkko/Flutter_Pinput) package, SmartAuth is already integrated into it and you can build highly customizable input, that your designers can't even draw in Figma 🤭
/// `Note that only Android is supported, I faked other operating systems because other package is depended on this one and that package works on every system`
///
/// <img src="https:///user-images.githubusercontent.com/26390946/155599527-fe934f2c-5124-4754-bbf6-bb97d55a77c0.gif" height="600"/>
///
/// ## Features:
/// - Android Autofill
///   - SMS Retriever [API](https:///developers.google.com/identity/sms-retriever/overview?hl=en)
///   - SMS User Consent [API](https:///developers.google.com/identity/sms-retriever/user-consent/overview)
/// - Showing Hint Dialog
/// - Getting Saved Credential
/// - Saving Credential
/// - Deleting Credential
class SmartAuth {
  static const MethodChannel _channel = MethodChannel('fman.smart_auth');

  /// This method outputs hash that is required for SMS Retriever API https://developers.google.com/identity/sms-retriever/overview?hl=en
  /// SMS must contain this hash at the end of the text
  /// Note that hash for debug and release if different
  Future<String?> getAppSignature() async {
    if (_isAndroid(Methods.getAppSignature)) {
      return _channel.invokeMethod(Methods.getAppSignature);
    }
    return null;
  }

  /// Starts listening to SMS that contains the App signature [getAppSignature] in the text
  /// returns code if it matches with matcher
  /// More about SMS Retriever API https://developers.google.com/identity/sms-retriever/overview?hl=en
  ///
  /// If useUserConsentApi is true SMS User Consent API will be used https://developers.google.com/identity/sms-retriever/user-consent/overview
  /// Which shows confirmations dialog to user to confirm reading the SMS content
  Future<SmsCodeResult> getSmsCode({
    // used to extract code from SMS
    String matcher = _defaultCodeMatcher,
    // Optional parameter for User Consent API
    String? senderPhoneNumber,
    // if true SMS User Consent API will be used otherwise plugin will use SMS Retriever API
    bool useUserConsentApi = false,
  }) async {
    if (senderPhoneNumber != null) {
      assert(
        useUserConsentApi == true,
        'senderPhoneNumber is only supported if useUserConsentApi is true',
      );
    }
    try {
      if (_isAndroid('getSmsCode')) {
        final String? sms = useUserConsentApi
            ? await _channel.invokeMethod(Methods.startSmsUserConsent, {
                'senderPhoneNumber': senderPhoneNumber,
              })
            : await _channel.invokeMethod(Methods.startSmsRetriever);
        return SmsCodeResult.fromSms(sms, matcher);
      }
    } catch (error) {
      debugPrint('Pinput/SmartAuth: getSmsCode failed: $error');
      return SmsCodeResult.fromSms(null, matcher);
    }

    return SmsCodeResult.fromSms(null, matcher);
  }

  /// Removes listener for [getSmsCode]
  Future<void> removeSmsListener() async {
    if (_isAndroid('removeSmsListener')) {
      try {
        Future.wait([
          removeSmsRetrieverListener(),
          removeSmsUserConsentListener(),
        ]);
      } catch (error) {
        debugPrint('Pinput/SmartAuth: removeSmsListener failed: $error');
      }
    }
  }

  /// Disposes [getSmsCode] if useUserConsentApi is false listener
  Future<bool> removeSmsRetrieverListener() async {
    try {
      if (_isAndroid('removeSmsRetrieverListener')) {
        final res = await _channel.invokeMethod(Methods.stopSmsRetriever);
        return res == true;
      }
    } catch (error) {
      debugPrint('Pinput/SmartAuth: removeSmsRetrieverListener failed: $error');
    }
    return false;
  }

  /// Disposes [getSmsCode] if useUserConsentApi is true listener
  Future<bool> removeSmsUserConsentListener() async {
    try {
      if (_isAndroid('removeSmsUserConsentListener')) {
        final res = await _channel.invokeMethod(Methods.stopSmsUserConsent);
        return res == true;
      }
    } catch (error) {
      debugPrint(
        'Pinput/SmartAuth: removeSmsUserConsentListener failed: $error',
      );
    }
    return false;
  }

  /// Opens dialog of user emails and/or phone numbers
  /// More about hint request https://developers.google.com/identity/smartlock-passwords/android/retrieve-hints
  /// More about parameters https://developers.google.com/android/reference/com/google/android/gms/auth/api/credentials/HintRequest.Builder
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
  }) async {
    if (_isAndroid(Methods.requestHint)) {
      try {
        final res = await _channel.invokeMethod(Methods.requestHint, {
          'isEmailAddressIdentifierSupported':
              isEmailAddressIdentifierSupported,
          'isPhoneNumberIdentifierSupported': isPhoneNumberIdentifierSupported,
          'accountTypes': accountTypes,
          'isIdTokenRequested': isIdTokenRequested,
          'showAddAccountButton': showAddAccountButton,
          'showCancelButton': showCancelButton,
          'idTokenNonce': idTokenNonce,
          'serverClientId': serverClientId,
        });
        if (res == null) return null;
        final Map<String, dynamic> map =
            jsonDecode(jsonEncode(res)) as Map<String, dynamic>;
        return Credential.fromJson(map);
      } catch (error) {
        debugPrint('Pinput/SmartAuth: requestHint failed: $error');
        return null;
      }
    }
    return null;
  }

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
  }) async {
    if (_isAndroid(Methods.getCredential)) {
      try {
        final res = await _channel.invokeMethod(Methods.getCredential, {
          'accountType': accountType,
          'serverClientId': serverClientId,
          'idTokenNonce': idTokenNonce,
          'isIdTokenRequested': isIdTokenRequested,
          'isPasswordLoginSupported': isPasswordLoginSupported,
          'showResolveDialog': showResolveDialog,
        });

        if (res == null) return null;

        final Map<String, dynamic> map =
            jsonDecode(jsonEncode(res)) as Map<String, dynamic>;
        return Credential.fromJson(map);
      } catch (error) {
        debugPrint('Pinput/SmartAuth: getCredential failed: $error');
        return null;
      }
    }
    return null;
  }

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
  }) async {
    if (_isAndroid(Methods.saveCredential)) {
      try {
        final res = await _channel.invokeMethod(Methods.saveCredential, {
          'id': id,
          'accountType': accountType,
          'name': name,
          'password': password,
          'profilePictureUri': profilePictureUri,
        });
        return res == true;
      } catch (error) {
        debugPrint('Pinput/SmartAuth: saveCredential failed: $error');
        return false;
      }
    }
    return false;
  }

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
  }) async {
    if (_isAndroid(Methods.deleteCredential)) {
      try {
        final res = await _channel.invokeMethod(Methods.deleteCredential, {
          'id': id,
          'accountType': accountType,
          'name': name,
          'password': password,
          'profilePictureUri': profilePictureUri,
        });
        return res == true;
      } catch (error) {
        debugPrint('Pinput/SmartAuth: deleteCredential failed: $error');
        return false;
      }
    }
    return false;
  }

  bool _isAndroid(String method) {
    if (defaultTargetPlatform == TargetPlatform.android) return true;
    debugPrint('SmartAuth $method is not supported on $defaultTargetPlatform');
    return false;
  }
}
