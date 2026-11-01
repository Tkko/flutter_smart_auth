import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smart_auth/smart_auth.dart';

/// Phone number the emulator reports as the SMS sender, see
/// `adb emu sms send`. Used by the SMS tests below.
const _sender = '5551234';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final smartAuth = SmartAuth.instance;

  group('getAppSignature', () {
    testWidgets('returns an 11 character hash', (tester) async {
      final result = await smartAuth.getAppSignature();

      expect(result.hasData, isTrue, reason: '${result.error}');
      expect(result.requireData, hasLength(11));
    });

    testWidgets('is stable between calls', (tester) async {
      final first = await smartAuth.getAppSignature();
      final second = await smartAuth.getAppSignature();

      expect(first.requireData, second.requireData);
    });
  });

  group('listeners', () {
    testWidgets('removeSmsRetrieverApiListener succeeds without a listener',
        (tester) async {
      final result = await smartAuth.removeSmsRetrieverApiListener();

      expect(result.hasError, isFalse, reason: '${result.error}');
    });

    testWidgets('removeUserConsentApiListener succeeds without a listener',
        (tester) async {
      final result = await smartAuth.removeUserConsentApiListener();

      expect(result.hasError, isFalse, reason: '${result.error}');
    });

    testWidgets('listeners can be removed repeatedly', (tester) async {
      for (var i = 0; i < 3; i++) {
        expect(
          (await smartAuth.removeSmsRetrieverApiListener()).hasError,
          isFalse,
        );
        expect(
          (await smartAuth.removeUserConsentApiListener()).hasError,
          isFalse,
        );
      }
    });
  });

  // These need an SMS sent from outside the app, so they only run when
  // started through `integration_test/run_sms_tests.sh`.
  const smsTests = bool.fromEnvironment('SMS_TESTS');

  group('SMS Retriever API', () {
    testWidgets(
      'receives a message containing the app signature',
      (tester) async {
        final signature = (await smartAuth.getAppSignature()).requireData;
        // ignore: avoid_print for testing
        print('SMS_SIGNATURE=$signature');

        final result = await smartAuth
            .getSmsWithRetrieverApi()
            .timeout(const Duration(seconds: 60));

        expect(result.hasData, isTrue, reason: '${result.error}');
        expect(result.requireData.code, '123456');
        expect(result.requireData.sms, contains(signature));
      },
      skip: !smsTests,
    );
  });

  group('SMS User Consent API', () {
    testWidgets(
      'receives a message after the user consents',
      (tester) async {
        // ignore: avoid_print for testing
        print('SMS_CONSENT_READY');
        final result = await smartAuth
            .getSmsWithUserConsentApi(senderPhoneNumber: _sender)
            .timeout(const Duration(seconds: 60));

        expect(result.hasData, isTrue, reason: '${result.error}');
        expect(result.requireData.code, '654321');
      },
      skip: !smsTests,
    );
  });
}
