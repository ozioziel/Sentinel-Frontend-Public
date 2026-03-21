import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_card.dart';

class EducationLibraryIntroCard extends StatelessWidget {
  final int totalTopics;
  final int visibleTopics;
  final bool isFiltering;

  const EducationLibraryIntroCard({
    super.key,
    required this.totalTopics,
    required this.visibleTopics,
    required this.isFiltering,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      padding: const EdgeInsets.all(0),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.cardBg, AppTheme.mocha],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _InfoChip(icon: Icons.menu_book_rounded, label: 'Temas claros'),
                _InfoChip(
                  icon: Icons.auto_stories_rounded,
                  label: 'Guia visual',
                ),
                _InfoChip(icon: Icons.article_outlined, label: 'Texto final'),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Aprende por temas con una vista mas directa y ligera.',
              style: AppTheme.headlineMedium.copyWith(height: 1.2),
            ),
            const SizedBox(height: 8),
            Text(
              'Cada tema abre una pantalla con explicacion visual y bloques de lectura faciles de seguir.',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textPrimary.withValues(alpha: 0.80),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    value: '$visibleTopics',
                    label: isFiltering ? 'Resultados' : 'Temas visibles',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    value: '$totalTopics',
                    label: 'Temas totales',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryLight),
          const SizedBox(width: 6),
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

class _StatTile extends StatelessWidget {
  final String value;
  final String label;

  const _StatTile({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppTheme.headlineMedium.copyWith(
              color: AppTheme.primaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textPrimary.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}
