import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/localization/app_language_service.dart';
import '../../core/theme/app_design_theme.dart';
import '../../core/theme/app_theme.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNav({super.key, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: AppFloatingSurface(
          padding: EdgeInsets.zero,
          borderRadius: 30,
          amplitude: 2.8,
          phase: math.pi / 2,
          backgroundColor: AppTheme.cardBg.withValues(alpha: 0.96),
          borderColor: AppTheme.primary.withValues(alpha: 0.20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.cardBg.withValues(alpha: 0.98),
              AppTheme.primaryDark.withValues(alpha: 0.94),
            ],
          ),
          child: NavigationBar(
            height: 76,
            selectedIndex: currentIndex,
            onDestinationSelected: onTap,
            backgroundColor: Colors.transparent,
            indicatorColor: AppTheme.primary.withValues(alpha: 0.18),
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.crisis_alert_outlined),
                selectedIcon: const Icon(Icons.crisis_alert),
                label: context.tr('navigation.alert'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.folder_copy_outlined),
                selectedIcon: const Icon(Icons.folder_copy),
                label: context.tr('navigation.evidence'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.description_outlined),
                selectedIcon: const Icon(Icons.description),
                label: context.tr('navigation.incidents'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.menu_book_outlined),
                selectedIcon: const Icon(Icons.menu_book),
                label: context.tr('navigation.learn'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.location_on_outlined),
                selectedIcon: const Icon(Icons.location_on),
                label: context.tr('navigation.directory'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline),
                selectedIcon: const Icon(Icons.person),
                label: context.tr('navigation.profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
