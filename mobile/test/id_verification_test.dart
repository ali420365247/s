import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_mobile/identity_manager.dart';

void main() {
  test('ID number format validation', () {
    expect(IdentityManager.isValidIdNumber('ABC123'), isTrue);
    expect(IdentityManager.isValidIdNumber('abc123'), isTrue);
    expect(IdentityManager.isValidIdNumber('123'), isFalse);
    expect(IdentityManager.isValidIdNumber('TOO-LONG-ID-12345'), isFalse);
    expect(IdentityManager.isValidIdNumber('A1B2C3D4'), isTrue);
  });

  test('ID photo and live photo exact match succeeds', () async {
    final a = Uint8List.fromList([1, 2, 3, 4, 5]);
    final b = Uint8List.fromList([1, 2, 3, 4, 5]);
    final ok = await IdentityManager.verifyId('ABC123', a, b);
    expect(ok, isTrue);
  });

  test('ID photo and live photo different fails', () async {
    final a = Uint8List.fromList([1, 2, 3, 4, 5]);
    final b = Uint8List.fromList([9, 8, 7, 6, 5]);
    final ok = await IdentityManager.verifyId('ABC123', a, b);
    expect(ok, isFalse);
  });

  test('Invalid ID number fails verification even if photos match', () async {
    final a = Uint8List.fromList([1, 2, 3]);
    final b = Uint8List.fromList([1, 2, 3]);
    final ok = await IdentityManager.verifyId('123', a, b);
    expect(ok, isFalse);
  });
}
