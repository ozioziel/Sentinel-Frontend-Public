import 'package:flutter/material.dart';

import '../../../../core/localization/app_language_service.dart';
import '../../../../core/theme/app_theme.dart';
import 'session_gate_screen.dart';

class LanguageSelectionScreen extends StatefulWidget {
  /// When true (initial launch), selecting a language replaces the stack with
  /// a fresh SessionGateScreen so the normal auth flow continues.
  /// When false (from profile), selecting a language just pops.
  final bool isInitialSetup;

  const LanguageSelectionScreen({super.key, this.isInitialSetup = true});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  bool _isLoading = false;

  Future<void> _selectLanguage(AppLanguage language) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    await AppLanguageService.instance.setLanguage(language);
    if (!mounted) return;
    // Always replace the entire stack so every screen rebuilds with new language.
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SessionGateScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = AppLanguageService.instance.language;
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: widget.isInitialSetup
          ? null
          : AppBar(
              backgroundColor: AppTheme.surface,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded,
                    color: AppTheme.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                context.tr('profile.language_title'),
                style: AppTheme.titleLarge,
              ),
            ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: widget.isInitialSetup ? 60 : 24),
              if (widget.isInitialSetup) ...[
                Text(
                  context.tr('languages.title'),
                  style: AppTheme.headlineLarge,
                ),
                const SizedBox(height: 10),
                Text(
                  context.tr('languages.subtitle'),
                  style: AppTheme.bodyMedium.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 48),
              ],
              _LanguageOption(
                label: 'Español',
                nativeLabel: context.tr('languages.spanish'),
                isSelected: !widget.isInitialSetup &&
                    current == AppLanguage.spanish,
                onTap: _isLoading
                    ? null
                    : () => _selectLanguage(AppLanguage.spanish),
              ),
              const SizedBox(height: 16),
              _LanguageOption(
                label: 'Aymara',
                nativeLabel: 'Aru',
                isSelected: !widget.isInitialSetup &&
                    current == AppLanguage.aymara,
                onTap: _isLoading
                    ? null
                    : () => _selectLanguage(AppLanguage.aymara),
              ),
              const SizedBox(height: 16),
              _LanguageOption(
                label: 'Quechua',
                nativeLabel: 'Simi',
                isSelected: !widget.isInitialSetup &&
                    current == AppLanguage.quechua,
                onTap: _isLoading
                    ? null
                    : () => _selectLanguage(AppLanguage.quechua),
              ),
              if (_isLoading) ...[
                const SizedBox(height: 32),
                const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String label;
  final String nativeLabel;
  final bool isSelected;
  final VoidCallback? onTap;

  const _LanguageOption({
    required this.label,
    required this.nativeLabel,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primary.withValues(alpha: 0.12)
                : AppTheme.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primary
                  : AppTheme.primary.withValues(alpha: 0.25),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTheme.titleLarge.copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nativeLabel,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.primary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.primary,
                  size: 20,
                )
              else
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
