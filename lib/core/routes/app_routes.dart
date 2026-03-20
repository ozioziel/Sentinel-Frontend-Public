import 'package:flutter/material.dart';

import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/chatbot/presentation/screens/chatbot_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String home = '/home';
  static const String emergency = '/emergency';
  static const String evidence = '/evidence';
  static const String incidents = '/incidents';
  static const String education = '/education';
  static const String directory = '/directory';
  static const String chatbot = '/chatbot';
  static const String profile = '/profile';

  static Map<String, WidgetBuilder> get routes => {
    login: (_) => const LoginScreen(),
    register: (_) => const RegisterScreen(),
    forgotPassword: (_) => const ForgotPasswordScreen(),
    home: (_) => const HomeScreen(),
    emergency: (_) => const HomeScreen(initialIndex: 0),
    evidence: (_) => const HomeScreen(initialIndex: 1),
    incidents: (_) => const HomeScreen(initialIndex: 2),
    education: (_) => const HomeScreen(initialIndex: 3),
    directory: (_) => const HomeScreen(initialIndex: 4),
    chatbot: (_) => const ChatbotScreen(),
    profile: (_) => const HomeScreen(initialIndex: 5),
  };

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final builder = routes[settings.name];
    if (builder != null) {
      return MaterialPageRoute(builder: builder, settings: settings);
    }

    return MaterialPageRoute(
      builder: (_) =>
          const Scaffold(body: Center(child: Text('Pagina no encontrada'))),
    );
  }
}
