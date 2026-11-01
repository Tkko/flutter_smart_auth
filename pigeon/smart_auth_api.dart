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
}

class SmartAuthRequestCanceled {
  const SmartAuthRequestCanceled([this.message]);

  final String? message;
}
