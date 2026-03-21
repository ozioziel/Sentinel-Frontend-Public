import 'package:flutter/material.dart';
import '../../core/theme/app_design_theme.dart';
import '../../core/theme/app_theme.dart';

enum ButtonVariant { primary, secondary, outline, danger, ghost }

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;
  final double? height;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final w = _buildButton();
    return fullWidth ? SizedBox(width: double.infinity, child: w) : w;
  }

  Color get _bgColor {
    switch (variant) {
      case ButtonVariant.primary:
        return AppTheme.primary;
      case ButtonVariant.secondary:
        return AppTheme.cardBg;
      case ButtonVariant.outline:
        return Colors.transparent;
      case ButtonVariant.danger:
        return AppTheme.error;
      case ButtonVariant.ghost:
        return Colors.transparent;
    }
  }

  Color get _fgColor {
    switch (variant) {
      case ButtonVariant.primary:
        return AppTheme.surface;
      case ButtonVariant.danger:
        return AppTheme.textPrimary;
      case ButtonVariant.secondary:
        return AppTheme.textPrimary;
      case ButtonVariant.outline:
        return AppTheme.primary;
      case ButtonVariant.ghost:
        return AppTheme.textSecondary;
    }
  }

  BorderSide get _border {
    switch (variant) {
      case ButtonVariant.outline:
        return const BorderSide(color: AppTheme.primary, width: 1.5);
      case ButtonVariant.secondary:
        return const BorderSide(color: AppTheme.divider, width: 1);
      default:
        return BorderSide.none;
    }
  }

  Color get _shadowColor {
    switch (variant) {
      case ButtonVariant.primary:
        return AppTheme.primary;
      case ButtonVariant.danger:
        return AppTheme.error;
      case ButtonVariant.outline:
      case ButtonVariant.secondary:
        return AppTheme.secondary;
      case ButtonVariant.ghost:
        return AppTheme.primaryDark;
    }
  }

  Widget _buildButton() {
    final elevation = switch (variant) {
      ButtonVariant.primary => 12.0,
      ButtonVariant.danger => 11.0,
      ButtonVariant.secondary => 8.0,
      ButtonVariant.outline => 7.0,
      ButtonVariant.ghost => 0.0,
    };

    return AppFloatMotion(
      amplitude: elevation == 0 ? 0 : 2.2,
      phase: variant.index * 0.7,
      child: SizedBox(
        height: height ?? 50,
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: _bgColor,
            foregroundColor: _fgColor,
            disabledBackgroundColor: _bgColor.withValues(alpha: 0.45),
            disabledForegroundColor: _fgColor.withValues(alpha: 0.45),
            shadowColor: _shadowColor.withValues(alpha: 0.34),
            elevation: elevation,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: _border,
            ),
          ),
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _fgColor,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18, color: _fgColor),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      text,
                      style: AppTheme.labelLarge.copyWith(
                        fontSize: 15,
                        color: _fgColor,
                        letterSpacing: 0.65,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
