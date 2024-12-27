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
  final smartAuth = SmartAuth.instance;
  final pinputController = TextEditingController();
  String? appSignature;

  @override
  void dispose() {
    smartAuth.removeSmsRetrieverApiListener();
    smartAuth.removeUserConsentApiListener();
    pinputController.dispose();
    super.dispose();
  }

  void getAppSignature() async {
    final res = await smartAuth.getAppSignature();
    setState(() => appSignature = res.data);
    debugPrint('Signature: $res');
  }

  void userConsent() async {
    final res = await smartAuth.getSmsWithUserConsentApi();
    if (res.hasData) {
      debugPrint('userConsent: $res');
      final code = res.requireData.code;

      /// The code can be null if the SMS is received but the code is extracted from it
      if (code == null) return;
      pinputController.text = code;
      pinputController.selection = TextSelection.fromPosition(
        TextPosition(offset: pinputController.text.length),
      );
    } else if (res.state.isCanceled) {
      debugPrint('userConsent canceled');
    } else {
      debugPrint('userConsent failed: $res');
    }
  }

  void smsRetriever() async {
    final res = await smartAuth.getSmsWithRetrieverApi();
    if (res.hasData) {
      debugPrint('smsRetriever: $res');
      final code = res.requireData.code;

      /// The code can be null if the SMS is received but the code is extracted from it
      if (code == null) return;
      pinputController.text = code;
      pinputController.selection = TextSelection.fromPosition(
        TextPosition(offset: pinputController.text.length),
      );
    } else {
      debugPrint('smsRetriever failed: $res');
    }
  }

  void requestPhoneNumberHint() async {
    final res = await smartAuth.requestPhoneNumberHint();
    if (res.hasData) {
      // Use the phone number
    } else {
      // Handle error
    }
    debugPrint('requestHint: $res');
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
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
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
                  child: const Text('Sms User Consent API'),
                ),
                TextButton(
                  onPressed: smsRetriever,
                  child: const Text('Sms Retriever API'),
                ),
                TextButton(
                  onPressed: getAppSignature,
                  child: const Text('Get App Signature'),
                ),
                if (appSignature != null)
                  SelectableText(
                    'App Signature: $appSignature',
                    textAlign: TextAlign.center,
                  ),
                TextButton(
                  onPressed: requestPhoneNumberHint,
                  child: const Text('Request Phone Number Hint'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
