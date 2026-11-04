import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smart_auth/smart_auth.dart';

/// Phone number the emulator reports as the SMS sender, see
/// `adb emu sms send`. Used by the SMS tests below.
const _sender = '5551234';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final smartAuth = SmartAuth.instance;

  // The plugin only has an Android implementation.
  final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  group(
    'getAppSignature',
    () {
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
    },
    skip: !isAndroid,
  );

  group(
    'listeners',
    () {
      testWidgets('removeSmsRetrieverApiListener succeeds without a listener', (
        tester,
      ) async {
        final result = await smartAuth.removeSmsRetrieverApiListener();

        expect(result.hasError, isFalse, reason: '${result.error}');
      });

      testWidgets('removeUserConsentApiListener succeeds without a listener', (
        tester,
      ) async {
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
    },
    skip: !isAndroid,
  );

  // The emulator has no credential provider (password manager) set up, so
  // these cover the requests that can be answered without any UI. Showing the
  // account selector and creating passkeys needs a provider and a real person.
  group(
    'Credential Manager',
    () {
      const timeout = Duration(seconds: 30);

      setUp(() async {
        await smartAuth.clearCredentialState();
      });

      testWidgets('clearCredentialState completes', (tester) async {
        final result = await smartAuth.clearCredentialState();

        // Without a credential provider Android fails the request with
        // TYPE_UNKNOWN, e.g. on emulators without Google Password Manager.
        expect(result.isCanceled, isFalse);
        if (result.hasError) {
          expect(result.error, contains('CLEAR_CREDENTIAL_STATE_FAILED'));
        } else {
          expect(result.isSuccess, isTrue);
        }
      });

      testWidgets('getCredential without options fails', (tester) async {
        final result = await smartAuth.getCredential();

        expect(result.hasData, isFalse);
        expect(result.error, contains('INVALID_REQUEST'));
      });

      testWidgets('getCredential finishes when there is nothing to show', (
        tester,
      ) async {
        final result = await smartAuth
            .getCredential(passwordOption: SmartAuthPasswordOption())
            .timeout(timeout);

        // Without a provider the plugin reports NO_CREDENTIAL, with saved
        // credentials the user would pick one.
        expect(
          result.hasData || result.hasError || result.isCanceled,
          isTrue,
        );
        if (result.hasError) {
          expect(result.error, contains('NO_CREDENTIAL'));
        }
      });

      testWidgets('createPasswordCredential finishes without crashing', (
        tester,
      ) async {
        final result = await smartAuth
            .createPasswordCredential(
              id: 'user@example.com',
              password: 'password123',
            )
            .timeout(timeout);

        expect(
          result.hasData || result.hasError || result.isCanceled,
          isTrue,
        );
        if (result.hasError) {
          expect(result.error, contains('CREATE_CREDENTIAL_FAILED'));
        }
      });

      testWidgets('createPublicKeyCredential rejects an invalid request', (
        tester,
      ) async {
        final result = await smartAuth
            .createPublicKeyCredential(requestJson: 'not json')
            .timeout(timeout);

        expect(result.hasData, isFalse);
        expect(result.hasError || result.isCanceled, isTrue);
      });

      testWidgets('getCredential with an invalid passkey request fails', (
        tester,
      ) async {
        final result = await smartAuth
            .getCredential(
              publicKeyOptions: [
                SmartAuthPublicKeyOption(requestJson: 'not json'),
              ],
            )
            .timeout(timeout);

        expect(result.hasData, isFalse);
      });

      testWidgets('getPreparedCredential needs prepareGetCredential first', (
        tester,
      ) async {
        final result = await smartAuth.getPreparedCredential();

        expect(result.hasData, isFalse);
        expect(result.hasError, isTrue);
      });

      testWidgets('getPreparedCredential uses the last prepareGetCredential', (
        tester,
      ) async {
        final prepared = await smartAuth
            .prepareGetCredential(passwordOption: SmartAuthPasswordOption())
            .timeout(timeout);
        if (prepared.hasError) {
          // Below Android 14 there is nothing to prepare.
          expect(prepared.error, contains('UNSUPPORTED'));
          return;
        }

        final result = await smartAuth.getPreparedCredential().timeout(timeout);

        // Without a provider nothing is found, with saved credentials the
        // user would pick one.
        expect(
          result.hasData || result.hasError || result.isCanceled,
          isTrue,
        );
        if (result.hasError) {
          expect(result.error, contains('NO_CREDENTIAL'));
        }
      });

      testWidgets('clearCredentialState drops the prepared credential', (
        tester,
      ) async {
        final prepared = await smartAuth
            .prepareGetCredential(passwordOption: SmartAuthPasswordOption())
            .timeout(timeout);
        if (prepared.hasError) {
          // Below Android 14 there is nothing to prepare.
          expect(prepared.error, contains('UNSUPPORTED'));
          return;
        }

        await smartAuth.clearCredentialState();
        final result = await smartAuth.getPreparedCredential();

        expect(result.hasData, isFalse);
        expect(result.error, contains('NO_PREPARED_CREDENTIAL'));
      });

      testWidgets(
        'prepareGetCredential does not fail with a SecurityException',
        (tester) async {
          final result = await smartAuth
              .prepareGetCredential(passwordOption: SmartAuthPasswordOption())
              .timeout(timeout);

          // Below Android 14 it reports UNSUPPORTED. From Android 14 it
          // succeeds, the has* fields are null because only privileged apps may
          // query them.
          if (result.hasError) {
            expect(result.error, contains('UNSUPPORTED'));
          } else {
            expect(result.hasData, isTrue, reason: '${result.error}');
          }
        },
      );
    },
    skip: !isAndroid,
  );

  // These need an SMS sent from outside the app, so they only run when
  // started through `integration_test/run_sms_tests.sh`.
  final smsTests = isAndroid && const bool.fromEnvironment('SMS_TESTS');

  // Needs the hint dialog to be dismissed from outside the app, see
  // `integration_test/run_sms_tests.sh`.
  final hintTests = isAndroid && const bool.fromEnvironment('HINT_TESTS');

  group('Phone Number Hint', () {
    testWidgets(
      'is reported as canceled when the user dismisses the dialog',
      (tester) async {
        // ignore: avoid_print for testing
        print('HINT_READY');
        final result = await smartAuth.requestPhoneNumberHint().timeout(
          const Duration(seconds: 60),
        );

        expect(result.hasData, isFalse);
        // Without a SIM or Google account the dialog can't be shown at all.
        expect(result.isCanceled || result.hasError, isTrue);
      },
      skip: !hintTests,
    );
  });

  group('SMS Retriever API', () {
    testWidgets(
      'receives a message containing the app signature',
      (tester) async {
        final signature = (await smartAuth.getAppSignature()).requireData;
        // ignore: avoid_print for testing
        print('SMS_SIGNATURE=$signature');

        final result = await smartAuth.getSmsWithRetrieverApi().timeout(
          const Duration(seconds: 60),
        );

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
