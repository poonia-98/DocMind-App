
import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';


class VaultEncryptionService {
  static const _secureStorage = FlutterSecureStorage();
  static const _keyStorageKey = 'vault_master_key';
  static const _ivStorageKey = 'vault_iv';

  /// Initialize encryption keys (generate if not exists)
  Future<void> initializeKeys() async {
    try {
      // Check if master key exists
      final existingKey = await _secureStorage.read(key: _keyStorageKey);
      final existingIV = await _secureStorage.read(key: _ivStorageKey);

      if (existingKey == null || existingIV == null) {
        // Generate new keys
        await _generateAndStoreKeys();
      }
    } catch (e) {
      throw VaultEncryptionException(
          'Failed to initialize encryption keys: $e');
    }
  }

  /// Generate and securely store encryption keys
  Future<void> _generateAndStoreKeys() async {
    try {
      // Generate random 256-bit key
      final key = encrypt.Key.fromSecureRandom(32); // 256 bits

      // Generate random IV (Initialization Vector)
      final iv = encrypt.IV.fromSecureRandom(16); // 128 bits

      // Store securely
      await _secureStorage.write(
        key: _keyStorageKey,
        value: base64Encode(key.bytes),
      );
      await _secureStorage.write(
        key: _ivStorageKey,
        value: base64Encode(iv.bytes),
      );
    } catch (e) {
      throw VaultEncryptionException('Failed to generate encryption keys: $e');
    }
  }

  /// Get encryption key from secure storage
  Future<encrypt.Key> _getKey() async {
    try {
      final keyString = await _secureStorage.read(key: _keyStorageKey);
      if (keyString == null) {
        await initializeKeys();
        return _getKey(); // Retry after initialization
      }

      final keyBytes = base64Decode(keyString);
      return encrypt.Key(Uint8List.fromList(keyBytes));
    } catch (e) {
      throw VaultEncryptionException('Failed to retrieve encryption key: $e');
    }
  }

  /// Get IV from secure storage
  Future<encrypt.IV> _getIV() async {
    try {
      final ivString = await _secureStorage.read(key: _ivStorageKey);
      if (ivString == null) {
        await initializeKeys();
        return _getIV(); // Retry after initialization
      }

      final ivBytes = base64Decode(ivString);
      return encrypt.IV(Uint8List.fromList(ivBytes));
    } catch (e) {
      throw VaultEncryptionException('Failed to retrieve IV: $e');
    }
  }

  /// Encrypt text data (for document content)
  Future<String> encryptText(String plainText) async {
    try {
      final key = await _getKey();
      final iv = await _getIV();

      final encrypter =
          encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      final encrypted = encrypter.encrypt(plainText, iv: iv);

      return encrypted.base64;
    } catch (e) {
      throw VaultEncryptionException('Encryption failed: $e');
    }
  }

  /// Decrypt text data
  Future<String> decryptText(String encryptedText) async {
    try {
      final key = await _getKey();
      final iv = await _getIV();

      final encrypter =
          encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      final decrypted = encrypter.decrypt64(encryptedText, iv: iv);

      return decrypted;
    } catch (e) {
      throw VaultEncryptionException('Decryption failed: $e');
    }
  }

  /// Encrypt binary data (for files)
  Future<Uint8List> encryptBytes(Uint8List data) async {
    try {
      final key = await _getKey();
      final iv = await _getIV();

      final encrypter =
          encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      final encrypted = encrypter.encryptBytes(data.toList(), iv: iv);

      return Uint8List.fromList(encrypted.bytes);
    } catch (e) {
      throw VaultEncryptionException('File encryption failed: $e');
    }
  }

  /// Decrypt binary data
  Future<Uint8List> decryptBytes(Uint8List encryptedData) async {
    try {
      final key = await _getKey();
      final iv = await _getIV();

      final encrypter =
          encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      final decrypted = encrypter.decryptBytes(
        encrypt.Encrypted(encryptedData),
        iv: iv,
      );

      return Uint8List.fromList(decrypted);
    } catch (e) {
      throw VaultEncryptionException('File decryption failed: $e');
    }
  }

  /// Generate hash of data (for integrity verification)
  String generateHash(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verify data integrity
  bool verifyHash(String data, String expectedHash) {
    final actualHash = generateHash(data);
    return actualHash == expectedHash;
  }

  /// Reset encryption keys 
  Future<void> resetKeys() async {
    try {
      await _secureStorage.delete(key: _keyStorageKey);
      await _secureStorage.delete(key: _ivStorageKey);
      await initializeKeys();
    } catch (e) {
      throw VaultEncryptionException('Failed to reset encryption keys: $e');
    }
  }

  /// Delete all encryption keys 
  Future<void> deleteKeys() async {
    try {
      await _secureStorage.delete(key: _keyStorageKey);
      await _secureStorage.delete(key: _ivStorageKey);
    } catch (e) {
      throw VaultEncryptionException('Failed to delete encryption keys: $e');
    }
  }

  /// Check if vault is encrypted 
  Future<bool> isVaultEncrypted() async {
    try {
      final keyExists = await _secureStorage.read(key: _keyStorageKey);
      final ivExists = await _secureStorage.read(key: _ivStorageKey);
      return keyExists != null && ivExists != null;
    } catch (e) {
      return false;
    }
  }
}

/// Custom exception for vault encryption errors
class VaultEncryptionException implements Exception {
  final String message;
  VaultEncryptionException(this.message);

  @override
  String toString() => message;
}
