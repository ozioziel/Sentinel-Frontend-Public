import 'package:flutter/material.dart';

import '../../../../core/localization/app_language_service.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/app_branding_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_button.dart';
import 'contacts_screen.dart';
import '../services/auth_identity_mapper.dart';
import '../services/auth_service.dart';
import '../services/contacts_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final ContactsService _contactsService = ContactsService();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideIn;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideIn = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final result = await AuthService().login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    setState(() => _isLoading = false);

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final user = result.user;
    if (user == null) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
        (route) => false,
      );
      return;
    }

    final hasContacts = await _contactsService.hasContacts(user.id);
    if (!mounted) {
      return;
    }

    if (hasContacts) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
        (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => ContactsScreen(userId: user.id, isInitialSetup: true),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appName = AppBrandingService.instance.displayName;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.berryBackdropGradient,
            ),
          ),
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withValues(alpha: 0.07),
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideIn,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 64),
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.primary, AppTheme.primaryLight],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.4),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.shield_rounded,
                            color: AppTheme.surface,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          appName,
                          style: AppTheme.headlineLarge.copyWith(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr('auth.login.tagline'),
                          style: AppTheme.bodyMedium.copyWith(fontSize: 15),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 56),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            context.tr('auth.login.title'),
                            style: AppTheme.headlineMedium,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            context.tr('auth.login.subtitle'),
                            style: AppTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          style: AppTheme.bodyLarge,
                          decoration: InputDecoration(
                            labelText: context.tr('auth.login.email_label'),
                            prefixIcon: const Icon(
                              Icons.alternate_email_rounded,
                              color: AppTheme.textSecondary,
                            ),
                            hintText: context.tr('auth.login.email_hint'),
                          ),
                          validator: (value) {
                            if (!AuthIdentityMapper.isValidEmail(value ?? '')) {
                              return context.tr('auth.login.email_invalid');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          style: AppTheme.bodyLarge,
                          decoration: InputDecoration(
                            labelText: context.tr('auth.login.password_label'),
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: AppTheme.textSecondary,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppTheme.textSecondary,
                              ),
                              onPressed: () {
                                setState(
                                  () => _obscurePassword = !_obscurePassword,
                                );
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return context.tr('auth.login.password_required');
                            }
                            if (value.length < 8) {
                              return context.tr('auth.login.password_min');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),
                        CustomButton(
                          text: context.tr('auth.login.submit'),
                          onPressed: _login,
                          isLoading: _isLoading,
                        ),
                        const SizedBox(height: 16),
                        CustomButton(
                          text: context.tr('auth.login.create_account'),
                          variant: ButtonVariant.outline,
                          onPressed: () {
                            Navigator.pushNamed(context, AppRoutes.register);
                          },
                        ),
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.forgotPassword,
                            );
                          },
                          child: Text(
                            context.tr('auth.login.forgot_password'),
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.primaryLight,
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          context.tr('auth.login.terms'),
                          style: AppTheme.bodyMedium.copyWith(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
