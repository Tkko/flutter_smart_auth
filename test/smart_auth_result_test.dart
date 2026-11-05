import 'package:flutter_test/flutter_test.dart';
import 'package:smart_auth/smart_auth.dart';

void main() {
  group('SmartAuthSms.fromSms', () {
    test('extracts the first 4-8 digit code by default', () {
      final sms = SmartAuthSms.fromSms('Your code is 123456', r'\d{4,8}');

      expect(sms.code, '123456');
      expect(sms.sms, 'Your code is 123456');
    });

    test('returns null code when nothing matches', () {
      final sms = SmartAuthSms.fromSms('Hello there', r'\d{4,8}');

      expect(sms.code, isNull);
    });
  });

  group('SmartAuthResult', () {
    test('success has data', () {
      const result = SmartAuthResult.success('x');

      expect(result.hasData, isTrue);
      expect(result.isSuccess, isTrue);
      expect(result.state, SmartAuthResultState.success);
      expect(result.requireData, 'x');
      expect(result.isCanceled, isFalse);
    });

    test('success with void data succeeds and requireData does not throw', () {
      const result = SmartAuthResult<void>.success(null);

      expect(result.hasData, isFalse);
      expect(result.isSuccess, isTrue);
      expect(result.state, SmartAuthResultState.success);
      expect(result.hasError, isFalse);
      expect(result.isCanceled, isFalse);
      expect(() => result.requireData, returnsNormally);
    });

    test('canceled is reported', () {
      const result = SmartAuthResult<String>.canceled();

      expect(result.isCanceled, isTrue);
      expect(result.hasData, isFalse);
    });

    test('failure has error', () {
      const result = SmartAuthResult<String>.failure('boom');

      expect(result.hasError, isTrue);
      expect(result.error, 'boom');
    });
  });
}
