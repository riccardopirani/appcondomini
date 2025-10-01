import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _locale = const Locale('it');

  Locale get locale => _locale;

  LanguageProvider() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language_code') ?? 'it';
    _locale = Locale(languageCode);
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;

    _locale = locale;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', locale.languageCode);
  }

  String getLanguageName(String languageCode) {
    switch (languageCode) {
      case 'it':
        return 'Italiano';
      case 'en':
        return 'English';
      case 'fr':
        return 'Français';
      case 'zh':
        return '中文';
      default:
        return languageCode;
    }
  }

  IconData getLanguageFlag(String languageCode) {
    // Usando emoji come icone
    switch (languageCode) {
      case 'it':
        return Icons.flag; // 🇮🇹
      case 'en':
        return Icons.flag; // 🇬🇧
      case 'fr':
        return Icons.flag; // 🇫🇷
      case 'zh':
        return Icons.flag; // 🇨🇳
      default:
        return Icons.language;
    }
  }
}
