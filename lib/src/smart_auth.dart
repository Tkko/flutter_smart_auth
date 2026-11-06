import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:smart_auth/src/models/smart_auth_result.dart';
import 'package:smart_auth/src/models/sms_code_result.dart';
import 'package:smart_auth/src/smart_auth_api.g.dart';

const _defaultCodeMatcher = r'\d{4,8}';

/// Flutter package for listening SMS code on Android, suggesting phone number.
///
/// If you need pin code input like shown below, take a look at [Pinput](https:///github.com/Tkko/Flutter_Pinput) package
/// `Note that only Android is supported, I faked other operating systems
/// because other package is depended on this one and that package works
/// on every system`
///
/// <img src="https:///user-images.githubusercontent.com/26390946/155599527-fe934f2c-5124-4754-bbf6-bb97d55a77c0.gif" height="600"/>
///
/// ## Features:
/// - Android Autofill
///   - SMS Retriever [API](https://developers.google.com/identity/sms-retriever/overview?hl=en)
///   - SMS User Consent [API](https://developers.google.com/identity/sms-retriever/user-consent/overview)
/// - Credential Manager: get, save and clear passwords and passkeys [API](https://developer.android.com/identity/sign-in/credential-manager)
/// - Showing Phone Number Hint Dialog [API](https://developers.google.com/identity/phone-number-hint/android)
class SmartAuth {
  SmartAuth._();

  /// Singleton instance of SmartAuth
  static final SmartAuth _instance = SmartAuth._();

  /// getter for singleton instance
  static SmartAuth get instance => _instance;

  /// A Generated class from pigeon that contains methods
  /// to interact with native code
  final SmartAuthApi _api = SmartAuthApi();

  /// This method outputs hash that is required for SMS Retriever API https://developers.google.com/identity/sms-retriever/overview?hl=en
  /// SMS must contain this hash at the end of the text
  /// Note that hash for debug and release if different
  Future<SmartAuthResult<String>> getAppSignature() async {
    try {
      final result = await _api.getAppSignature();
      return SmartAuthResult.success(result);
    } catch (error) {
      debugPrint('Pinput/SmartAuth: getAppSignature failed: $error');
      return SmartAuthResult.failure(
        'Failed to get app signature with error: $error',
      );
    }
  }

  /// Starts listening to SMS that contains
  /// the App signature [getAppSignature]in the text
  /// returns code if it matches with matcher
  /// More about SMS Retriever API https://developers.google.com/identity/sms-retriever/overview?hl=en
  ///
  /// Only one SMS call can wait at a time: starting another one finishes
  /// this one as canceled.
  Future<SmartAuthResult<SmartAuthSms>> getSmsWithRetrieverApi({
    /// used to extract code from SMS
    String matcher = _defaultCodeMatcher,
  }) async {
    try {
      final result = await _api.getSmsWithRetrieverApi();
      return SmartAuthResult.success(SmartAuthSms.fromSms(result, matcher));
    } catch (error) {
      final isCanceled =
          error is PlatformException &&
          error.details is SmartAuthRequestCanceled;

      if (isCanceled) {
        debugPrint('Pinput/SmartAuth: ${error.message}');
        return const SmartAuthResult.canceled();
      }
      debugPrint('Pinput/SmartAuth: getSmsWithRetrieverApi failed: $error');
      return SmartAuthResult.failure(
        'Failed to get SMS with retriever API with error: $error',
      );
    }
  }

