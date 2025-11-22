import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_mobile/identity_manager.dart';

void main() {
  const MethodChannel channel = MethodChannel('nexus.secure_storage');

  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    channel.setMockMethodCallHandler(null);
  });

  test('registerAccount returns false when metadata already exists', () async {
    // Mock getMetadata to return an existing metadata JSON string
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'getMetadata') {
        return jsonEncode({
          'salt': base64Encode(List<int>.filled(16, 1)),
          'login_count': 0,
        });
      }
      // default responses
      if (methodCall.method == 'storeIdentity') return true;
      if (methodCall.method == 'storeIdentityBiometric') return true;
      if (methodCall.method == 'storeMetadata') return true;
      return null;
    });

    final res = await IdentityManager.registerAccount('password123', birthDate: DateTime.now().subtract(const Duration(days: 365 * 20)));
    expect(res, isFalse);
  });
}
