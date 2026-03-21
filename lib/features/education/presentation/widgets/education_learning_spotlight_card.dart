import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_card.dart';

class EducationLearningSpotlightCard extends StatelessWidget {
  const EducationLearningSpotlightCard({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Apartado nuevo',
                  style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text('Widget generico de apoyo', style: AppTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Panel rapido para destacar una ruta, consejo o recordatorio.',
            style: AppTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Por ahora queda como espacio flexible arriba de la mascota mientras se define el contenido final del backend.',
            style: AppTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primary.withValues(alpha: 0.18),
                  AppTheme.secondary.withValues(alpha: 0.88),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: const [
                _SpotlightPill(
                  icon: Icons.record_voice_over_rounded,
                  label: 'Consentimiento',
                ),
                _SpotlightPill(
                  icon: Icons.health_and_safety_rounded,
                  label: 'Autocuidado',
                ),
                _SpotlightPill(
                  icon: Icons.groups_rounded,
                  label: 'Apoyo seguro',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotlightPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SpotlightPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryLight),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
