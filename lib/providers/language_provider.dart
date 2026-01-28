import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../config/app_constants.dart';

class LanguageProvider with ChangeNotifier {
  final StorageService _storage = StorageService();
  static const _defaultLanguage = 'en';

  String _currentLanguage = _defaultLanguage;
  String get currentLanguage => _currentLanguage;

  String get currentLanguageName {
    switch (_currentLanguage) {
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
      case 'fr':
        return 'Français';
      case 'de':
        return 'Deutsch';
      case 'it':
        return 'Italiano';
      case 'pt':
        return 'Português';
      case 'ru':
        return 'Русский';
      case 'zh':
        return '中文';
      case 'ja':
        return '日本語';
      case 'ko':
        return '한국어';
      default:
        return 'English';
    }
  }

  List<Map<String, String>> get supportedLanguages => [
    {'code': 'en', 'name': 'English'},
    {'code': 'es', 'name': 'Español'},
    {'code': 'fr', 'name': 'Français'},
    {'code': 'de', 'name': 'Deutsch'},
    {'code': 'it', 'name': 'Italiano'},
    {'code': 'pt', 'name': 'Português'},
    {'code': 'ru', 'name': 'Русский'},
    {'code': 'zh', 'name': '中文'},
    {'code': 'ja', 'name': '日本語'},
    {'code': 'ko', 'name': '한국어'},
  ];

  LanguageProvider() {
    _load();
  }

  Future<void> _load() async {
    _currentLanguage =
        _storage.getString(AppConstants.languageKey) ?? _defaultLanguage;
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    if (_currentLanguage != languageCode) {
      _currentLanguage = languageCode;
      await _storage.setString(AppConstants.languageKey, languageCode);
      notifyListeners();
    }
  }
}