  /// Starts listening to SMS User Consent API https://developers.google.com/identity/sms-retriever/user-consent/overview
  /// Which shows confirmations dialog to user to
  /// confirm reading the SMS content
  /// returns code if it matches with matcher
  ///
  /// Only one SMS call can wait at a time: starting another one finishes
  /// this one as canceled.
  Future<SmartAuthResult<SmartAuthSms>> getSmsWithUserConsentApi({
    /// used to extract code from SMS
    String matcher = _defaultCodeMatcher,

    /// Optional parameter for User Consent API
    String? senderPhoneNumber,
  }) async {
    try {
      final result = await _api.getSmsWithUserConsentApi(senderPhoneNumber);
      return SmartAuthResult.success(SmartAuthSms.fromSms(result, matcher));
    } catch (error) {
      final isCanceled =
          error is PlatformException &&
          error.details is SmartAuthRequestCanceled;

      if (isCanceled) {
        debugPrint('Pinput/SmartAuth: ${error.message}');
        return const SmartAuthResult.canceled();
      }
      debugPrint('Pinput/SmartAuth: getSmsWithUserConsentApi failed: $error');
      return SmartAuthResult.failure(
        'Failed to get SMS with user consent API with error: $error',
      );
    }
  }

  /// Removes listener for [getSmsWithUserConsentApi]
  /// A call that is still waiting for an SMS finishes as canceled.
  Future<SmartAuthResult<void>> removeUserConsentApiListener() async {
    try {
      await _api.removeUserConsentListener();
      return const SmartAuthResult.success(null);
    } catch (error) {
      debugPrint('Pinput/SmartAuth: removeUserConsentListener failed: $error');
      return SmartAuthResult.failure(
        'Failed to remove user consent listener with error: $error',
      );
    }
  }

  /// Removes listener for [getSmsWithRetrieverApi]
  /// A call that is still waiting for an SMS finishes as canceled.
  Future<SmartAuthResult<void>> removeSmsRetrieverApiListener() async {
    try {
      await _api.removeSmsRetrieverListener();
      return const SmartAuthResult.success(null);
    } catch (error) {
      debugPrint('Pinput/SmartAuth: removeSmsRetrieverListener failed: $error');
      return SmartAuthResult.failure(
        'Failed to remove sms retriever listener with error: $error',
      );
    }
  }

  /// Runs the Phone Number Hint API, a library powered by Google Play services
  /// provides a frictionless way to show a user’s (SIM-based)
  /// phone numbers as a hint.
  /// https://developers.google.com/identity/phone-number-hint/android
  Future<SmartAuthResult<String>> requestPhoneNumberHint() async {
    try {
      final result = await _api.requestPhoneNumberHint();
      return SmartAuthResult.success(result);
    } catch (error) {
      final isCanceled =
          error is PlatformException &&
          error.details is SmartAuthRequestCanceled;
      if (isCanceled) {
        debugPrint('Pinput/SmartAuth: requestPhoneNumberHint canceled by user');
        return const SmartAuthResult.canceled();
      }

      final message = 'Failed to request phone number hint with error: $error';
      debugPrint('Pinput/SmartAuth: $message');
      return SmartAuthResult.failure(message);
    }
  }

  /// Shows the account selector of the Credential Manager and
  /// returns the credential selected by the user.
  /// Pass [passwordOption] to get saved passwords and
  /// [publicKeyOptions] to sign in with a passkey.
  /// At least one option is required.
  /// https://developer.android.com/identity/sign-in/credential-manager
  Future<SmartAuthResult<SmartAuthCredential>> getCredential({
    SmartAuthPasswordOption? passwordOption,
    List<SmartAuthPublicKeyOption>? publicKeyOptions,
    bool? preferImmediatelyAvailableCredentials,
    String? origin,
  }) {
    return _runCredentialRequest(
      'getCredential',
      () => _api.getCredential(
        SmartAuthGetCredentialRequest(
          passwordOption: passwordOption,
          publicKeyOptions: publicKeyOptions,
          preferImmediatelyAvailableCredentials:
              preferImmediatelyAvailableCredentials,
          origin: origin,
        ),
      ),
    );
  }

