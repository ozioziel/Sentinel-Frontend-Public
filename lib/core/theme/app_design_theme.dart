import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppDesignMotion extends StatefulWidget {
  final Widget child;

  const AppDesignMotion({super.key, required this.child});

  static Animation<double>? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_AppDesignMotionScope>()
        ?.animation;
  }

  @override
  State<AppDesignMotion> createState() => _AppDesignMotionState();
}

class _AppDesignMotionState extends State<AppDesignMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AppDesignMotionScope(animation: _controller, child: widget.child);
  }
}

class _AppDesignMotionScope extends InheritedNotifier<Animation<double>> {
  const _AppDesignMotionScope({
    required Animation<double> animation,
    required super.child,
  }) : super(notifier: animation);

  Animation<double> get animation => notifier!;
}

class AppFloatMotion extends StatelessWidget {
  final Widget child;
  final double amplitude;
  final double phase;

  const AppFloatMotion({
    super.key,
    required this.child,
    this.amplitude = 2.4,
    this.phase = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (amplitude == 0) {
      return child;
    }

    final animation = AppDesignMotion.maybeOf(context);
    if (animation == null) {
      return child;
    }

    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final angle = (animation.value * math.pi * 2) + phase;
        final offsetY = math.sin(angle) * amplitude;
        return Transform.translate(offset: Offset(0, offsetY), child: child);
      },
    );
  }
}

class AppDesignTheme {
  static ButtonStyle elevatedButtonStyle({
    required Color fillColor,
    required Color foregroundColor,
    required Color shadowColor,
  }) {
    return _buttonStyle(
      fillColor: fillColor,
      foregroundColor: foregroundColor,
      shadowColor: shadowColor,
      baseElevation: 12,
      pressedElevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    );
  }

  static ButtonStyle filledButtonStyle({
    required Color fillColor,
    required Color foregroundColor,
    required Color shadowColor,
  }) {
    return _buttonStyle(
      fillColor: fillColor,
      foregroundColor: foregroundColor,
      shadowColor: shadowColor,
      baseElevation: 10,
      pressedElevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    );
  }

  static ButtonStyle outlinedButtonStyle({
    required Color fillColor,
    required Color foregroundColor,
    required Color borderColor,
    required Color shadowColor,
  }) {
    return _buttonStyle(
      fillColor: fillColor,
      foregroundColor: foregroundColor,
      shadowColor: shadowColor,
      baseElevation: 8,
      pressedElevation: 4,
      fillOpacity: 0.18,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      side: BorderSide(color: borderColor, width: 1.15),
    );
  }

  static ButtonStyle textButtonStyle({
    required Color fillColor,
    required Color foregroundColor,
    required Color shadowColor,
  }) {
    return _buttonStyle(
      fillColor: fillColor,
      foregroundColor: foregroundColor,
      shadowColor: shadowColor,
      baseElevation: 5,
      pressedElevation: 2,
      fillOpacity: 0.16,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      minimumSize: const Size(0, 48),
      shape: const StadiumBorder(),
    );
  }

  static ButtonStyle iconButtonStyle({
    required Color fillColor,
    required Color foregroundColor,
    required Color borderColor,
    required Color shadowColor,
  }) {
    return _buttonStyle(
      fillColor: fillColor,
      foregroundColor: foregroundColor,
      shadowColor: shadowColor,
      baseElevation: 7,
      pressedElevation: 3,
      fillOpacity: 0.88,
      padding: const EdgeInsets.all(12),
      minimumSize: const Size(48, 48),
      shape: const CircleBorder(),
      side: BorderSide(color: borderColor, width: 1),
      iconSize: 21,
    );
  }

  static ButtonStyle _buttonStyle({
    required Color fillColor,
    required Color foregroundColor,
    required Color shadowColor,
    required OutlinedBorder shape,
    BorderSide? side,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 22,
      vertical: 16,
    ),
    Size minimumSize = const Size(0, 58),
    double fillOpacity = 1,
    double iconSize = 20,
    double baseElevation = 8,
    double pressedElevation = 4,
  }) {
    return ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return foregroundColor.withValues(alpha: 0.40);
        }
        return foregroundColor;
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        final resolved = fillColor.withValues(alpha: fillOpacity);
        if (states.contains(WidgetState.disabled)) {
          return resolved.withValues(alpha: 0.42);
        }
        return resolved;
      }),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      shadowColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return Colors.transparent;
        }

        final alpha = states.contains(WidgetState.pressed) ? 0.20 : 0.34;
        return shadowColor.withValues(alpha: alpha);
      }),
      elevation: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return 0;
        }
        if (states.contains(WidgetState.pressed)) {
          return pressedElevation;
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return baseElevation + 1.5;
        }
        return baseElevation;
      }),
      iconSize: WidgetStatePropertyAll(iconSize),
      minimumSize: WidgetStatePropertyAll(minimumSize),
      padding: WidgetStatePropertyAll(padding),
      shape: WidgetStatePropertyAll(shape),
      side: side == null
          ? null
          : WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return side.copyWith(color: side.color.withValues(alpha: 0.26));
              }
              return side;
            }),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.65,
          height: 1.0,
        ),
      ),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return foregroundColor.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return foregroundColor.withValues(alpha: 0.08);
        }
        return Colors.transparent;
      }),
    );
  }
}

class AppFloatingSurface extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final Gradient? gradient;
  final double borderRadius;
  final double amplitude;
  final double phase;
  final bool showShadow;

  const AppFloatingSurface({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,
    this.borderColor,
    this.gradient,
    this.borderRadius = 20,
    this.amplitude = 3.2,
    this.phase = 0,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fillColor = backgroundColor ?? theme.cardColor;
    final strokeColor = borderColor ?? theme.dividerColor;

    final surfaceChild = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: gradient == null ? fillColor : null,
            gradient: gradient,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: strokeColor.withValues(alpha: 0.92),
              width: 1.1,
            ),
          ),
          child: onTap == null
              ? Padding(padding: padding, child: child)
              : InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(borderRadius),
                  child: Padding(padding: padding, child: child),
                ),
        ),
      ),
    );

    final glowColor =
        Color.lerp(strokeColor, theme.colorScheme.primary, 0.28) ?? strokeColor;

    return AppFloatMotion(
      amplitude: showShadow ? amplitude : 0,
      phase: phase,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: showShadow
              ? [
                  BoxShadow(
                    color: glowColor.withValues(alpha: 0.22),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ]
              : const [],
        ),
        child: surfaceChild,
      ),
    );
  }
}
