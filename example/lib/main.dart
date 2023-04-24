import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:smart_auth/smart_auth.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final smartAuth = SmartAuth();
  final pinputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    getAppSignature();
  }

  @override
  void dispose() {
    smartAuth.removeSmsListener();
    pinputController.dispose();
    super.dispose();
  }

  void getAppSignature() async {
    final res = await smartAuth.getAppSignature();
    debugPrint('Signature: $res');
  }

  void userConsent() async {
    debugPrint('userConsent: ');
    final res = await smartAuth.getSmsCode(useUserConsentApi: true);
    userConsent();
    if (res.codeFound) {
      pinputController.text = res.code!;
      pinputController.selection = TextSelection.fromPosition(
          TextPosition(offset: pinputController.text.length));
    } else {
      debugPrint('userConsent failed: $res');
    }
    debugPrint('userConsent: $res');
  }

  void smsRetriever() async {
    final res = await smartAuth.getSmsCode();
    smsRetriever();
    if (res.codeFound) {
      pinputController.text = res.code!;
      pinputController.selection = TextSelection.fromPosition(
          TextPosition(offset: pinputController.text.length));
    } else {
      debugPrint('smsRetriever failed: $res');
    }
    debugPrint('smsRetriever: $res');
  }

  void requestHint() async {
    final res = await smartAuth.requestHint(
      isPhoneNumberIdentifierSupported: true,
      isEmailAddressIdentifierSupported: true,
      showCancelButton: true,
    );
    debugPrint('requestHint: $res');
  }

  void removeSmsListener() {
    smartAuth.removeSmsListener();
  }

  // identifier Url
  final accountType = 'https://developers.google.com';

  // Value you want to save, phone number or email for example
  final credentialId = 'Credential Id';
  final credentialName = 'Credential Name';
  final profilePictureUri = 'https://profilePictureUri.com';

  void saveCredential() async {
    final res = await smartAuth.saveCredential(
      id: credentialId,
      name: credentialName,
      accountType: accountType,
      profilePictureUri: profilePictureUri,
    );
    debugPrint('saveCredentials: $res');
  }

  void getCredential() async {
    final res = await smartAuth.getCredential(
      accountType: accountType,
      showResolveDialog: true,
    );
    debugPrint('getCredentials: $res');
  }

  void deleteCredential() async {
    final res = await smartAuth.deleteCredential(
      id: credentialId,
      accountType: accountType,
    );
    debugPrint('removeCredentials: $res');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('es', ''),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('es', ''),
      ],
      builder: (_, __) {
        return Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: pinputController,
                  decoration: const InputDecoration(
                    hintText: 'Code',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              TextButton(
                  onPressed: userConsent,
                  child: const Text('Sms User Consent API')),
              TextButton(
                  onPressed: smsRetriever,
                  child: const Text('Sms Retriever API')),
              TextButton(
                  onPressed: requestHint, child: const Text('Request Hint')),
              TextButton(
                  onPressed: getCredential,
                  child: const Text('Get Credential')),
              TextButton(
                  onPressed: saveCredential,
                  child: const Text('Save Credential')),
              TextButton(
                  onPressed: deleteCredential,
                  child: const Text('Delete Credential')),
            ],
          ),
        );
      },
    );
  }
}
