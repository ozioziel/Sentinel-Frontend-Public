import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/services/app_branding_service.dart';
import 'core/services/app_theme_service.dart';
import 'core/localization/app_language_service.dart';
import 'core/navigation/app_navigator.dart';
import 'core/theme/app_design_theme.dart';
import 'core/routes/app_routes.dart';
import 'core/widgets/offline_sync_recovery_scope.dart';
import 'features/auth/presentation/screens/session_gate_screen.dart';
import 'features/emergency/presentation/widgets/emergency_alert_recovery_scope.dart';

class SentinelApp extends StatelessWidget {
  const SentinelApp({super.key});

  static final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppBrandingService.instance,
      builder: (context, _) {
        return AnimatedBuilder(
          animation: AppThemeService.instance,
          builder: (context, _) {
            return MaterialApp(
              title: AppBrandingService.instance.displayName,
              debugShowCheckedModeBanner: false,
              theme: AppThemeService.instance.currentThemeData,
              navigatorKey: AppNavigator.navigatorKey,
              scaffoldMessengerKey: _scaffoldMessengerKey,
              locale: AppLanguageService.instance.materialLocale,
              supportedLocales: AppLanguageService.supportedMaterialLocales,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) {
                return OfflineSyncRecoveryScope(
                  scaffoldMessengerKey: _scaffoldMessengerKey,
                  child: EmergencyAlertRecoveryScope(
                    scaffoldMessengerKey: _scaffoldMessengerKey,
                    child: AppDesignMotion(
                      child: child ?? const SizedBox.shrink(),
                    ),
                  ),
                );
              },
              home: const SessionGateScreen(),
              onGenerateRoute: AppRoutes.onGenerateRoute,
            );
          },
        );
      },
    );
  }
}
