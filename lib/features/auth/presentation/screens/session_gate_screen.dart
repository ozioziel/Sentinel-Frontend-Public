import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class SessionGateScreen extends StatefulWidget {
  const SessionGateScreen({super.key});

  @override
  State<SessionGateScreen> createState() => _SessionGateScreenState();
}

class _SessionGateScreenState extends State<SessionGateScreen> {
  late final Future<UserModel?> _sessionFuture;

  @override
  void initState() {
    super.initState();
    _sessionFuture = AuthService().getSession();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _SessionLoadingView();
        }

        if (snapshot.data != null) {
          return const HomeScreen();
        }

        return const LoginScreen();
      },
    );
  }
}

class _SessionLoadingView extends StatelessWidget {
  const _SessionLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primary),
            SizedBox(height: 16),
            Text('Cargando sesion...', style: AppTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
