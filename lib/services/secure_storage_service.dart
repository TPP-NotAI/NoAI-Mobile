import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for storing sensitive data using platform-level encryption.
///
/// Uses Keychain on iOS and EncryptedSharedPreferences on Android.
/// Use this instead of [StorageService] for PII or credentials.
class SecureStorageService {
  static final SecureStorageService _instance =
      SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<void> delete(String key) => _storage.delete(key: key);

  Future<bool> containsKey(String key) => _storage.containsKey(key: key);
}
