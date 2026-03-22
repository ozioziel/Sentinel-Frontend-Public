import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../services/offline_sync_service.dart';

class OfflineSyncRecoveryScope extends StatefulWidget {
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;
  final Widget child;

  const OfflineSyncRecoveryScope({
    super.key,
    required this.scaffoldMessengerKey,
    required this.child,
  });

  @override
  State<OfflineSyncRecoveryScope> createState() =>
      _OfflineSyncRecoveryScopeState();
}

class _OfflineSyncRecoveryScopeState extends State<OfflineSyncRecoveryScope>
    with WidgetsBindingObserver {
  final OfflineSyncService _offlineSyncService = OfflineSyncService.instance;
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<dynamic>? _connectivitySubscription;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      dynamic result,
    ) {
      if (_hasActiveConnection(result)) {
        unawaited(_retryPendingOperations());
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_retryPendingOperations());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_retryPendingOperations());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _retryPendingOperations() async {
    if (_isSyncing) {
      return;
    }

    _isSyncing = true;
    try {
      final result = await _offlineSyncService.retryPendingOperations();
      final message = result?.message;
      if (message == null || message.trim().isEmpty) {
        return;
      }

      final messenger = widget.scaffoldMessengerKey.currentState;
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } finally {
      _isSyncing = false;
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
