/// Flutter package for listening SMS code on Android, suggesting phone number, email, saving a credential.

library;

export 'src/models/sms_code_result.dart';
export 'src/models/smart_auth_result.dart';
export 'src/smart_auth.dart';
export 'src/smart_auth_api.g.dart'
    show
        SmartAuthCreateCredentialResponse,
        SmartAuthCredential,
        SmartAuthCredentialType,
        SmartAuthPasswordOption,
        SmartAuthPreparedCredential,
        SmartAuthPublicKeyOption,
        SmartAuthRequestCanceled;
