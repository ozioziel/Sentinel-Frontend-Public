import 'package:flutter/material.dart';

import '../../../../core/localization/app_language_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/mascot_image.dart';

class ChatMessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final bool isTyping;

  const ChatMessageBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.isTyping = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: _MessageCard(
          label: AppLanguageService.instance.pick(
            es: 'Tu',
            en: 'You',
          ),
          text: text,
          isTyping: isTyping,
          backgroundColor: AppTheme.primary,
          borderColor: AppTheme.primaryLight,
          textColor: AppTheme.surface,
          labelColor: AppTheme.surface.withValues(alpha: 0.72),
          maxWidth: 290,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: _AssistantAvatar(isTyping: isTyping),
          ),
          _MessageCard(
            label: isTyping
                ? AppLanguageService.instance.pick(
                    es: 'Asistente escribiendo...',
                    en: 'Assistant is typing...',
                  )
                : AppLanguageService.instance.pick(
                    es: 'Asistente',
                    en: 'Assistant',
                  ),
            text: text,
            isTyping: isTyping,
            backgroundColor: AppTheme.cardBg,
            borderColor: AppTheme.divider,
            textColor: AppTheme.textPrimary,
            labelColor: AppTheme.textSecondary,
            maxWidth: 280,
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final String label;
  final String text;
  final bool isTyping;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final Color labelColor;
  final double maxWidth;

  const _MessageCard({
    required this.label,
    required this.text,
    required this.isTyping,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.labelColor,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTheme.bodyMedium.copyWith(
                color: labelColor,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            if (isTyping)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  3,
                  (index) => Container(
                    width: 8,
                    height: 8,
                    margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
                    decoration: BoxDecoration(
                      color: textColor.withValues(alpha: 0.70),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              )
            else
              Text(
                text,
                style: AppTheme.bodyLarge.copyWith(
                  color: textColor,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AssistantAvatar extends StatelessWidget {
  final bool isTyping;

  const _AssistantAvatar({required this.isTyping});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 62,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isTyping
                    ? AppTheme.primary.withValues(alpha: 0.28)
                    : AppTheme.divider,
              ),
            ),
            child: const MascotImage(
              width: 42,
              height: 42,
              padding: EdgeInsets.all(8),
              semanticsLabel: 'Mascota de apoyo',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppLanguageService.instance.pick(
              es: 'Ayuda',
              en: 'Help',
            ),
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
