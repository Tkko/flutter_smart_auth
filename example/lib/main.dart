import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:smart_auth/smart_auth.dart';

void main() {
  runApp(const MyApp());
}

/// This example demonstrates how to use the SmartAuth plugin.
class MyApp extends StatefulWidget {
  /// Creates a new instance of the [MyApp] class.
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final smartAuth = SmartAuth.instance;
  final pinputController = TextEditingController();
  String? appSignature;

  @override
  void dispose() {
    /// Removes the listeners if the SMS code is not received yet
    unawaited(smartAuth.removeSmsRetrieverApiListener());

    /// Removes the listeners if the SMS code is not received yet
    unawaited(smartAuth.removeUserConsentApiListener());

    pinputController.dispose();
    super.dispose();
  }

  Future<void> getAppSignature() async {
    final res = await smartAuth.getAppSignature();
    setState(() => appSignature = res.data);
    debugPrint('Signature: $res');
  }

  Future<void> userConsent() async {
    final res = await smartAuth.getSmsWithUserConsentApi();
    if (res.hasData) {
      debugPrint('userConsent: $res');
      final code = res.requireData.code;

      /// The code can be null if the SMS was received but
      /// the code was not extracted from it
      if (code == null) return;
      pinputController.text = code;
      pinputController.selection = TextSelection.fromPosition(
        TextPosition(offset: pinputController.text.length),
      );
    } else if (res.isCanceled) {
      debugPrint('userConsent canceled');
    } else {
      debugPrint('userConsent failed: $res');
    }
  }

  Future<void> smsRetriever() async {
    final res = await smartAuth.getSmsWithRetrieverApi();
    if (res.hasData) {
      debugPrint('smsRetriever: $res');
      final code = res.requireData.code;

      /// The code can be null if the SMS was received but
      /// the code was not extracted from it
      if (code == null) return;
      pinputController.text = code;
      pinputController.selection = TextSelection.fromPosition(
        TextPosition(offset: pinputController.text.length),
      );
    } else {
      debugPrint('smsRetriever failed: $res');
    }
  }

  Future<void> requestPhoneNumberHint() async {
    final res = await smartAuth.requestPhoneNumberHint();
    if (res.hasData) {
      // Use the phone number
    } else {
      // Handle error
    }
    debugPrint('requestHint: $res');
  }

  Future<void> getCredential() async {
    final res = await smartAuth.getCredential(
      passwordOption: SmartAuthPasswordOption(),
    );
    // Never log `res.data`, it contains the password.
    debugPrint('getCredential: ${res.state} ${res.error ?? ''}');
  }

  Future<void> createPasswordCredential() async {
    final res = await smartAuth.createPasswordCredential(
      id: 'user@example.com',
      password: 'password123',
    );
    debugPrint('createPasswordCredential: ${res.state} ${res.error ?? ''}');
  }

  Future<void> prepareAndGetCredential() async {
    final prepared = await smartAuth.prepareGetCredential(
      passwordOption: SmartAuthPasswordOption(),
    );
    debugPrint(
      'prepareGetCredential: ${prepared.state} ${prepared.error ?? ''}',
    );
    if (!prepared.hasData) return;
    final res = await smartAuth.getPreparedCredential();
    debugPrint('getPreparedCredential: ${res.state} ${res.error ?? ''}');
  }

  Future<void> clearCredentialState() async {
    final res = await smartAuth.clearCredentialState();
    debugPrint('clearCredentialState: ${res.state} ${res.error ?? ''}');
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
      supportedLocales: const [Locale('en', ''), Locale('es', '')],
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
                  padding: const EdgeInsets.all(8),
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
                TextButton(
                  onPressed: getCredential,
                  child: const Text('Get Credential'),
                ),
                TextButton(
                  onPressed: createPasswordCredential,
                  child: const Text('Create Password Credential'),
                ),
                TextButton(
                  onPressed: prepareAndGetCredential,
                  child: const Text('Prepare + Get Credential (Android 14+)'),
                ),
                TextButton(
                  onPressed: clearCredentialState,
                  child: const Text('Clear Credential State'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
