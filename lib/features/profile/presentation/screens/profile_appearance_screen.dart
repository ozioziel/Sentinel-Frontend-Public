import 'package:flutter/material.dart';

import '../../../../core/localization/app_language_service.dart';
import '../../../../core/services/app_branding_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_card.dart';
import '../models/profile_avatar_option.dart';
import '../widgets/profile_avatar_badge.dart';

class ProfileAppearanceScreen extends StatefulWidget {
  const ProfileAppearanceScreen({super.key});

  @override
  State<ProfileAppearanceScreen> createState() =>
      _ProfileAppearanceScreenState();
}

class _ProfileAppearanceScreenState extends State<ProfileAppearanceScreen> {
  final AppBrandingService _brandingService = AppBrandingService.instance;
  final TextEditingController _appNameController = TextEditingController();

  bool _isSaving = false;
  late String _selectedPresetId;
  String _selectedAvatarId = ProfileAppearanceStore.avatarOptions.first.id;

  @override
  void initState() {
    super.initState();
    _selectedPresetId = _brandingService.selectedPreset.id;
    _appNameController.text = _brandingService.customAppName;
    _appNameController.addListener(_refreshPreview);
    _loadAvatarOption();
  }

  @override
  void dispose() {
    _appNameController.removeListener(_refreshPreview);
    _appNameController.dispose();
    super.dispose();
  }

  void _refreshPreview() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadAvatarOption() async {
    final avatarId = await ProfileAppearanceStore.loadAvatarOptionId();
    if (!mounted) return;
    setState(() => _selectedAvatarId = avatarId);
  }

  Future<void> _saveAppearance() async {
    setState(() => _isSaving = true);

    await ProfileAppearanceStore.saveAvatarOptionId(_selectedAvatarId);
    final warning = await _brandingService.saveBranding(
      presetId: _selectedPresetId,
      customAppName: _appNameController.text,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    final message = warning == null
        ? context.tr('profile.appearance.updated')
        : context.tr(
            'profile.appearance.saved_warning',
            params: {'warning': warning},
          );

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _draftDisplayName(AppBrandingPreset preset) {
    final customName = _appNameController.text.trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    return customName.isEmpty ? preset.launcherName : customName;
  }

  @override
  Widget build(BuildContext context) {
    final selectedPreset = AppBrandingService.presetById(_selectedPresetId);
    final selectedAvatar = ProfileAppearanceStore.optionById(_selectedAvatarId);
    final displayNamePreview = _draftDisplayName(selectedPreset);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: Text(context.tr('profile.appearance.title'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    ProfileAvatarBadge(
                      option: selectedAvatar,
                      size: 66,
                      borderRadius: 22,
                      iconSize: 32,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(displayNamePreview, style: AppTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text(
                            context.tr(
                              'profile.appearance.profile_preview',
                              params: {'title': selectedAvatar.localizedTitle},
                            ),
                            style: AppTheme.bodyMedium.copyWith(fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.tr(
                              'profile.appearance.launcher_preview',
                              params: {'title': selectedPreset.launcherName},
                            ),
                            style: AppTheme.bodyMedium.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    _BrandingPreviewBadge(
                      icon: selectedPreset.previewIcon,
                      color: selectedPreset.accentColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                context.tr('profile.appearance.avatar_title'),
                style: AppTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('profile.appearance.avatar_subtitle'),
                style: AppTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: ProfileAppearanceStore.avatarOptions.map((option) {
                  return _AvatarOptionCard(
                    option: option,
                    isSelected: option.id == _selectedAvatarId,
                    onTap: () {
                      setState(() => _selectedAvatarId = option.id);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Text(
                context.tr('profile.appearance.launcher_title'),
                style: AppTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('profile.appearance.launcher_subtitle'),
                style: AppTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: AppBrandingService.presets.map((preset) {
                  return _BrandingPresetCard(
                    preset: preset,
                    isSelected: preset.id == _selectedPresetId,
                    onTap: () {
                      setState(() => _selectedPresetId = preset.id);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _appNameController,
                maxLength: 24,
                decoration: InputDecoration(
                  labelText: context.tr('profile.appearance.custom_name_label'),
                  hintText: selectedPreset.launcherName,
                  helperText: context.tr(
                    'profile.appearance.custom_name_helper',
                  ),
                  prefixIcon: const Icon(Icons.draw_outlined),
                ),
              ),
              const SizedBox(height: 6),
              CustomCard(
                padding: const EdgeInsets.all(14),
                backgroundColor: AppTheme.primary.withValues(alpha: 0.08),
                borderColor: AppTheme.primary.withValues(alpha: 0.25),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppTheme.primaryLight,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _brandingService.supportsLauncherCustomization
                            ? context.tr('profile.appearance.platform_android')
                            : context.tr('profile.appearance.platform_other'),
                        style: AppTheme.bodyMedium.copyWith(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveAppearance,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.surface,
                          ),
                        )
                      : const Icon(Icons.palette_outlined, size: 18),
                  label: Text(
                    _isSaving
                        ? context.tr('profile.appearance.saving')
                        : context.tr('profile.appearance.save'),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarOptionCard extends StatelessWidget {
  final ProfileAvatarOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _AvatarOptionCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: CustomCard(
        onTap: onTap,
        borderRadius: 18,
        backgroundColor: isSelected
            ? option.startColor.withValues(alpha: 0.18)
            : AppTheme.cardBg,
        borderColor: isSelected ? option.startColor : AppTheme.divider,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProfileAvatarBadge(
                  option: option,
                  size: 58,
                  borderRadius: 18,
                  iconSize: 28,
                ),
                const Spacer(),
                if (isSelected)
                  Icon(Icons.check_circle, color: option.startColor, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Text(option.localizedTitle, style: AppTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              option.localizedSubtitle,
              style: AppTheme.bodyMedium.copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandingPreviewBadge extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _BrandingPreviewBadge({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.32),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, color: AppTheme.textPrimary, size: 28),
    );
  }
}

class _BrandingPresetCard extends StatelessWidget {
  final AppBrandingPreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  const _BrandingPresetCard({
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: CustomCard(
        onTap: onTap,
        borderRadius: 18,
        backgroundColor: isSelected
            ? preset.accentColor.withValues(alpha: 0.18)
            : AppTheme.cardBg,
        borderColor: isSelected ? preset.accentColor : AppTheme.divider,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _BrandingPreviewBadge(
                  icon: preset.previewIcon,
                  color: preset.accentColor,
                ),
                const Spacer(),
                if (isSelected)
                  Icon(Icons.check_circle, color: preset.accentColor, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Text(preset.localizedTitle, style: AppTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              preset.localizedDescription,
              style: AppTheme.bodyMedium.copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
