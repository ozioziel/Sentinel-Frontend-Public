import 'package:flutter/material.dart';

import '../../../../core/localization/app_language_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_card.dart';
import '../../../../shared/widgets/mascot_image.dart';
import '../../domain/models/education_topic.dart';

class EducationTopicBanner extends StatelessWidget {
  final EducationTopic topic;

  const EducationTopicBanner({super.key, required this.topic});

  String _topicSubject() {
    final l10n = AppLanguageService.instance;

    return switch (topic.id) {
      'derechos-sexuales' => l10n.pick(
        es: 'los derechos sexuales',
        en: 'sexual rights',
      ),
      'derechos-reproductivos' => l10n.pick(
        es: 'los derechos reproductivos',
        en: 'reproductive rights',
      ),
      'prevencion-violencia' => l10n.pick(
        es: 'la prevencion de la violencia',
        en: 'violence prevention',
      ),
      'metodos-anticonceptivos' => l10n.pick(
        es: 'los metodos anticonceptivos',
        en: 'contraceptive methods',
      ),
      'riesgo' => l10n.pick(
        es: 'que hacer si estas en riesgo',
        en: 'what to do if you are at risk',
      ),
      'despues' => l10n.pick(
        es: 'que hacer despues de una situacion de violencia',
        en: 'what to do after a violent situation',
      ),
      _ => topic.title.toLowerCase(),
    };
  }

  String _introMessage() {
    final subject = _topicSubject();

    return AppLanguageService.instance.pick(
      es: 'Hola, vas a aprender sobre $subject.',
      en: 'Hi, you are going to learn about $subject.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final bannerSurface =
        Color.lerp(topic.color, AppTheme.cardBg, 0.78) ?? AppTheme.cardBg;

    return CustomCard(
      padding: const EdgeInsets.all(0),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              topic.color.withValues(alpha: 0.30),
              bannerSurface,
              AppTheme.cardBg,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MascotBadge(color: topic.color),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _ThoughtBubble(
                      color: topic.color,
                      text: _introMessage(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(topic.title, style: AppTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(topic.description, style: AppTheme.bodyLarge),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: topic.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: topic.color.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Text(
                    topic.tag,
                    style: TextStyle(
                      color: topic.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _MiniPill(
                  icon: Icons.play_circle_outline_rounded,
                  label: context.tr('education.detail.video_chip'),
                ),
                _MiniPill(
                  icon: Icons.auto_stories_rounded,
                  label: context.tr('education.detail.image_chip'),
                ),
                _MiniPill(
                  icon: Icons.article_outlined,
                  label: context.tr('education.detail.text_chip'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MascotBadge extends StatelessWidget {
  final Color color;

  const _MascotBadge({required this.color});

  @override
  Widget build(BuildContext context) {
    final glow = Color.lerp(color, AppTheme.primaryLight, 0.34) ?? color;

    return Container(
      width: 94,
      height: 112,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.88),
            color.withValues(alpha: 0.42),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 16,
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: glow.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const Positioned.fill(
            child: MascotImage(
              width: 84,
              height: 84,
              padding: EdgeInsets.fromLTRB(6, 8, 6, 14),
              semanticsLabel: 'Mascota educativa',
            ),
          ),
          Positioned(
            top: 16,
            right: 12,
            child: Icon(Icons.auto_awesome_rounded, color: glow, size: 17),
          ),
        ],
      ),
    );
  }
}

class _ThoughtBubble extends StatelessWidget {
  final Color color;
  final String text;

  const _ThoughtBubble({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    final bubbleColor =
        Color.lerp(color, AppTheme.surface, 0.70) ?? AppTheme.surface;
    final borderColor =
        Color.lerp(color, AppTheme.primaryLight, 0.36) ?? AppTheme.primaryLight;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor.withValues(alpha: 0.30)),
          ),
          child: Text(
            text,
            style: AppTheme.titleLarge.copyWith(fontSize: 17, height: 1.25),
          ),
        ),
        Positioned(
          left: -12,
          bottom: 18,
          child: _ThoughtDot(
            size: 14,
            color: bubbleColor,
            borderColor: borderColor,
          ),
        ),
        Positioned(
          left: -4,
          bottom: 34,
          child: _ThoughtDot(
            size: 9,
            color: bubbleColor,
            borderColor: borderColor,
          ),
        ),
      ],
    );
  }
}

class _ThoughtDot extends StatelessWidget {
  final double size;
  final Color color;
  final Color borderColor;

  const _ThoughtDot({
    required this.size,
    required this.color,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor.withValues(alpha: 0.26)),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: AppTheme.bodyMedium),
        ],
      ),
    );
  }
}
