import 'package:flutter_test/flutter_test.dart';
import 'package:smart_auth/smart_auth.dart';
import 'package:smart_auth/src/smart_auth_api.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const codec = SmartAuthApi.pigeonChannelCodec;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const prefix = 'dev.flutter.pigeon.smart_auth.SmartAuthApi';

  void mock(String method, Object? Function(List<Object?> args) handler) {
    messenger.setMockMessageHandler('$prefix.$method', (message) async {
      final args = (codec.decodeMessage(message) as List<Object?>?) ?? [];
      return codec.encodeMessage(handler(args));
    });
  }

  tearDown(() {
    for (final method in [
      'getCredential',
      'createCredential',
      'prepareGetCredential',
      'getPreparedCredential',
      'clearCredentialState',
    ]) {
      messenger.setMockMessageHandler('$prefix.$method', null);
    }
  });

  test('getCredential returns the password credential', () async {
    mock('getCredential', (args) {
      final request = args.first! as SmartAuthGetCredentialRequest;
      expect(request.passwordOption, isNotNull);
      return [
        SmartAuthCredential(
          type: SmartAuthCredentialType.password,
          id: 'user',
          password: 'secret',
        ),
      ];
    });

    final result = await SmartAuth.instance.getCredential(
      passwordOption: SmartAuthPasswordOption(),
    );

    expect(result.requireData.id, 'user');
    expect(result.requireData.password, 'secret');
  });

  test('createPasswordCredential sends id and password', () async {
    mock('createCredential', (args) {
      final request = args.first! as SmartAuthCreateCredentialRequest;
      expect(request.type, SmartAuthCredentialType.password);
      expect(request.id, 'user');
      expect(request.password, 'secret');
      return [
        SmartAuthCreateCredentialResponse(
          type: SmartAuthCredentialType.password,
        ),
      ];
    });

    final result = await SmartAuth.instance.createPasswordCredential(
      id: 'user',
      password: 'secret',
    );

    expect(result.hasData, isTrue);
  });

  test('prepareGetCredential and getPreparedCredential', () async {
    mock(
      'prepareGetCredential',
      (_) => [SmartAuthPreparedCredential(hasPasswordCredentials: true)],
    );
    mock(
      'getPreparedCredential',
      (_) => [SmartAuthCredential(type: SmartAuthCredentialType.publicKey)],
    );

    final prepared = await SmartAuth.instance.prepareGetCredential(
      passwordOption: SmartAuthPasswordOption(),
    );
    final credential = await SmartAuth.instance.getPreparedCredential();

    expect(prepared.requireData.hasPasswordCredentials, isTrue);
    expect(credential.requireData.type, SmartAuthCredentialType.publicKey);
  });

  test('cancellation is reported as canceled', () async {
    messenger.setMockMessageHandler('$prefix.getCredential', (_) async {
      return codec.encodeMessage(<Object?>[
        'GET_CREDENTIAL_CANCELED',
        'canceled',
        SmartAuthRequestCanceled(),
      ]);
    });

    final result = await SmartAuth.instance.getCredential(
      passwordOption: SmartAuthPasswordOption(),
    );

    expect(result.isCanceled, isTrue);
  });

  test('failures are reported as errors', () async {
    messenger.setMockMessageHandler('$prefix.clearCredentialState', (_) async {
      return codec.encodeMessage(<Object?>['FAILED', 'boom', null]);
    });

    final result = await SmartAuth.instance.clearCredentialState();

    expect(result.hasError, isTrue);
    expect(result.isCanceled, isFalse);
  });
}
