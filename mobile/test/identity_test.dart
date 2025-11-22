import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import '../lib/identity_manager.dart';

void main() {
  test('exportEncryptedBlob returns non-empty blob', () async {
    final blob = await IdentityManager.exportEncryptedBlob();
    expect(blob, isNotNull);
    expect(blob.length, greaterThan(0));
    final s = utf8.decode(blob);
    expect(s.contains('ENCRYPTED_PLACEHOLDER'), isTrue);
  });
}
