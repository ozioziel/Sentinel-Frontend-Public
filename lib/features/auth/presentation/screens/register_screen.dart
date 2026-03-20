import 'package:flutter/material.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_button.dart';
import 'contacts_screen.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
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
    _nameController.dispose();
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
      helpText: 'Selecciona tu fecha de nacimiento',
    );

    if (pickedDate == null || !mounted) return;

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
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final result = await AuthService().register(
      _nameController.text.trim(),
      _phoneController.text.trim(),
      _passwordController.text.trim(),
      _selectedCity,
      _selectedBirthDate!,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: AppTheme.success,
        ),
      );

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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1A1A2E),
                  Color(0xFF16213E),
                  Color(0xFF0F3460),
                ],
              ),
            ),
          ),
          // Decorative circles
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
          // Content
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
                        // Botón volver
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
                        // Logo
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
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Crear cuenta',
                          style: AppTheme.headlineLarge.copyWith(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Completa los datos para registrarte',
                          style: AppTheme.bodyMedium.copyWith(fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 36),

                        // Nombre
                        TextFormField(
                          controller: _nameController,
                          keyboardType: TextInputType.name,
                          style: AppTheme.bodyLarge,
                          decoration: const InputDecoration(
                            labelText: 'Nombre completo',
                            prefixIcon: Icon(
                              Icons.person_outline,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Ingresa tu nombre';
                            }
                            if (v.trim().length < 3) {
                              return 'El nombre es muy corto';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Teléfono
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: AppTheme.bodyLarge,
                          decoration: const InputDecoration(
                            labelText: 'Número de WhatsApp',
                            prefixIcon: Icon(
                              Icons.phone_outlined,
                              color: AppTheme.textSecondary,
                            ),
                            hintText: '+591 7XXXXXXX',
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Ingresa tu número';
                            }
                            final digits = v.replaceAll(RegExp(r'\D'), '');
                            if (digits.length < 8) {
                              return 'Ingresa un numero valido';
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
                          decoration: const InputDecoration(
                            labelText: 'Fecha de nacimiento',
                            prefixIcon: Icon(
                              Icons.cake_outlined,
                              color: AppTheme.textSecondary,
                            ),
                            hintText: 'DD/MM/AAAA',
                          ),
                          validator: (v) {
                            if (_selectedBirthDate == null) {
                              return 'Selecciona tu fecha de nacimiento';
                            }
                            if (_selectedBirthDate!.isAfter(DateTime.now())) {
                              return 'Ingresa una fecha valida';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Ciudad
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCity,
                          dropdownColor: AppTheme.cardBg,
                          style: AppTheme.bodyLarge,
                          decoration: const InputDecoration(
                            labelText: 'Ciudad',
                            prefixIcon: Icon(
                              Icons.location_on_outlined,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'La Paz',
                              child: Text('La Paz'),
                            ),
                            DropdownMenuItem(
                              value: 'El Alto',
                              child: Text('El Alto'),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedCity = v ?? 'La Paz'),
                        ),
                        const SizedBox(height: 14),

                        // Contraseña
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: AppTheme.bodyLarge,
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
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
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Ingresa una contraseña';
                            }
                            if (v.length < 8) {
                              return 'Minimo 8 caracteres';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Confirmar contraseña
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirm,
                          style: AppTheme.bodyLarge,
                          decoration: InputDecoration(
                            labelText: 'Confirmar contraseña',
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
                              onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm,
                              ),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Confirma tu contraseña';
                            }
                            if (v != _passwordController.text) {
                              return 'Las contraseñas no coinciden';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),

                        CustomButton(
                          text: 'Crear cuenta',
                          onPressed: _register,
                          isLoading: _isLoading,
                        ),
                        const SizedBox(height: 16),
                        CustomButton(
                          text: 'Ya tengo cuenta',
                          variant: ButtonVariant.outline,
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Al registrarte, aceptas nuestros Términos\nde Servicio y Política de Privacidad.',
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
