import 'package:shared_preferences/shared_preferences.dart';

class LanguageService {
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  static const String _kLanguageKey = 'selected_language_locale';

  // 12 Most Spoken Languages (plus English default)
  // Using BCP-47 tags (dashes) which are safer for SpeechToText
  // 12 Most Spoken Languages (plus English default)
  // Using BCP-47 tags (dashes) which are safer for SpeechToText
  final List<Map<String, String>> supportedLanguages = [
    {'name': 'English', 'code': 'en-US', 'sttCode': 'en-US', 'countryCode': 'US'},
    {'name': 'Mandarin Chinese', 'code': 'zh-CN', 'sttCode': 'zh-CN', 'countryCode': 'CN'},
    {'name': 'Hindi', 'code': 'hi-IN', 'sttCode': 'hi-IN', 'countryCode': 'IN'},
    {'name': 'Hinglish', 'code': 'hi-Latn', 'sttCode': 'hi-IN', 'countryCode': 'IN'}, // UI: hi-Latn, STT: hi-IN (Devanagari)
    {'name': 'Spanish', 'code': 'es-ES', 'sttCode': 'es-ES', 'countryCode': 'ES'},
    {'name': 'French', 'code': 'fr-FR', 'sttCode': 'fr-FR', 'countryCode': 'FR'},
    {'name': 'Standard Arabic', 'code': 'ar-SA', 'sttCode': 'ar-SA', 'countryCode': 'SA'},
    {'name': 'Bengali', 'code': 'bn-BD', 'sttCode': 'bn-BD', 'countryCode': 'BD'},
    {'name': 'Portuguese', 'code': 'pt-BR', 'sttCode': 'pt-BR', 'countryCode': 'BR'},
    {'name': 'Russian', 'code': 'ru-RU', 'sttCode': 'ru-RU', 'countryCode': 'RU'},
    {'name': 'Urdu', 'code': 'ur-PK', 'sttCode': 'ur-PK', 'countryCode': 'PK'},
    {'name': 'Indonesian', 'code': 'id-ID', 'sttCode': 'id-ID', 'countryCode': 'ID'},
    {'name': 'German', 'code': 'de-DE', 'sttCode': 'de-DE', 'countryCode': 'DE'},
    {'name': 'Japanese', 'code': 'ja-JP', 'sttCode': 'ja-JP', 'countryCode': 'JP'},
  ];

  Future<String> getSelectedLanguageCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLanguageKey) ?? 'en-US';
  }

  Future<void> setLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLanguageKey, languageCode);
  }

  String getSTTCode(String uiCode) {
    final language = supportedLanguages.firstWhere(
      (element) => element['code'] == uiCode,
      orElse: () => {'name': 'English', 'code': 'en-US', 'sttCode': 'en-US'},
    );
    return language['sttCode'] ?? 'en-US';
  }

  String getLanguageName(String code) {
    final language = supportedLanguages.firstWhere(
      (element) => element['code'] == code,
      orElse: () => {'name': 'English', 'code': 'en-US', 'flag': '🇺🇸'},
    );
    return language['name']!;
  }
}
