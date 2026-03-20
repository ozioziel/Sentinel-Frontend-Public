import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';

class PanicButton extends StatefulWidget {
  final VoidCallback onActivated;

  const PanicButton({super.key, required this.onActivated});

  @override
  State<PanicButton> createState() => _PanicButtonState();
}

class _PanicButtonState extends State<PanicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _activateNow() {
    HapticFeedback.heavyImpact();
    widget.onActivated();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _activateNow,
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) {
              return Transform.scale(scale: _pulseAnim.value, child: child);
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.error.withOpacity(0.08),
                    border: Border.all(
                      color: AppTheme.error.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                ),
                Container(
                  width: 164,
                  height: 164,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.error.withOpacity(0.15),
                    border: Border.all(
                      color: AppTheme.error.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                ),
                Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [AppTheme.error, AppTheme.error.withRed(180)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.error.withOpacity(0.5),
                        blurRadius: 28,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.crisis_alert, color: Colors.white, size: 36),
                      SizedBox(height: 6),
                      Text(
                        'SOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Toca una vez para activar la alerta',
          style: AppTheme.bodyMedium.copyWith(fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
