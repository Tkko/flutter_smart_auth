part of '../smart_auth.dart';

/// The result of the SmartAuth methods
class SmartAuthResult<T> {
  const SmartAuthResult({
    required this.succeed,
    required this.canceled,
    required this.exception,
    required this.data,
  });

  const SmartAuthResult.success(this.data)
      : succeed = true,
        canceled = false,
        exception = null;

  const SmartAuthResult.failure(this.exception)
      : succeed = false,
        canceled = false,
        data = null;

  const SmartAuthResult.canceled(this.exception)
      : succeed = false,
        canceled = true,
        data = null;

  final bool succeed;
  final bool canceled;
  final String? exception;
  final T? data;

  @override
  String toString() {
    return 'SmartAuthResult{succeed: $succeed, canceled: $canceled, data: $data, exception: $exception, }';
  }
}

/// The returned value from [SmartAuth.getSmsCode]
/// Contains the whole sms and the OTP code itself
class SmsCodeResult extends SmartAuthResult<String> {
  /// The SMS text received from your OTP sender
  final String? sms;

  /// The actual code retrieved from SMS
  final String? code;

  /// Returns true if OTP code was found in the SMS content
  bool get codeFound => code != null;

  const SmsCodeResult({
    this.sms,
    this.code,
    bool canceled = false,
  }) : super(
          succeed: sms != null,
          canceled: canceled,
          exception: null,
          data: null,
        );

  factory SmsCodeResult.fromSms(String? sms, String matcher) {
    String? extractCode(String? sms) {
      if (sms == null) return null;

      try {
        final intRegex = RegExp(matcher, multiLine: true);
        final allMatches = intRegex.allMatches(sms);
        if (allMatches.isNotEmpty) {
          allMatches.first.group(0);
          return intRegex.allMatches(sms).first.group(0);
        }
      } catch (e) {
        debugPrint('$e');
        return null;
      }
      return null;
    }

    return SmsCodeResult(
      sms: sms,
      code: extractCode(sms),
    );
  }

  @override
  String toString() {
    return 'SmsCodeResult{sms: $sms, code: $code, succeed: $succeed}';
  }
}
