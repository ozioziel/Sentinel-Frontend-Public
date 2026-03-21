import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/localization/app_language_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_card.dart';
import '../../../../shared/widgets/mascot_image.dart';

class EducationTextBlockCard extends StatelessWidget {
  final List<String> textBlocks;
  final Color color;

  const EducationTextBlockCard({
    super.key,
    required this.textBlocks,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final paragraphs = textBlocks
        .map((text) => text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    final cardSurface =
        Color.lerp(color, AppTheme.cardBg, 0.80) ?? AppTheme.cardBg;

    return CustomCard(
      backgroundColor: cardSurface,
      child: Column(
        children: [
          _MascotSpeechBubble(color: color, paragraphs: paragraphs),
          const SizedBox(height: 18),
          _CenteredMascotSpeaker(color: color),
        ],
      ),
    );
  }
}

class _MascotSpeechBubble extends StatelessWidget {
  final Color color;
  final List<String> paragraphs;

  const _MascotSpeechBubble({required this.color, required this.paragraphs});

  @override
  Widget build(BuildContext context) {
    final bubbleColor =
        Color.lerp(color, AppTheme.surface, 0.74) ?? AppTheme.surface;
    final borderColor =
        Color.lerp(color, AppTheme.primaryLight, 0.38) ?? AppTheme.primaryLight;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: borderColor.withValues(alpha: 0.30)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLanguageService.instance.pick(
                  es: 'Te lo cuento paso a paso:',
                  en: 'Let me explain it step by step:',
                ),
                style: AppTheme.titleLarge.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 12),
              for (var index = 0; index < paragraphs.length; index++) ...[
                Text(
                  paragraphs[index],
                  style: AppTheme.bodyLarge.copyWith(fontSize: 15),
                ),
                if (index != paragraphs.length - 1) const SizedBox(height: 12),
              ],
              if (paragraphs.isEmpty)
                Text(
                  AppLanguageService.instance.pick(
                    es: 'Aqui aparecera la explicacion principal de este tema.',
                    en: 'The main explanation for this topic will appear here.',
                  ),
                  style: AppTheme.bodyLarge.copyWith(fontSize: 15),
                ),
            ],
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -4),
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: bubbleColor,
                border: Border.all(color: borderColor.withValues(alpha: 0.30)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CenteredMascotSpeaker extends StatelessWidget {
  final Color color;

  const _CenteredMascotSpeaker({required this.color});

  @override
  Widget build(BuildContext context) {
    final glow = Color.lerp(color, AppTheme.primaryLight, 0.34) ?? color;

    return Container(
      width: 150,
      height: 164,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.88),
            color.withValues(alpha: 0.38),
          ],
        ),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 24,
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: glow.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const Positioned.fill(
            child: MascotImage(
              width: 118,
              height: 118,
              padding: EdgeInsets.fromLTRB(10, 16, 10, 22),
              semanticsLabel: 'Mascota educativa hablando',
            ),
          ),
          Positioned(
            bottom: 18,
            child: Text(
              AppLanguageService.instance.pick(
                es: 'Tu mascota te guia',
                en: 'Your mascot guides you',
              ),
              style: AppTheme.labelLarge.copyWith(
                color: AppTheme.textPrimary.withValues(alpha: 0.92),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
