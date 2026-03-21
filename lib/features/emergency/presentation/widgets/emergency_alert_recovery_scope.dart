import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../services/emergency_alert_service.dart';

class EmergencyAlertRecoveryScope extends StatefulWidget {
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;
  final Widget child;

  const EmergencyAlertRecoveryScope({
    super.key,
    required this.scaffoldMessengerKey,
    required this.child,
  });

  @override
  State<EmergencyAlertRecoveryScope> createState() =>
      _EmergencyAlertRecoveryScopeState();
}

class _EmergencyAlertRecoveryScopeState
    extends State<EmergencyAlertRecoveryScope>
    with WidgetsBindingObserver {
  final EmergencyAlertService _alertService = EmergencyAlertService();
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<dynamic>? _connectivitySubscription;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (dynamic result) {
        if (_hasActiveConnection(result)) {
          unawaited(_retryPendingAlert());
        }
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_retryPendingAlert());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_retryPendingAlert());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _retryPendingAlert() async {
    if (_isRetrying) {
      return;
    }

    _isRetrying = true;
    try {
      final result = await _alertService.retryPendingAlert();
      final message = result?.message;
      if (message == null || message.trim().isEmpty) {
        return;
      }

      final messenger = widget.scaffoldMessengerKey.currentState;
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } finally {
      _isRetrying = false;
    }
  }

  bool _hasActiveConnection(dynamic result) {
    if (result is List<ConnectivityResult>) {
      return result.any((item) => item != ConnectivityResult.none);
    }

    if (result is ConnectivityResult) {
      return result != ConnectivityResult.none;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
