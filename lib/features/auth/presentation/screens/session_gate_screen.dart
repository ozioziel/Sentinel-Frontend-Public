import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'contacts_screen.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../services/auth_service.dart';
import '../services/contacts_service.dart';
import 'login_screen.dart';

class SessionGateScreen extends StatefulWidget {
  const SessionGateScreen({super.key});

  @override
  State<SessionGateScreen> createState() => _SessionGateScreenState();
}

class _SessionGateScreenState extends State<SessionGateScreen> {
  late final Future<_SessionDestination> _destinationFuture;
  final AuthService _authService = AuthService();
  final ContactsService _contactsService = ContactsService();

  @override
  void initState() {
    super.initState();
    _destinationFuture = _resolveDestination();
  }

  Future<_SessionDestination> _resolveDestination() async {
    final session = await _authService.getSession();
    if (session == null) {
      return const _SessionDestination.login();
    }

    final hasContacts = await _contactsService.hasContacts(session.id);
    if (!hasContacts) {
      return _SessionDestination.initialContacts(session.id);
    }

    return const _SessionDestination.home();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SessionDestination>(
      future: _destinationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _SessionLoadingView();
        }

        final destination = snapshot.data;
        if (destination == null ||
            destination.kind == _SessionDestinationKind.login) {
          return const LoginScreen();
        }

        if (destination.kind == _SessionDestinationKind.initialContacts) {
          return ContactsScreen(
            userId: destination.userId!,
            isInitialSetup: true,
          );
        }

        return const HomeScreen();
      },
    );
  }
}

enum _SessionDestinationKind { login, home, initialContacts }

class _SessionDestination {
  final _SessionDestinationKind kind;
  final String? userId;

  const _SessionDestination._({required this.kind, this.userId});

  const _SessionDestination.login()
    : this._(kind: _SessionDestinationKind.login);

  const _SessionDestination.home() : this._(kind: _SessionDestinationKind.home);

  const _SessionDestination.initialContacts(String userId)
    : this._(kind: _SessionDestinationKind.initialContacts, userId: userId);
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
