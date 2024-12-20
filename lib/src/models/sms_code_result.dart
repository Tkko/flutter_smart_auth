import 'package:flutter/foundation.dart';

/// The returned value from [SmartAuth.getSmsWithRetrieverApi] and [SmartAuth.getSmsWithUserConsentApi]
/// Contains the whole sms and the OTP code itself
class SmartAuthSms {
  /// The SMS text received from your OTP sender
  final String sms;

  /// The actual code retrieved from SMS
  /// Can be null if the regex matcher didn't find any code but user received the SMS
  final String? code;

  const SmartAuthSms({
    required this.sms,
    required this.code,
  });

  static SmartAuthSms fromSms(String sms, String matcher) {
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

    return SmartAuthSms(
      sms: sms,
      code: extractCode(sms),
    );
  }

  @override
  String toString() {
    return 'SmartAuthSms{sms: $sms, code: $code}';
  }
}
