part of 'smart_auth.dart';

class SmsCodeResult {
  final String? sms;
  final String? code;

  bool get codeFound => code != null;
  final bool succeed;

  SmsCodeResult({
    required this.sms,
    required this.code,
    this.succeed = false,
  });

  factory SmsCodeResult.fromSms(String? sms, String matcher) {
    String? _extractCode(String? sms) {
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
        sms: sms, succeed: sms != null, code: _extractCode(sms));
  }

  @override
  String toString() {
    return 'SmsCodeResult{sms: $sms, code: $code, succeed: $succeed}';
  }
}