  /// Saves a password to the Credential Manager.
  ///
  /// Needs a credential provider on the device, such as Google Password
  /// Manager with a signed-in Google account. Without one this fails with
  /// `TYPE_NO_CREATE_OPTIONS`.
  Future<SmartAuthResult<SmartAuthCreateCredentialResponse>>
  createPasswordCredential({
    required String id,
    required String password,
    bool? isAutoSelectAllowed,
    bool? preferImmediatelyAvailableCredentials,
    String? origin,
  }) {
    return _runCredentialRequest(
      'createPasswordCredential',
      () => _api.createCredential(
        SmartAuthCreateCredentialRequest(
          type: SmartAuthCredentialType.password,
          id: id,
          password: password,
          isAutoSelectAllowed: isAutoSelectAllowed,
          preferImmediatelyAvailableCredentials:
              preferImmediatelyAvailableCredentials,
          origin: origin,
        ),
      ),
    );
  }

  /// Creates a passkey, [requestJson] is the registration request
  /// in the WebAuthn JSON format.
  /// The registration response to send to your server is in
  /// [SmartAuthCreateCredentialResponse.registrationResponseJson].
  ///
  /// Needs a credential provider on the device, such as Google Password
  /// Manager with a signed-in Google account. Without one this fails with
  /// `TYPE_NO_CREATE_OPTIONS`.
  Future<SmartAuthResult<SmartAuthCreateCredentialResponse>>
  createPublicKeyCredential({
    required String requestJson,
    Uint8List? clientDataHash,
    bool? preferImmediatelyAvailableCredentials,
    String? origin,
  }) {
    return _runCredentialRequest(
      'createPublicKeyCredential',
      () => _api.createCredential(
        SmartAuthCreateCredentialRequest(
          type: SmartAuthCredentialType.publicKey,
          requestJson: requestJson,
          clientDataHash: clientDataHash,
          preferImmediatelyAvailableCredentials:
              preferImmediatelyAvailableCredentials,
          origin: origin,
        ),
      ),
    );
  }

  /// Fetches the credential data in advance to reduce the latency of
  /// the account selector.
  /// Call [getPreparedCredential] afterwards to show it.
  /// Android 14 or higher only.
  Future<SmartAuthResult<SmartAuthPreparedCredential>> prepareGetCredential({
    SmartAuthPasswordOption? passwordOption,
    List<SmartAuthPublicKeyOption>? publicKeyOptions,
    bool? preferImmediatelyAvailableCredentials,
    String? origin,
  }) {
    return _runCredentialRequest(
      'prepareGetCredential',
      () => _api.prepareGetCredential(
        SmartAuthGetCredentialRequest(
          passwordOption: passwordOption,
          publicKeyOptions: publicKeyOptions,
          preferImmediatelyAvailableCredentials:
              preferImmediatelyAvailableCredentials,
          origin: origin,
        ),
      ),
    );
  }

  /// Shows the account selector for the request passed to the
  /// last [prepareGetCredential]. Android 14 or higher only.
  Future<SmartAuthResult<SmartAuthCredential>> getPreparedCredential() {
    return _runCredentialRequest(
      'getPreparedCredential',
      _api.getPreparedCredential,
    );
  }

  /// Clears the credential state, call it when the user signs out.
  Future<SmartAuthResult<void>> clearCredentialState() {
    return _runCredentialRequest<void>(
      'clearCredentialState',
      _api.clearCredentialState,
    );
  }

  Future<SmartAuthResult<T>> _runCredentialRequest<T>(
    String method,
    Future<T> Function() request,
  ) async {
    try {
      return SmartAuthResult.success(await request());
    } catch (error) {
      final isCanceled =
          error is PlatformException &&
          error.details is SmartAuthRequestCanceled;
      if (isCanceled) {
        debugPrint('Pinput/SmartAuth: $method canceled by user');
        return SmartAuthResult.canceled();
      }

      final message = '$method failed with error: $error';
      debugPrint('Pinput/SmartAuth: $message');
      return SmartAuthResult.failure(message);
    }
  }
}
