import 'dart:convert';
import 'dart:typed_data';
import 'platform_secure_storage.dart';
import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart';
import 'dart:math';
import 'dart:convert';
  // --- CRYPTO KEYPAIR FOR SIGNING ---
  static final _algo = Ed25519();

  /// Generate and store a signing keypair in metadata if not present
  static Future<SimpleKeyPair> getOrCreateSigningKey() async {
    final meta = await PlatformSecureStorage.getMetadata() ?? {};
    if (meta.containsKey('signing_private')) {
      final priv = base64Decode(meta['signing_private'] as String);
      return _algo.newKeyPairFromSeed(priv);
    }
    // Generate new keypair
    final keypair = await _algo.newKeyPair();
    final priv = await keypair.extractPrivateKeyBytes();
    final pub = await keypair.extractPublicKeyBytes();
    meta['signing_private'] = base64Encode(priv);
    meta['signing_public'] = base64Encode(pub);
    await PlatformSecureStorage.storeMetadata(meta);
    return keypair;
  }

  /// Get public key (base64) from metadata
  static Future<String?> getSigningPublicKey() async {
    final meta = await PlatformSecureStorage.getMetadata();
    if (meta != null && meta.containsKey('signing_public')) {
      return meta['signing_public'] as String;
    }
    return null;
  }

  /// Sign a message (Uint8List) with local key
  static Future<Uint8List> signMessage(Uint8List message) async {
    final keypair = await getOrCreateSigningKey();
    final sig = await _algo.sign(message, keyPair: keypair);
    return Uint8List.fromList(sig.bytes);
  }

  /// Verify a signature given message and base64 public key
  static Future<bool> verifySignature(Uint8List message, Uint8List signature, String base64Pub) async {
    final pub = SimplePublicKey(base64Decode(base64Pub), type: KeyPairType.ed25519);
    return await _algo.verify(message, signature: Signature(signature, publicKey: pub));
  }

/// IdentityManager stub
/// In a real implementation this will export the encrypted identity blob
/// (private keys + minimal metadata) in a secure, versioned format.
class IdentityManager {
  /// Export an encrypted blob representing the user's identity.
  /// For now returns a small example Uint8List.
  static Future<Uint8List> exportEncryptedBlob() async {
    // In real app, gather: encrypted private keys (secure-enclave), metadata,
    // and encrypt with a short-lived passphrase / session key.
    final json = jsonEncode({
      'v': 1,
      'id': 'placeholder-index-id',
      'keys': 'ENCRYPTED_PLACEHOLDER',
    });
    return Uint8List.fromList(utf8.encode(json));
  }

  /// Import the blob on the new phone and (optionally) wipe the old device by
  /// instructing it to erase its keys using its local key material & policy.
  static Future<void> importAndWipeOld(Uint8List blob) async {
    // Validate and persist blob to secure storage (Keystore / Secure Enclave)
    final decoded = utf8.decode(blob);
    // TODO: decrypt and validate structure
    // Persist keys securely here (platform-specific code required)

    // Real implementation: store blob in secure storage protected by biometrics
    // Attempt to store with biometric protection first, fall back to plain store.
    try {
      final stored = await PlatformSecureStorage.storeIdentityWithBiometrics(blob);
      if (!stored) {
        await PlatformSecureStorage.storeIdentity(blob);
      }
    } catch (_) {
      await PlatformSecureStorage.storeIdentity(blob);
    }
    return;
  }

  /// Load stored identity (prefer biometric-protected retrieval)
  static Future<Uint8List?> loadStoredIdentity() async {
    try {
      final bio = await PlatformSecureStorage.getIdentityWithBiometrics();
      if (bio != null) return bio;
      final plain = await PlatformSecureStorage.getIdentity();
      return plain;
    } catch (_) {
      return null;
    }
  }

  /// Register an account on this device: derive a key from `password`, encrypt
  /// the exported identity blob, store it (both biometric and non-biometric),
  /// and store metadata (salt + login_count).
  static Future<bool> registerAccount(String password, {DateTime? birthDate}) async {
    // Require birth date and enforce 18+ age restriction
    if (birthDate == null) {
      return false;
    }
    final now = DateTime.now();
    // Compute exact age by subtracting DOB from current time and comparing
    // to an 18-year duration (approximate using average year length).
    final ageDuration = now.difference(birthDate);
    final daysPerYear = 365.2425; // average including leap years
    final required18 = Duration(days: (daysPerYear * 18).floor());
    if (ageDuration < required18) {
      return false;
    }

    // Prevent re-registration if metadata already exists (one-account-per-device)
    final existing = await PlatformSecureStorage.getMetadata();
    if (existing != null) {
      // Account already registered on this device
      return false;
    }

    final blob = await exportEncryptedBlob();
    final rng = Random.secure();
    final salt = List<int>.generate(16, (_) => rng.nextInt(256));

    final pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 100000, bits: 256);
    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    final algorithm = AesGcm.with256bits();
    final nonce = Nonce(List<int>.generate(12, (_) => rng.nextInt(256)));
    final encrypted = await algorithm.encrypt(blob, secretKey: secretKey, nonce: nonce);
    // Store bytes: iv + cipher
    final out = <int>[];
    out.addAll(nonce.bytes);
    out.addAll(encrypted.cipherText);
    final encBytes = Uint8List.fromList(out);

    final stored = await PlatformSecureStorage.storeIdentity(encBytes);
    final storedBio = await PlatformSecureStorage.storeIdentityWithBiometrics(encBytes);

