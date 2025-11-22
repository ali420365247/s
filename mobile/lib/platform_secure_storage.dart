import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'dart:convert';

class PlatformSecureStorage {
  static const MethodChannel _channel = MethodChannel('nexus.secure_storage');

  /// Store encrypted identity blob in platform secure storage (non-exportable)
  static Future<bool> storeIdentity(Uint8List blob) async {
    try {
      final res = await _channel.invokeMethod('storeIdentity', {'blob': blob});
      return res == true;
    } on PlatformException {
      return false;
    }
  }

  /// Store encrypted identity blob with biometric protection (preferred)
  static Future<bool> storeIdentityWithBiometrics(Uint8List blob) async {
    try {
      final res = await _channel.invokeMethod('storeIdentityBiometric', {'blob': blob});
      return res == true;
    } on PlatformException {
      return false;
    }
  }

  /// Import an identity blob previously exported
  static Future<bool> importIdentity(Uint8List blob) async {
    try {
      final res = await _channel.invokeMethod('importIdentity', {'blob': blob});
      return res == true;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> importIdentityWithBiometrics(Uint8List blob) async {
    try {
      final res = await _channel.invokeMethod('importIdentityBiometric', {'blob': blob});
      return res == true;
    } on PlatformException {
      return false;
    }
  }

  /// Retrieve stored identity blob with biometric prompt (returns null on failure)
  static Future<Uint8List?> getIdentityWithBiometrics() async {
    try {
      final res = await _channel.invokeMethod('getIdentityBiometric');
      if (res == null) return null;
      if (res is Uint8List) return res;
      if (res is List<int>) return Uint8List.fromList(res)
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Retrieve stored identity blob without biometric (if stored non-biometrically)
  static Future<Uint8List?> getIdentity() async {
    try {
      final res = await _channel.invokeMethod('getIdentity');
      if (res == null) return null;
      if (res is Uint8List) return res;
      if (res is List<int>) return Uint8List.fromList(res)
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Store arbitrary metadata (JSON-serializable map) in secure app storage
  static Future<bool> storeMetadata(Map<String, dynamic> json) async {
    try {
      // Convert to JSON string to ensure cross-platform compatibility
      final encoded = jsonEncode(json);
      final res = await _channel.invokeMethod('storeMetadata', {'json': encoded});
      return res == true;
    } on PlatformException {
      return false;
    }
  }

  /// Retrieve previously stored metadata (returns null if not found)
  static Future<Map<String, dynamic>?> getMetadata() async {
    try {
      final res = await _channel.invokeMethod('getMetadata');
      if (res == null) return null;
      if (res is String) {
        return Map<String, dynamic>.from(jsonDecode(res));
      }
      if (res is Map) return Map<String, dynamic>.from(res as Map);
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Wipe keys/identity from the device
  static Future<bool> wipeDevice() async {
    try {
      final res = await _channel.invokeMethod('wipeDevice');
      return res == true;
    } on PlatformException {
      return false;
    }
  }
}
