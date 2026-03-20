import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

@immutable
class AppBrandingPreset {
  final String id;
  final String launcherName;
  final String title;
  final String description;
  final IconData previewIcon;
  final Color accentColor;

  const AppBrandingPreset({
    required this.id,
    required this.launcherName,
    required this.title,
    required this.description,
    required this.previewIcon,
    required this.accentColor,
  });
}

class AppBrandingService extends ChangeNotifier {
  AppBrandingService._();

  static final AppBrandingService instance = AppBrandingService._();
  static const MethodChannel _channel = MethodChannel(
    'com.example.test01/app_branding',
  );

  static const List<AppBrandingPreset> presets = [
    AppBrandingPreset(
      id: 'sentinel',
      launcherName: AppConstants.appName,
      title: 'Sentinel',
      description: 'Mantiene la identidad actual de seguridad.',
      previewIcon: Icons.shield_rounded,
      accentColor: Color(0xFFD63864),
    ),
    AppBrandingPreset(
      id: 'agenda',
      launcherName: 'Agenda',
      title: 'Agenda',
      description: 'Aspecto discreto, como una app de calendario.',
      previewIcon: Icons.calendar_month_rounded,
      accentColor: Color(0xFF1B9AAA),
    ),
    AppBrandingPreset(
      id: 'notas',
      launcherName: 'Notas',
      title: 'Notas',
      description: 'Icono limpio para pasar como bloc de notas.',
      previewIcon: Icons.sticky_note_2_rounded,
      accentColor: Color(0xFFF28F3B),
    ),
    AppBrandingPreset(
      id: 'tareas',
      launcherName: 'Tareas',
      title: 'Tareas',
      description: 'Lista de pendientes simple y neutral.',
      previewIcon: Icons.checklist_rounded,
      accentColor: Color(0xFF2E9E57),
    ),
  ];

  AppBrandingPreset _selectedPreset = presetById(
    AppConstants.defaultBrandingPresetId,
  );
  String _customAppName = '';

  AppBrandingPreset get selectedPreset => _selectedPreset;
  String get customAppName => _customAppName;
  String get displayName =>
      _customAppName.isEmpty ? _selectedPreset.launcherName : _customAppName;
  bool get supportsLauncherCustomization =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static AppBrandingPreset presetById(String? id) {
    return presets.firstWhere(
      (preset) => preset.id == id,
      orElse: () => presets.first,
    );
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedPreset = presetById(
      prefs.getString(AppConstants.keyBrandingPreset),
    );
    _customAppName = _sanitizeName(
      prefs.getString(AppConstants.keyCustomAppName) ?? '',
    );

    if (supportsLauncherCustomization) {
      await _applyNativePreset(_selectedPreset.id);
    }
  }

  Future<String?> saveBranding({
    required String presetId,
    required String customAppName,
  }) async {
    _selectedPreset = presetById(presetId);
    _customAppName = _sanitizeName(customAppName);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyBrandingPreset, _selectedPreset.id);
    await prefs.setString(AppConstants.keyCustomAppName, _customAppName);

    return _applyNativePreset(_selectedPreset.id);
  }

  String _sanitizeName(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<String?> _applyNativePreset(String presetId) async {
    if (!supportsLauncherCustomization) {
      return 'El icono y el nombre del launcher se aplican en Android.';
    }

    try {
      await _channel.invokeMethod<void>('applyPreset', {'presetId': presetId});
      return null;
    } on MissingPluginException {
      return 'No se pudo conectar con el cambio nativo del launcher.';
    } on PlatformException catch (error) {
      return error.message ?? 'No se pudo actualizar el launcher.';
    } catch (_) {
      return 'No se pudo actualizar el launcher.';
    }
  }
}
