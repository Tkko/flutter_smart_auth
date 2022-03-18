#import "SmartAuthPlugin.h"
#if __has_include(<smart_auth/smart_auth-Swift.h>)
#import <smart_auth/smart_auth-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "smart_auth-Swift.h"
#endif

@implementation SmartAuthPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftSmartAuthPlugin registerWithRegistrar:registrar];
}
@end
