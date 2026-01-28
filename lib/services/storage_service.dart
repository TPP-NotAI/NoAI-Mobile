import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  // Singleton pattern
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;

  // Initialize shared preferences
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Get string value
  String? getString(String key) {
    return _prefs?.getString(key);
  }

  // Set string value
  Future<bool> setString(String key, String value) async {
    return await _prefs?.setString(key, value) ?? false;
  }

  // Get int value
  int? getInt(String key) {
    return _prefs?.getInt(key);
  }

  // Set int value
  Future<bool> setInt(String key, int value) async {
    return await _prefs?.setInt(key, value) ?? false;
  }

  // Get bool value
  bool? getBool(String key) {
    return _prefs?.getBool(key);
  }

  // Set bool value
  Future<bool> setBool(String key, bool value) async {
    return await _prefs?.setBool(key, value) ?? false;
  }

  // Get double value
  double? getDouble(String key) {
    return _prefs?.getDouble(key);
  }

  // Set double value
  Future<bool> setDouble(String key, double value) async {
    return await _prefs?.setDouble(key, value) ?? false;
  }

  // Get string list
  List<String>? getStringList(String key) {
    return _prefs?.getStringList(key);
  }

  // Set string list
  Future<bool> setStringList(String key, List<String> value) async {
    return await _prefs?.setStringList(key, value) ?? false;
  }

  // Remove a key
  Future<bool> remove(String key) async {
    return await _prefs?.remove(key) ?? false;
  }

  // Clear all data
  Future<bool> clear() async {
    return await _prefs?.clear() ?? false;
  }

  // Check if key exists
  bool containsKey(String key) {
    return _prefs?.containsKey(key) ?? false;
  }

  // Get all keys
  Set<String> getKeys() {
    return _prefs?.getKeys() ?? {};
  }
}