    final meta = {
      'salt': base64Encode(salt),
      'login_count': 0,
      'created_at': DateTime.now().toIso8601String(),
      'dob': birthDate.toIso8601String(),
      'age_verified': true,
    };
    await PlatformSecureStorage.storeMetadata(meta);
    return stored || storedBio;
  }

  /// Validate an ID number format. Simple alphanumeric (6-12 chars) check.
  static bool isValidIdNumber(String idNumber) {
    final reg = RegExp(r'^[A-Z0-9]{6,12}\$', caseSensitive: false);
    return reg.hasMatch(idNumber);
  }

  /// Verify ID by checking ID number format and comparing ID photo vs live photo.
  /// This is a placeholder: photo comparison is done by exact byte equality
  /// (in real app, replace with a proper face-matching library or ML model).
  static Future<bool> verifyId(String idNumber, Uint8List idPhoto, Uint8List livePhoto) async {
    if (!isValidIdNumber(idNumber)) return false;
    return verifyIdMatch(idPhoto, livePhoto);
  }

  /// Placeholder photo matcher: returns true if the two byte arrays are identical.
  static bool verifyIdMatch(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// CONTACT / REQUEST FLOW
  /// Contacts are stored inside metadata under key `contacts` as a map:
  /// { id: { 'status': 'pending'|'accepted'|'rejected', 'name': string?, 'requested_at': ISO } }

  static Future<Map<String, dynamic>> _loadFullMetadata() async {
    final meta = await PlatformSecureStorage.getMetadata();
    if (meta == null) return <String, dynamic>{};
    return Map<String, dynamic>.from(meta);
  }

  static Future<bool> _writeFullMetadata(Map<String, dynamic> m) async {
    return await PlatformSecureStorage.storeMetadata(m);
  }

  /// Send a contact request to a remote Index ID (local simulation).
  /// In this scaffolding, we only record an outgoing 'pending' request locally.
  static Future<bool> sendContactRequest(String indexId, {String? displayName}) async {
    if (indexId.isEmpty) return false;
    final meta = await _loadFullMetadata();
    final contacts = Map<String, dynamic>.from(meta['contacts'] ?? {});
    contacts[indexId] = {
      'status': 'pending',
      'name': displayName ?? indexId,
      'requested_at': DateTime.now().toIso8601String(),
    };
    meta['contacts'] = contacts;
    return await _writeFullMetadata(meta);
  }

  /// Accept an incoming contact request (or accept a pending local request).
  static Future<bool> acceptContactRequest(String indexId) async {
    if (indexId.isEmpty) return false;
    final meta = await _loadFullMetadata();
    final contacts = Map<String, dynamic>.from(meta['contacts'] ?? {});
    final entry = contacts[indexId] ?? {};
    entry['status'] = 'accepted';
    entry['accepted_at'] = DateTime.now().toIso8601String();
    contacts[indexId] = entry;
    meta['contacts'] = contacts;
    return await _writeFullMetadata(meta);
  }

  /// Reject or remove a contact request.
  static Future<bool> rejectContactRequest(String indexId) async {
    if (indexId.isEmpty) return false;
    final meta = await _loadFullMetadata();
    final contacts = Map<String, dynamic>.from(meta['contacts'] ?? {});
    contacts.remove(indexId);
    meta['contacts'] = contacts;
    return await _writeFullMetadata(meta);
  }

  /// Return contacts map
  static Future<Map<String, dynamic>> getContacts() async {
    final meta = await _loadFullMetadata();
    return Map<String, dynamic>.from(meta['contacts'] ?? {});
  }

  /// Helper to check whether a given indexId has been accepted
  static Future<bool> isContactAccepted(String indexId) async {
    final contacts = await getContacts();
    final e = contacts[indexId];
    if (e == null) return false;
    return (e['status'] as String?) == 'accepted';
  }

  /// Return a local Index ID for this device. Prefer value stored in metadata
  /// under `id`, otherwise return a placeholder string.
  static Future<String> getLocalIndexId() async {
    final meta = await PlatformSecureStorage.getMetadata();
    if (meta != null && meta.containsKey('id')) {
      return meta['id'] as String;
    }
    return 'local-index-placeholder';
  }

  /// Login with password. Enforces biometric prompt every 10th login.
  /// Returns decrypted identity blob on success, null on failure.
  static Future<Uint8List?> login(String password) async {
    final meta = await PlatformSecureStorage.getMetadata();
    if (meta == null) return null;
    final salt = base64Decode(meta['salt'] as String);
    var loginCount = (meta['login_count'] as int?) ?? 0;

    // derive key
    final pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 100000, bits: 256);
    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );

    // get encrypted blob
    final enc = await PlatformSecureStorage.getIdentity();
    if (enc == null) return null;

    try {
      final iv = enc.sublist(0, 12);
      final ct = enc.sublist(12);
      final algorithm = AesGcm.with256bits();
      final plain = await algorithm.decrypt(
        SecretBox(ct, nonce: Nonce(iv), mac: Mac.empty),
        secretKey: secretKey,
      );

      // increment counter and store
      loginCount += 1;
      meta['login_count'] = loginCount;
      await PlatformSecureStorage.storeMetadata(meta);

      // if this was every 10th login, require biometric second factor
      if (loginCount % 10 == 0) {
        final bio = await PlatformSecureStorage.getIdentityWithBiometrics();
        if (bio == null) return null; // biometric failed
      }

      return Uint8List.fromList(plain);
    } catch (e) {
      return null;
    }
  }
}
