import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  aymara(
    code: 'ay',
    labelKey: 'languages.aymara',
    chatbotName: 'Aymara',
  ),
  quechua(
    code: 'qu',
    labelKey: 'languages.quechua',
    chatbotName: 'Quechua',
  ),
  spanish(
    code: 'es',
    labelKey: 'languages.spanish',
    chatbotName: 'Spanish',
  );

  final String code;
  final String labelKey;
  final String chatbotName;

  const AppLanguage({
    required this.code,
    required this.labelKey,
    required this.chatbotName,
  });

  static AppLanguage fromCode(String? value) {
    for (final lang in AppLanguage.values) {
      if (lang.code == value) return lang;
    }
    return AppLanguage.spanish;
  }
}

class AppLanguageService extends ChangeNotifier {
  AppLanguageService._();

  static final AppLanguageService instance = AppLanguageService._();
  static const String _assetPathPrefix = 'assets/i18n';
  static const String _langPrefKey = 'app_language';
  // ay and qu are not supported by GlobalMaterialLocalizations, so we always
  // pass Spanish to MaterialApp. App-level text is handled by tr() / pick().
  static const List<Locale> supportedMaterialLocales = [Locale('es', 'BO')];
  static const Locale _materialLocale = Locale('es', 'BO');

  AppLanguage _language = AppLanguage.aymara;
  bool _isLanguageChosen = false;
  Map<String, dynamic> _translations = <String, dynamic>{};
  Map<String, dynamic> _fallbackTranslations = <String, dynamic>{};

  AppLanguage get language => _language;
  Locale get materialLocale => _materialLocale;
  bool get isLanguageChosen => _isLanguageChosen;

  Future<void> initialize() async {
    _fallbackTranslations = await _loadTranslations(AppLanguage.spanish);

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_langPrefKey);
    if (saved != null) {
      _language = AppLanguage.fromCode(saved);
      _translations = await _loadTranslations(_language);
      _isLanguageChosen = true;
    } else {
      _language = AppLanguage.aymara;
      _translations = _fallbackTranslations;
      _isLanguageChosen = false;
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    _language = language;
    _translations = await _loadTranslations(language);
    _isLanguageChosen = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langPrefKey, language.code);
    notifyListeners();
  }

  String languageLabel(AppLanguage language) {
    return tr(language.labelKey);
  }

  String pick({
    required String es,
    String? en,
    String? ay,
    String? qu,
  }) {
    switch (_language) {
      case AppLanguage.aymara:
        return ay ?? es;
      case AppLanguage.quechua:
        return qu ?? es;
      case AppLanguage.spanish:
        return es;
    }
  }

  String tr(
    String key, {
    Map<String, String> params = const <String, String>{},
    String? fallback,
  }) {
    final value =
        _lookupValue(_translations, key) ??
        _lookupValue(_fallbackTranslations, key) ??
        fallback ??
        key;

    if (value is! String) {
      return fallback ?? key;
    }

    return _replaceParams(value, params);
  }

  Future<Map<String, dynamic>> _loadTranslations(AppLanguage language) async {
    try {
      final raw = await rootBundle.loadString(
        '$_assetPathPrefix/${language.code}.json',
      );
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Fall back to the bundled Spanish copy.
    }

    return _fallbackTranslations;
  }

  dynamic _lookupValue(Map<String, dynamic> source, String key) {
    dynamic current = source;
    for (final part in key.split('.')) {
      if (current is Map<String, dynamic> && current.containsKey(part)) {
        current = current[part];
        continue;
      }
      if (current is Map && current.containsKey(part)) {
        current = current[part];
        continue;
      }
      return null;
    }
    return current;
  }

  String _replaceParams(String value, Map<String, String> params) {
    var resolved = value;
    for (final entry in params.entries) {
      resolved = resolved.replaceAll('{{${entry.key}}}', entry.value);
    }
    return resolved;
  }
}

/// InheritedNotifier that makes any widget calling [BuildContext.tr] or
/// [BuildContext.pick] automatically rebuild when the language changes.
/// Place this once in the widget tree (inside MaterialApp.builder) above all
/// app content.
class AppLanguageScope extends InheritedNotifier<AppLanguageService> {
  AppLanguageScope({super.key, required super.child})
      : super(notifier: AppLanguageService.instance);

  /// Call in [build] to register a rebuild dependency without reading a string.
  static void watch(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLanguageScope>();
}

extension AppLanguageBuildContext on BuildContext {
  AppLanguage get appLanguage {
    dependOnInheritedWidgetOfExactType<AppLanguageScope>();
    return AppLanguageService.instance.language;
  }

  String tr(
    String key, {
    Map<String, String> params = const <String, String>{},
    String? fallback,
  }) {
    dependOnInheritedWidgetOfExactType<AppLanguageScope>();
    return AppLanguageService.instance.tr(
      key,
      params: params,
      fallback: fallback,
    );
  }

  /// Reactive version of [AppLanguageService.pick] — registers this widget as
  /// a dependent so it rebuilds automatically on language change.
  String pick({
    required String es,
    String? en,
    String? ay,
    String? qu,
  }) {
    dependOnInheritedWidgetOfExactType<AppLanguageScope>();
    return AppLanguageService.instance.pick(es: es, en: en, ay: ay, qu: qu);
  }
}
