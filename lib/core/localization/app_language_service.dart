import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum AppLanguage {
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
}

class AppLanguageService extends ChangeNotifier {
  AppLanguageService._();

  static final AppLanguageService instance = AppLanguageService._();
  static const String _assetPathPrefix = 'assets/i18n';
  static const List<Locale> supportedMaterialLocales = [Locale('es', 'BO')];
  static const Locale _materialLocale = Locale('es', 'BO');

  final AppLanguage _language = AppLanguage.spanish;
  Map<String, dynamic> _translations = <String, dynamic>{};

  AppLanguage get language => _language;
  Locale get materialLocale => _materialLocale;

  Future<void> initialize() async {
    _translations = await _loadTranslations();
  }

  String pick({
    required String es,
    String? en,
    String? ay,
    String? qu,
  }) {
    return es;
  }

  String tr(
    String key, {
    Map<String, String> params = const <String, String>{},
    String? fallback,
  }) {
    final value =
        _lookupValue(_translations, key) ??
        fallback ??
        key;

    if (value is! String) {
      return fallback ?? key;
    }

    return _replaceParams(value, params);
  }

  Future<Map<String, dynamic>> _loadTranslations() async {
    try {
      final raw = await rootBundle.loadString('$_assetPathPrefix/es.json');
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return <String, dynamic>{};
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
