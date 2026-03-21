import 'package:flutter/material.dart';

import '../../../../core/localization/app_language_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_card.dart';
import '../../domain/models/education_story_panel.dart';

class EducationStoryPanelCard extends StatelessWidget {
  final EducationStoryPanel panel;
  final int index;

  const EducationStoryPanelCard({
    super.key,
    required this.panel,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage =
        panel.imageAssetPath != null && panel.imageAssetPath!.trim().isNotEmpty;

    return CustomCard(
      padding: const EdgeInsets.all(16),
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
                  color: panel.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  index == 0
                      ? context.tr('education.detail.main_comic')
                      : context.tr(
                          'education.detail.step',
                          params: {'number': '${index + 1}'},
                        ),
                  style: TextStyle(
                    color: panel.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(panel.eyebrow, style: AppTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 14),
          if (hasImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                color: panel.color.withValues(alpha: 0.08),
                child: Image.asset(
                  panel.imageAssetPath!,
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                  semanticLabel: panel.imageSemanticLabel ?? panel.title,
                  errorBuilder: (context, error, stackTrace) {
                    return _VisualPlaceholder(panel: panel);
                  },
                ),
              ),
            )
          else
            _VisualPlaceholder(panel: panel),
          const SizedBox(height: 16),
          Text(panel.title, style: AppTheme.titleLarge),
          const SizedBox(height: 8),
          Text(panel.caption, style: AppTheme.bodyLarge.copyWith(fontSize: 15)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.34),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Text(panel.footer, style: AppTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _VisualPlaceholder extends StatelessWidget {
  final EducationStoryPanel panel;

  const _VisualPlaceholder({required this.panel});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 5 / 4,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                panel.color.withValues(alpha: 0.90),
                panel.color.withValues(alpha: 0.35),
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -24,
                right: -12,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                bottom: -20,
                left: -10,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryDark.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                left: 16,
                bottom: 16,
                child: Container(
                  width: 92,
                  height: 118,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryDark.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppTheme.primaryLight.withValues(alpha: 0.20),
                    ),
                  ),
                  child: Icon(
                    panel.icon,
                    size: 42,
                    color: AppTheme.textPrimary.withValues(alpha: 0.94),
                  ),
                ),
              ),
              Positioned(
                top: 18,
                left: 118,
                right: 16,
                child: _ComicBubble(text: panel.bubbleText),
              ),
              Positioned(
                right: 16,
                bottom: 18,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryDark.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppTheme.primaryLight.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(panel.icon, size: 15, color: AppTheme.textPrimary),
                      const SizedBox(width: 6),
                      Text(
                        context.tr('education.detail.visual_space'),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComicBubble extends StatelessWidget {
  final String text;

  const _ComicBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.textPrimary.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryLight.withValues(alpha: 0.14),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.secondary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          height: 1.25,
        ),
      ),
    );
  }
}
