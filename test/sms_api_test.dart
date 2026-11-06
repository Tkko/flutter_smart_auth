import 'package:flutter_test/flutter_test.dart';
import 'package:smart_auth/smart_auth.dart';
import 'package:smart_auth/src/smart_auth_api.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const codec = SmartAuthApi.pigeonChannelCodec;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const prefix = 'dev.flutter.pigeon.smart_auth.SmartAuthApi';
  const methods = [
    'getAppSignature',
    'getSmsWithRetrieverApi',
    'getSmsWithUserConsentApi',
    'removeSmsRetrieverListener',
    'removeUserConsentListener',
    'requestPhoneNumberHint',
  ];

  void reply(String method, Object? value) {
    messenger.setMockMessageHandler('$prefix.$method', (_) async {
      return codec.encodeMessage(<Object?>[value]);
    });
  }

  void fail(String method, String code, {Object? details}) {
    messenger.setMockMessageHandler('$prefix.$method', (_) async {
      return codec.encodeMessage(<Object?>[code, 'message', details]);
    });
  }

  tearDown(() {
    for (final method in methods) {
      messenger.setMockMessageHandler('$prefix.$method', null);
    }
  });

  group('getSmsWithRetrieverApi', () {
    test('extracts the code with the default matcher', () async {
      reply('getSmsWithRetrieverApi', 'Your code is 123456');

      final result = await SmartAuth.instance.getSmsWithRetrieverApi();

      expect(result.requireData.code, '123456');
    });

    test('extracts the code with a custom matcher', () async {
      reply('getSmsWithRetrieverApi', 'Code AB-12 expires in 123456 seconds');

      final result = await SmartAuth.instance.getSmsWithRetrieverApi(
        matcher: r'[A-Z]{2}-\d{2}',
      );

      expect(result.requireData.code, 'AB-12');
    });

    test('keeps the SMS when the matcher finds nothing', () async {
      reply('getSmsWithRetrieverApi', 'No digits here');

      final result = await SmartAuth.instance.getSmsWithRetrieverApi();

      expect(result.requireData.sms, 'No digits here');
      expect(result.requireData.code, isNull);
    });

    test('keeps the SMS when the matcher is an invalid regex', () async {
      reply('getSmsWithRetrieverApi', 'Your code is 123456');

      final result = await SmartAuth.instance.getSmsWithRetrieverApi(
        matcher: '(',
      );

      expect(result.requireData.sms, 'Your code is 123456');
      expect(result.requireData.code, isNull);
    });

    test('cancellation is reported as canceled', () async {
      fail(
        'getSmsWithRetrieverApi',
        'SMS_REQUEST_CANCELED',
        details: SmartAuthRequestCanceled(),
      );

      final result = await SmartAuth.instance.getSmsWithRetrieverApi();

      expect(result.isCanceled, isTrue);
      expect(result.hasError, isFalse);
    });

    test('failures are reported as errors', () async {
      fail('getSmsWithRetrieverApi', 'FAILED');

      final result = await SmartAuth.instance.getSmsWithRetrieverApi();

      expect(result.hasError, isTrue);
      expect(result.isCanceled, isFalse);
    });
  });

  group('getSmsWithUserConsentApi', () {
    test('sends the sender phone number', () async {
      Object? sender;
      messenger.setMockMessageHandler('$prefix.getSmsWithUserConsentApi', (
        message,
      ) async {
        sender = (codec.decodeMessage(message) as List<Object?>).first;
        return codec.encodeMessage(<Object?>['Your code is 123456']);
      });

      final result = await SmartAuth.instance.getSmsWithUserConsentApi(
        senderPhoneNumber: '5551234',
      );

      expect(sender, '5551234');
      expect(result.requireData.code, '123456');
    });

    test('cancellation is reported as canceled', () async {
      fail(
        'getSmsWithUserConsentApi',
        'USER_CONSENT_CANCELED',
        details: SmartAuthRequestCanceled(),
      );

      final result = await SmartAuth.instance.getSmsWithUserConsentApi();

      expect(result.isCanceled, isTrue);
      expect(result.hasError, isFalse);
    });

    test('failures are reported as errors', () async {
      fail('getSmsWithUserConsentApi', 'FAILED');

      final result = await SmartAuth.instance.getSmsWithUserConsentApi();

      expect(result.hasError, isTrue);
      expect(result.isCanceled, isFalse);
    });
  });

  group('requestPhoneNumberHint', () {
    test('returns the phone number', () async {
      reply('requestPhoneNumberHint', '+15551234');

      final result = await SmartAuth.instance.requestPhoneNumberHint();

      expect(result.requireData, '+15551234');
    });

    test('cancellation is reported as canceled', () async {
      fail(
        'requestPhoneNumberHint',
        'PHONE_NUMBER_HINT_CANCELED',
        details: SmartAuthRequestCanceled(),
      );

      final result = await SmartAuth.instance.requestPhoneNumberHint();

      expect(result.isCanceled, isTrue);
      expect(result.hasError, isFalse);
    });

    test('failures are reported as errors', () async {
      fail('requestPhoneNumberHint', 'PHONE_NUMBER_HINT_FAILED');

      final result = await SmartAuth.instance.requestPhoneNumberHint();

      expect(result.hasError, isTrue);
      expect(result.isCanceled, isFalse);
    });
  });

  // Other platforms have no native side, the calls must not throw there.
  group('without a native implementation', () {
    test('every call reports an error', () async {
      final auth = SmartAuth.instance;

      expect((await auth.getAppSignature()).hasError, isTrue);
      expect((await auth.getSmsWithRetrieverApi()).hasError, isTrue);
      expect((await auth.getSmsWithUserConsentApi()).hasError, isTrue);
      expect((await auth.removeSmsRetrieverApiListener()).hasError, isTrue);
      expect((await auth.removeUserConsentApiListener()).hasError, isTrue);
      expect((await auth.requestPhoneNumberHint()).hasError, isTrue);
    });
  });
}
