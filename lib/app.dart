import 'package:flutter/material.dart';
import 'core/services/app_branding_service.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_routes.dart';
import 'features/auth/presentation/screens/session_gate_screen.dart';

class SentinelApp extends StatelessWidget {
  const SentinelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppBrandingService.instance,
      builder: (context, _) {
        return MaterialApp(
          title: AppBrandingService.instance.displayName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: const SessionGateScreen(),
          onGenerateRoute: AppRoutes.onGenerateRoute,
        );
      },
    );
  }
}
