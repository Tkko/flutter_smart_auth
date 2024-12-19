import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/smart_auth_api.g.dart',
    kotlinOptions: KotlinOptions(package: 'fman.ge.smart_auth'),
    kotlinOut: 'android/src/main/kotlin/fman/ge/smart_auth/smart_auth_api.g.kt',
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
