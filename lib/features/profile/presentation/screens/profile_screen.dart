import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_language_service.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/app_branding_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_card.dart';
import '../../../auth/presentation/models/contact_model.dart';
import '../../../auth/presentation/screens/contacts_screen.dart';
import '../../../auth/presentation/services/auth_service.dart';
import '../../../auth/presentation/services/contacts_service.dart';
import '../models/profile_avatar_option.dart';
import '../widgets/profile_avatar_badge.dart';
import 'profile_about_screen.dart';
import 'profile_appearance_screen.dart';

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

  UserModel? _user;
  List<ContactModel> _contacts = [];
  bool _isLoading = true;
  String _selectedAvatarId = ProfileAppearanceStore.avatarOptions.first.id;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final avatarId = await ProfileAppearanceStore.loadAvatarOptionId();
    final user = await _authService.getSession();
    if (!mounted) return;

    if (user == null) {
      setState(() {
        _selectedAvatarId = avatarId;
        _user = null;
        _contacts = [];
        _isLoading = false;
      });
      return;
    }

    final contacts = await _contactsService.getContacts(user.id);
    if (!mounted) return;

    setState(() {
      _selectedAvatarId = avatarId;
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
    if (!mounted) return;
    _loadData();
  }

  Future<void> _goToAppearance() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileAppearanceScreen()),
    );
    if (!mounted) return;
    _loadData();
  }

  Future<void> _goToAbout() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileAboutScreen()),
    );
    if (!mounted) return;
    setState(() {});
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

  @override
  Widget build(BuildContext context) {
    final selectedAvatar = ProfileAppearanceStore.optionById(_selectedAvatarId);
    final selectedPreset = _brandingService.selectedPreset;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: widget.isEmbedded
          ? AppBar(title: Text(context.tr('profile.title')))
          : null,
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
                      Text(
                        context.tr('profile.title'),
                        style: AppTheme.headlineLarge,
                      ),
                      const SizedBox(height: 20),
                    ],
                    Center(
                      child: Column(
                        children: [
                          ProfileAvatarBadge(option: selectedAvatar),
                          const SizedBox(height: 14),
                          Text(
                            _user?.name ?? context.tr('profile.user_fallback'),
                            style: AppTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _user?.city ??
                                context.tr('profile.location_fallback'),
                            style: AppTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _user?.email ?? '',
                            style: AppTheme.bodyMedium.copyWith(fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _user?.phone ?? '',
                            style: AppTheme.bodyMedium.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      context.tr('profile.account_title'),
                      style: AppTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    CustomCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _ProfileInfoRow(
                            icon: Icons.alternate_email_rounded,
                            label: context.tr('profile.email_label'),
                            value:
                                _user?.email ??
                                context.tr('profile.email_empty'),
                          ),
                          const SizedBox(height: 12),
                          _ProfileInfoRow(
                            icon: Icons.phone_outlined,
                            label: context.tr('profile.phone_label'),
                            value:
                                _user?.phone ??
                                context.tr('profile.phone_empty'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            context.tr('profile.contacts_title'),
                            style: AppTheme.titleLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _goToContacts,
                          icon: const Icon(Icons.edit, size: 16),
                          label: Text(context.tr('common.manage')),
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
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.person_outline,
                                          color: AppTheme.surface,
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
                                            if ((contact.email ?? '')
                                                .isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 2,
                                                ),
                                                child: Text(
                                                  contact.email!,
                                                  style: AppTheme.bodyMedium
                                                      .copyWith(
                                                        fontSize: 12,
                                                        color: AppTheme
                                                            .textSecondary,
                                                      ),
                                                ),
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
                    Text(
                      context.tr('profile.settings_title'),
                      style: AppTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    _SettingTile(
                      icon: Icons.palette_outlined,
                      title: context.tr('profile.appearance_title'),
                      subtitle:
                          '${selectedPreset.localizedTitle} | icono ${selectedAvatar.localizedTitle}',
                      onTap: _goToAppearance,
                    ),
                    _SettingTile(
                      icon: Icons.info_outline,
                      title: context.tr(
                        'profile.about_title',
                        params: {'appName': _brandingService.displayName},
                      ),
                      subtitle: context.tr(
                        'profile.version',
                        params: {'version': AppConstants.appVersion},
                      ),
                      onTap: _goToAbout,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout, size: 18),
                        label: Text(context.tr('profile.logout')),
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

class _ProfileInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.surface, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTheme.bodyMedium.copyWith(fontSize: 12)),
              const SizedBox(height: 2),
              Text(value, style: AppTheme.labelLarge),
            ],
          ),
        ),
      ],
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
          color: AppTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.25),
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
                    context.tr('profile.no_contacts_title'),
                    style: AppTheme.labelLarge,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    context.tr('profile.no_contacts_subtitle'),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CustomCard(
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
      ),
    );
  }
}
