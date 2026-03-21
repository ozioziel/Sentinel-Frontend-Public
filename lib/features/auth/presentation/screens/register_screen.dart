import 'package:flutter/material.dart';

import '../../../../core/localization/app_language_service.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_button.dart';
import 'contacts_screen.dart';
import '../services/auth_identity_mapper.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _firstNamesController = TextEditingController();
  final _lastNamesController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String _selectedCity = 'La Paz';
  DateTime? _selectedBirthDate;

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
    _firstNamesController.dispose();
    _lastNamesController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initialDate =
        _selectedBirthDate ?? DateTime(now.year - 18, now.month, now.day);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now) ? now : initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: context.tr('auth.register.birth_date_help'),
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    setState(() {
      _selectedBirthDate = pickedDate;
      _birthDateController.text = _formatBirthDateLabel(pickedDate);
    });
  }

  String _formatBirthDateLabel(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString().padLeft(4, '0');
    return '$day/$month/$year';
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final result = await AuthService().register(
      _firstNamesController.text.trim(),
      _lastNamesController.text.trim(),
      _emailController.text.trim(),
      _phoneController.text.trim(),
      _passwordController.text.trim(),
      _selectedCity,
      _selectedBirthDate!,
    );

    if (!mounted) {
      return;
    }

    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? AppTheme.success : AppTheme.error,
      ),
    );

    if (!result.success) {
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

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => ContactsScreen(userId: user.id, isInitialSetup: true),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
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
                        const SizedBox(height: 40),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.arrow_back_ios,
                              color: AppTheme.textPrimary,
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.primary, AppTheme.primaryLight],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.shield_rounded,
                            color: AppTheme.surface,
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          context.tr('auth.register.title'),
                          style: AppTheme.headlineLarge.copyWith(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.tr('auth.register.subtitle'),
                          style: AppTheme.bodyMedium.copyWith(fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 36),
                        TextFormField(
                          controller: _firstNamesController,
                          keyboardType: TextInputType.name,
                          style: AppTheme.bodyLarge,
                          decoration: InputDecoration(
                            labelText: context.tr(
                              'auth.register.first_names_label',
                            ),
                            prefixIcon: const Icon(
                              Icons.person_outline,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return context.tr(
                                'auth.register.first_names_required',
                              );
                            }
                            if (value.trim().length < 3) {
                              return context.tr(
                                'auth.register.first_names_short',
                              );
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _lastNamesController,
                          keyboardType: TextInputType.name,
                          style: AppTheme.bodyLarge,
                          decoration: InputDecoration(
                            labelText: context.tr(
                              'auth.register.last_names_label',
                            ),
                            prefixIcon: const Icon(
                              Icons.badge_outlined,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return context.tr(
                                'auth.register.last_names_required',
                              );
                            }
                            if (value.trim().length < 3) {
                              return context.tr(
                                'auth.register.last_names_short',
                              );
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: AppTheme.bodyLarge,
                          decoration: InputDecoration(
                            labelText: context.tr('auth.register.email_label'),
                            prefixIcon: const Icon(
                              Icons.alternate_email_rounded,
                              color: AppTheme.textSecondary,
                            ),
                            hintText: context.tr('auth.register.email_hint'),
                          ),
                          validator: (value) {
                            if (!AuthIdentityMapper.isValidEmail(value ?? '')) {
                              return context.tr('auth.register.email_invalid');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: AppTheme.bodyLarge,
                          decoration: InputDecoration(
                            labelText: context.tr('auth.register.phone_label'),
                            prefixIcon: const Icon(
                              Icons.phone_outlined,
                              color: AppTheme.textSecondary,
                            ),
                            hintText: context.tr('auth.register.phone_hint'),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return context.tr('auth.register.phone_required');
                            }
                            final digits = value.replaceAll(RegExp(r'\D'), '');
                            if (digits.length < 8) {
                              return context.tr('auth.register.phone_invalid');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _birthDateController,
                          readOnly: true,
                          onTap: _pickBirthDate,
                          style: AppTheme.bodyLarge,
                          decoration: InputDecoration(
                            labelText: context.tr(
                              'auth.register.birth_date_label',
                            ),
                            prefixIcon: const Icon(
                              Icons.cake_outlined,
                              color: AppTheme.textSecondary,
                            ),
                            hintText: context.tr(
                              'auth.register.birth_date_hint',
                            ),
                          ),
                          validator: (value) {
                            if (_selectedBirthDate == null) {
                              return context.tr(
                                'auth.register.birth_date_required',
                              );
                            }
                            if (_selectedBirthDate!.isAfter(DateTime.now())) {
                              return context.tr(
                                'auth.register.birth_date_invalid',
                              );
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCity,
                          dropdownColor: AppTheme.cardBg,
                          style: AppTheme.bodyLarge,
                          decoration: InputDecoration(
                            labelText: context.tr('auth.register.city_label'),
                            prefixIcon: const Icon(
                              Icons.location_on_outlined,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'La Paz',
                              child: Text(
                                context.tr('auth.register.city_la_paz'),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'El Alto',
                              child: Text(
                                context.tr('auth.register.city_el_alto'),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedCity = value ?? 'La Paz');
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: AppTheme.bodyLarge,
                          decoration: InputDecoration(
                            labelText: context.tr(
                              'auth.register.password_label',
                            ),
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
                              return context.tr(
                                'auth.register.password_required',
                              );
                            }
                            if (value.length < 8) {
                              return context.tr('auth.register.password_min');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirm,
                          style: AppTheme.bodyLarge,
                          decoration: InputDecoration(
                            labelText: context.tr(
                              'auth.register.confirm_password_label',
                            ),
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: AppTheme.textSecondary,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppTheme.textSecondary,
                              ),
                              onPressed: () {
                                setState(
                                  () => _obscureConfirm = !_obscureConfirm,
                                );
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return context.tr(
                                'auth.register.confirm_password_required',
                              );
                            }
                            if (value != _passwordController.text) {
                              return context.tr(
                                'auth.register.confirm_password_mismatch',
                              );
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),
                        CustomButton(
                          text: context.tr('auth.register.submit'),
                          onPressed: _register,
                          isLoading: _isLoading,
                        ),
                        const SizedBox(height: 16),
                        CustomButton(
                          text: context.tr('auth.register.has_account'),
                          variant: ButtonVariant.outline,
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          context.tr('auth.register.terms'),
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
