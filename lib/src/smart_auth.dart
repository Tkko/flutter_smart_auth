import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

part 'sms_code_result.dart';

part 'credential.dart';

const _defaultCodeMatcher = '\\d{4,7}';

class SmartAuth {
  static const MethodChannel _channel = MethodChannel('fman.smart_auth');

  /// This method outputs hash that is required for SMS Retriever API [https://developers.google.com/identity/sms-retriever/overview?hl=en]
  /// SMS must contain this hash at the end of the text
  /// Note that hash for debug and release if different
  Future<String?> getAppSignature() async {
    if (_isAndroid('getAppSignature')) {
      return _channel.invokeMethod('getAppSignature');
    }
    return null;
  }

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
  }) async {
    if (senderPhoneNumber != null) {
      assert(useUserConsentApi == true,
          'senderPhoneNumber is only supported if useUserConsentApi is true');
    }

    if (_isAndroid('getSmsCode')) {
      final String? sms = useUserConsentApi
          ? await _channel.invokeMethod(
              'startSmsUserConsent', {'senderPhoneNumber': senderPhoneNumber})
          : await _channel.invokeMethod('startSmsRetriever');
      return SmsCodeResult.fromSms(sms, matcher);
    }
    return SmsCodeResult.fromSms(null, matcher);
  }

  /// Removes listener for [getSmsCode]
  Future<void> removeSmsListener() async {
    if (_isAndroid('removeSmsListener')) {
      await _channel.invokeMethod('stopSmsRetriever');
      await _channel.invokeMethod('stopSmsUserConsent');
      return;
    }
  }

  /// Disposes [getSmsCode] if useUserConsntApi is false listener
  Future<bool> removeSmsRetrieverListener() async {
    if (_isAndroid('removeSmsRetrieverListener')) {
      final res = await _channel.invokeMethod('stopSmsRetriever');
      return res == true;
    }
    return false;
  }

  /// Disposes [getSmsCode] if useUserConsntApi is true listener
  Future<bool> removeSmsUserConsentListener() async {
    if (_isAndroid('removeSmsUserConsentListener')) {
      final res = await _channel.invokeMethod('stopSmsUserConsent');
      return res == true;
    }
    return false;
  }

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
  }) async {
    if (_isAndroid('requestHint')) {
      final res = await _channel.invokeMethod('requestHint', {
        'isEmailAddressIdentifierSupported': isEmailAddressIdentifierSupported,
        'isPhoneNumberIdentifierSupported': isPhoneNumberIdentifierSupported,
        'accountTypes': accountTypes,
        'isIdTokenRequested': isIdTokenRequested,
        'showAddAccountButton': showAddAccountButton,
        'showCancelButton': showCancelButton,
        'idTokenNonce': idTokenNonce,
        'serverClientId': serverClientId,
      });
      if (res == null) return null;

      try {
        final Map<String, dynamic> map =
            jsonDecode(jsonEncode(res)) as Map<String, dynamic>;
        return Credential.fromJson(map);
      } catch (e) {
        debugPrint('$e');
        return null;
      }
    }
    return null;
  }

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
    // If we can't get credential without user interaction,
    // we can show dialog to prompt user to choose credential
    bool showResolveDialog = false,
  }) async {
    if (_isAndroid('getCredential')) {
      final res = await _channel.invokeMethod('getCredential', {
        'accountType': accountType,
        'serverClientId': serverClientId,
        'idTokenNonce': idTokenNonce,
        'isIdTokenRequested': isIdTokenRequested,
        'isPasswordLoginSupported': isPasswordLoginSupported,
        'showResolveDialog': showResolveDialog,
      });

      if (res == null) return null;

      try {
        final Map<String, dynamic> map =
            jsonDecode(jsonEncode(res)) as Map<String, dynamic>;
        return Credential.fromJson(map);
      } catch (e) {
        debugPrint('$e');
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
    if (_isAndroid('saveCredential')) {
      final res = await _channel.invokeMethod('saveCredential', {
        'id': id,
        'accountType': accountType,
        'name': name,
        'password': password,
        'profilePictureUri': profilePictureUri,
      });
      return res == true;
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
    if (_isAndroid('deleteCredential')) {
      final res = await _channel.invokeMethod('deleteCredential', {
        'id': id,
        'accountType': accountType,
        'name': name,
        'password': password,
        'profilePictureUri': profilePictureUri,
      });
      return res == true;
    }
    return false;
  }

  bool _isAndroid(String method) {
    if (defaultTargetPlatform == TargetPlatform.android) return true;
    debugPrint('SmartAuth $method is not supported on $defaultTargetPlatform');
    return false;
  }
}
