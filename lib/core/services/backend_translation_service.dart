import 'dart:convert';

import 'package:http/http.dart' as http;

import '../localization/app_language_service.dart';

/// Translates backend-returned Spanish text to the current app language
/// using Google Translate's free endpoint. Results are cached in-memory.
class BackendTranslationService {
  BackendTranslationService._();

  static final BackendTranslationService instance =
      BackendTranslationService._();

  // cache[targetLang][original] = translated
  final Map<String, Map<String, String>> _cache = {};

  bool get _needsTranslation {
    final lang = AppLanguageService.instance.language;
    return lang == AppLanguage.aymara || lang == AppLanguage.quechua;
  }

  String get _targetLang => AppLanguageService.instance.language.code;

  /// Translates [text] from Spanish to the current app language.
  /// Returns the original text if translation is not needed or fails.
  Future<String> translate(String text) async {
    if (text.trim().isEmpty) return text;
    if (!_needsTranslation) return text;

    final target = _targetLang;
    final cached = _cache[target]?[text];
    if (cached != null) return cached;

    try {
      final url = Uri.parse(
        'https://translate.googleapis.com/translate_a/single'
        '?client=gtx&sl=es&tl=$target&dt=t&q=${Uri.encodeComponent(text)}',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final segments = data[0] as List?;
        if (segments != null && segments.isNotEmpty) {
          final parts = segments
              .map((e) => (e is List && e.isNotEmpty ? e[0] : null) as String? ?? '')
              .join('');
          if (parts.isNotEmpty) {
            _cache.putIfAbsent(target, () => {})[text] = parts;
            return parts;
          }
        }
      }
    } catch (_) {
      // Fall through — return original text
    }
    return text;
  }

  /// Clears the translation cache (call after language change).
  void clearCache() => _cache.clear();
}
