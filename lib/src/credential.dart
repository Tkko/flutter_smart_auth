part of 'smart_auth.dart';

/// A credential that can be used to authenticate a user,
/// with additional user information used to distinguish this credential from other available credentials.
/// Credentials can be constructed using Credential.Builder.
/// This is typically required when a credential is to be saved using [SmartAuth.saveCredential]
/// for future retrieval after a new account is created, or the user changes their password.
/// More about Credential https://developers.google.com/android/reference/com/google/android/gms/auth/api/credentials/Credential?hl=en
class Credential {
  /// Returns the type of federated identity account used to sign in the user.
  final String? accountType;

  /// Returns the credential identifier.
  final String id;

  /// Returns the display name of the credential, if available.
  final String? name;

  /// Returns the password used to sign in the user.
  final String? password;

  /// Returns the URL to an image of the user, if available.
  final String? profilePictureUri;
  final String? familyName;
  final String? givenName;

  Credential({
    required this.id,
    this.accountType,
    this.familyName,
    this.givenName,
    this.name,
    this.password,
    this.profilePictureUri,
  });

  Map<String, dynamic> toJson() => {
        'accountType': accountType,
        'id': id,
        'familyName': familyName,
        'givenName': givenName,
        'name': name,
        'password': password,
        'profilePictureUri': profilePictureUri,
      };

  factory Credential.fromJson(Map<String, dynamic> map) {
    return Credential(
      accountType: map['accountType'] as String?,
      id: map['id'] as String,
      familyName: map['familyName'] as String?,
      givenName: map['givenName'] as String?,
      name: map['name'] as String?,
      password: map['password'] as String?,
      profilePictureUri: map['profilePictureUri'] as String?,
    );
  }

  @override
  String toString() => toJson().toString();
}
