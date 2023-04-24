part of 'smart_auth.dart';

/// The returned value from [SmartAuth.getSmsCode]
/// Contains the whole sms and the OTP code itself
class SmsCodeResult {
  /// The SMS text received from your OTP sender
  final String? sms;

  /// The actual code retrieved from SMS
  final String? code;

  /// Returns true if OTP code was found in the SMS content
  bool get codeFound => code != null;

  /// Returns true sms content != null
  final bool succeed;

  SmsCodeResult({
    required this.sms,
    required this.code,
    this.succeed = false,
  });

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
      succeed: sms != null,
      code: extractCode(sms),
    );
  }

  @override
  String toString() {
    return 'SmsCodeResult{sms: $sms, code: $code, succeed: $succeed}';
  }
}
