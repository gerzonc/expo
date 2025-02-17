// Copyright 2022-present 650 Industries. All rights reserved.

#import <ABI45_0_0ExpoModulesCore/ABI45_0_0ExpoModulesHostObject.h>
#import <ABI45_0_0ExpoModulesCore/ABI45_0_0EXJavaScriptObject.h>
#import <ABI45_0_0ExpoModulesCore/Swift.h>

namespace ABI45_0_0expo {

ExpoModulesHostObject::ExpoModulesHostObject(SwiftInteropBridge *swiftInterop) : swiftInterop(swiftInterop) {}

ExpoModulesHostObject::~ExpoModulesHostObject() {
  [swiftInterop setRuntime:nil];
}

jsi::Value ExpoModulesHostObject::get(jsi::Runtime &runtime, const jsi::PropNameID &name) {
  NSString *moduleName = [NSString stringWithUTF8String:name.utf8(runtime).c_str()];
  ABI45_0_0EXJavaScriptObject *nativeObject = [swiftInterop getNativeModuleObject:moduleName];

  return nativeObject ? jsi::Value(runtime, *[nativeObject get]) : jsi::Value::undefined();
}

void ExpoModulesHostObject::set(jsi::Runtime &runtime, const jsi::PropNameID &name, const jsi::Value &value) {
  std::string message("RuntimeError: Cannot override the host object for expo module '");
  message += name.utf8(runtime);
  message += "'.";
  throw jsi::JSError(runtime, message);
}

std::vector<jsi::PropNameID> ExpoModulesHostObject::getPropertyNames(jsi::Runtime &runtime) {
  NSArray<NSString *> *moduleNames = [swiftInterop getModuleNames];
  std::vector<jsi::PropNameID> propertyNames;

  propertyNames.reserve([moduleNames count]);

  for (NSString *moduleName in moduleNames) {
    propertyNames.push_back(jsi::PropNameID::forAscii(runtime, [moduleName UTF8String]));
  }
  return propertyNames;
}

} // namespace ABI45_0_0expo
