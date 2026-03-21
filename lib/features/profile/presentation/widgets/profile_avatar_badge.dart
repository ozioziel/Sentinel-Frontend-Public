import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../models/profile_avatar_option.dart';

class ProfileAvatarBadge extends StatelessWidget {
  final ProfileAvatarOption option;
  final double size;
  final double borderRadius;
  final double iconSize;

  const ProfileAvatarBadge({
    super.key,
    required this.option,
    this.size = 84,
    this.borderRadius = 28,
    this.iconSize = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [option.startColor, option.endColor],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: option.startColor.withValues(alpha: 0.34),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(option.icon, color: AppTheme.textPrimary, size: iconSize),
    );
  }
}
