import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/app_branding_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_card.dart';
import '../../../auth/presentation/screens/contacts_screen.dart';
import '../../../auth/presentation/services/auth_service.dart';
import '../../../auth/presentation/services/contacts_service.dart';

class ProfileScreen extends StatefulWidget {
  final bool isEmbedded;

  const ProfileScreen({super.key, this.isEmbedded = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ContactsService _contactsService = ContactsService();
  final AuthService _authService = AuthService();
  final AppBrandingService _brandingService = AppBrandingService.instance;
  final TextEditingController _appNameController = TextEditingController();

  UserModel? _user;
  List<ContactModel> _contacts = [];
  bool _isLoading = true;
  bool _isSavingBranding = false;
  late String _selectedPresetId;

  @override
  void initState() {
    super.initState();
    _selectedPresetId = _brandingService.selectedPreset.id;
    _appNameController.text = _brandingService.customAppName;
    _appNameController.addListener(_refreshDraftPreview);
    _loadData();
  }

  @override
  void dispose() {
    _appNameController.removeListener(_refreshDraftPreview);
    _appNameController.dispose();
    super.dispose();
  }

  void _refreshDraftPreview() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final user = await _authService.getSession();
    if (!mounted) return;

    if (user == null) {
      setState(() {
        _user = null;
        _contacts = [];
        _isLoading = false;
      });
      return;
    }

    final contacts = await _contactsService.getContacts(user.id);
    if (!mounted) return;

    setState(() {
      _user = user;
      _contacts = contacts;
      _isLoading = false;
    });
  }

  Future<void> _goToContacts() async {
    if (_user == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ContactsScreen(userId: _user!.id)),
    );
    _loadData();
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }

  Future<void> _saveBranding() async {
    setState(() => _isSavingBranding = true);
    final warning = await _brandingService.saveBranding(
      presetId: _selectedPresetId,
      customAppName: _appNameController.text,
    );
    if (!mounted) return;

    setState(() => _isSavingBranding = false);

    final message = warning == null
        ? 'Apariencia actualizada.'
        : 'Apariencia guardada. $warning';

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
    final displayNamePreview = _draftDisplayName(selectedPreset);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: widget.isEmbedded ? AppBar(title: const Text('Mi Perfil')) : null,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    if (!widget.isEmbedded) ...[
                      Text('Perfil', style: AppTheme.headlineLarge),
                      const SizedBox(height: 20),
                    ],
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppTheme.primary,
                                  AppTheme.primaryLight,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withOpacity(0.35),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _user?.name ?? 'Usuaria',
                            style: AppTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _user?.city ?? 'Bolivia',
                            style: AppTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _user?.phone ?? '',
                            style: AppTheme.bodyMedium.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text('Apariencia de la app', style: AppTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      'Elige un icono genérico por defecto y define cómo quieres ver el nombre dentro de la app.',
                      style: AppTheme.bodyMedium,
                    ),
                    const SizedBox(height: 14),
                    CustomCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          _BrandingPreviewBadge(
                            icon: selectedPreset.previewIcon,
                            color: selectedPreset.accentColor,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayNamePreview,
                                  style: AppTheme.titleLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Nombre del launcher: ${selectedPreset.launcherName}',
                                  style: AppTheme.bodyMedium.copyWith(
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Preset activo: ${selectedPreset.title}',
                                  style: AppTheme.bodyMedium.copyWith(
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
                        labelText: 'Nombre personalizado',
                        hintText: selectedPreset.launcherName,
                        helperText:
                            'Déjalo vacío para usar el nombre del icono seleccionado.',
                        prefixIcon: const Icon(Icons.draw_outlined),
                      ),
                    ),
                    const SizedBox(height: 6),
                    CustomCard(
                      padding: const EdgeInsets.all(14),
                      backgroundColor: AppTheme.primary.withOpacity(0.08),
                      borderColor: AppTheme.primary.withOpacity(0.25),
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
                                  ? 'En Android, el icono y el nombre del acceso directo siguen el preset genérico elegido. El nombre personalizado se verá dentro de la app.'
                                  : 'En esta plataforma se guarda el nombre personalizado dentro de la app. El launcher depende del sistema operativo.',
                              style: AppTheme.bodyMedium.copyWith(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSavingBranding ? null : _saveBranding,
                        icon: _isSavingBranding
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.palette_outlined, size: 18),
                        label: Text(
                          _isSavingBranding
                              ? 'Guardando apariencia...'
                              : 'Guardar apariencia',
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Text(
                            'Contactos de emergencia',
                            style: AppTheme.titleLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _goToContacts,
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Gestionar'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _contacts.isEmpty
                        ? _EmptyContactsBanner(onTap: _goToContacts)
                        : Column(
                            children: _contacts.map((contact) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: CustomCard(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary.withOpacity(
                                            0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.person_outline,
                                          color: AppTheme.primary,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              contact.name,
                                              style: AppTheme.labelLarge,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              contact.relation,
                                              style: AppTheme.bodyMedium
                                                  .copyWith(
                                                    fontSize: 11,
                                                    color: AppTheme.primary,
                                                  ),
                                            ),
                                            const SizedBox(height: 1),
                                            Text(
                                              contact.phone,
                                              style: AppTheme.bodyMedium
                                                  .copyWith(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: AppTheme.error,
                                          size: 18,
                                        ),
                                        onPressed: () async {
                                          if (_user == null) return;
                                          await _contactsService.deleteContact(
                                            _user!.id,
                                            contact.id,
                                          );
                                          _loadData();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                    const SizedBox(height: 24),
                    Text('Configuración', style: AppTheme.titleLarge),
                    const SizedBox(height: 12),
                    _SettingTile(
                      icon: Icons.notifications_outlined,
                      title: 'Notificaciones',
                      subtitle: 'Alertas y avisos',
                      onTap: () {},
                    ),
                    _SettingTile(
                      icon: Icons.lock_outline,
                      title: 'Privacidad',
                      subtitle: 'Datos y permisos',
                      onTap: () {},
                    ),
                    _SettingTile(
                      icon: Icons.language_outlined,
                      title: 'Idioma',
                      subtitle: 'Español (Bolivia)',
                      onTap: () {},
                    ),
                    _SettingTile(
                      icon: Icons.info_outline,
                      title: 'Acerca de ${_brandingService.displayName}',
                      subtitle: 'Versión ${AppConstants.appVersion}',
                      onTap: () {},
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('Cerrar sesión'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.error,
                          side: const BorderSide(color: AppTheme.error),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
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
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.32),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 28),
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
            ? preset.accentColor.withOpacity(0.18)
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
            Text(preset.title, style: AppTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              preset.description,
              style: AppTheme.bodyMedium.copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyContactsBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _EmptyContactsBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.primary.withOpacity(0.25),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.people_outline, color: AppTheme.primary, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sin contactos de emergencia',
                    style: AppTheme.labelLarge,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Toca aquí para agregar uno',
                    style: AppTheme.bodyMedium.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: AppTheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.labelLarge),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTheme.bodyMedium.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: AppTheme.textSecondary,
          ),
        ],
      ),
    );
  }
}
