import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/platform_secure_storage.dart';

void main() {
  const channel = MethodChannel('nexus.secure_storage');

  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    ServicesBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('storeIdentity and wipeDevice mock', () async {
    ServicesBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'storeIdentity') return true;
      if (methodCall.method == 'storeIdentityBiometric') return true;
      if (methodCall.method == 'wipeDevice') return true;
      return false;
    });

    final ok = await PlatformSecureStorage.storeIdentityWithBiometrics(Uint8List.fromList([1,2,3]));
    expect(ok, isTrue);

    final wiped = await PlatformSecureStorage.wipeDevice();
    expect(wiped, isTrue);
  });
}
