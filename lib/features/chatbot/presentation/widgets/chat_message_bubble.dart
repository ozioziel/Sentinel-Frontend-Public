import 'package:flutter/material.dart';

import '../../../../core/services/app_branding_service.dart';
import '../../../../core/theme/app_theme.dart';

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
    final bubbleColor = isUser ? AppTheme.primary : AppTheme.cardBg;
    final textColor = isUser ? Colors.white : AppTheme.textPrimary;
    final label = isUser
        ? 'Tu'
        : '${AppBrandingService.instance.displayName} Bot';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isUser ? AppTheme.primaryLight : AppTheme.divider,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTheme.bodyMedium.copyWith(
                  color: isUser ? Colors.white70 : AppTheme.textSecondary,
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
                        color: textColor.withValues(alpha: 0.75),
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
      ),
    );
  }
}
