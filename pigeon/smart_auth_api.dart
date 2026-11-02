import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/smart_auth_api.g.dart',
    kotlinOptions: KotlinOptions(package: 'dev.tornike.smart_auth'),
    kotlinOut:
        'android/src/main/kotlin/dev/tornike/smart_auth/smart_auth_api.g.kt',
  ),
)
@HostApi()
abstract class SmartAuthApi {
  String getAppSignature();

  @async
  String getSmsWithRetrieverApi();

  @async
  String getSmsWithUserConsentApi(String? phoneNumber);

  void removeSmsRetrieverListener();

  void removeUserConsentListener();

  @async
  String requestPhoneNumberHint();

  /// Credential Manager `getCredential`
  @async
  SmartAuthCredential getCredential(SmartAuthGetCredentialRequest request);

  /// Credential Manager `createCredential`
  @async
  SmartAuthCreateCredentialResponse createCredential(
    SmartAuthCreateCredentialRequest request,
  );

  /// Credential Manager `prepareGetCredential`, Android 14 or higher
  @async
  SmartAuthPreparedCredential prepareGetCredential(
    SmartAuthGetCredentialRequest request,
  );

  /// Credential Manager `getCredential` with the handle of the last
  /// [prepareGetCredential], Android 14 or higher
  @async
  SmartAuthCredential getPreparedCredential();

  /// Credential Manager `clearCredentialState`
  @async
  void clearCredentialState();
}

/// Type of the credential, [unknown] is returned for the types that are not supported yet
enum SmartAuthCredentialType { password, publicKey, unknown }

/// Maps to `GetPasswordOption`
class SmartAuthPasswordOption {
  SmartAuthPasswordOption({this.isAutoSelectAllowed, this.allowedUserIds});

  bool? isAutoSelectAllowed;
  List<String>? allowedUserIds;
}

/// Maps to `GetPublicKeyCredentialOption`
class SmartAuthPublicKeyOption {
  SmartAuthPublicKeyOption({required this.requestJson, this.clientDataHash});

  String requestJson;
  Uint8List? clientDataHash;
}

/// Maps to `GetCredentialRequest`
class SmartAuthGetCredentialRequest {
  SmartAuthGetCredentialRequest({
    this.passwordOption,
    this.publicKeyOptions,
    this.preferImmediatelyAvailableCredentials,
    this.origin,
  });

  SmartAuthPasswordOption? passwordOption;
  List<SmartAuthPublicKeyOption>? publicKeyOptions;
  bool? preferImmediatelyAvailableCredentials;
  String? origin;
}

/// Maps to `PasswordCredential` and `PublicKeyCredential`
class SmartAuthCredential {
  SmartAuthCredential({
    required this.type,
    this.id,
    this.password,
    this.authenticationResponseJson,
  });

  SmartAuthCredentialType type;
  String? id;
  String? password;
  String? authenticationResponseJson;
}

/// Maps to `CreatePasswordRequest` and `CreatePublicKeyCredentialRequest`
class SmartAuthCreateCredentialRequest {
  SmartAuthCreateCredentialRequest({
    required this.type,
    this.id,
    this.password,
    this.requestJson,
    this.clientDataHash,
    this.isAutoSelectAllowed,
    this.preferImmediatelyAvailableCredentials,
    this.origin,
  });

  SmartAuthCredentialType type;
  String? id;
  String? password;
  String? requestJson;
  Uint8List? clientDataHash;
  bool? isAutoSelectAllowed;
  bool? preferImmediatelyAvailableCredentials;
  String? origin;
}

/// Maps to `CreatePasswordResponse` and `CreatePublicKeyCredentialResponse`
class SmartAuthCreateCredentialResponse {
  SmartAuthCreateCredentialResponse({
    required this.type,
    this.registrationResponseJson,
  });

  SmartAuthCredentialType type;
  String? registrationResponseJson;
}

/// Maps to `PrepareGetCredentialResponse`.
///
/// Android only lets privileged apps (`CREDENTIAL_MANAGER_QUERY_CANDIDATE_CREDENTIALS`)
/// see what credentials are available, for any other app the fields are null.
class SmartAuthPreparedCredential {
  SmartAuthPreparedCredential({
    this.hasPasswordCredentials,
    this.hasPublicKeyCredentials,
    this.hasAuthenticationResults,
    this.hasRemoteResults,
  });

  bool? hasPasswordCredentials;
  bool? hasPublicKeyCredentials;
  bool? hasAuthenticationResults;
  bool? hasRemoteResults;
}

class SmartAuthRequestCanceled {
  const SmartAuthRequestCanceled([this.message]);

  final String? message;
}
