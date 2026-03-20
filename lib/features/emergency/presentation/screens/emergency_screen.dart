import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_card.dart';
import '../../../auth/presentation/services/auth_service.dart';
import '../../../auth/presentation/services/contacts_service.dart';
import '../services/emergency_alert_service.dart';
import '../services/emergency_backend_service.dart';
import '../services/emergency_capture_service.dart';
import '../widgets/panic_button.dart';

class EmergencyScreen extends StatefulWidget {
  final bool isEmbedded;

  const EmergencyScreen({super.key, this.isEmbedded = false});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  bool _isRecording = false;
  bool _isSendingAlert = false;
  String _captureStatus = 'Grabando video, audio y ubicacion...';
  String? _activeLocationUrl;
  String? _activeIncidentId;
  Future<EmergencyIncidentResult>? _incidentCreationFuture;

  final AuthService _authService = AuthService();
  final ContactsService _contactsService = ContactsService();
  final EmergencyCaptureService _captureService = EmergencyCaptureService();
  final EmergencyAlertService _alertService = EmergencyAlertService();
  final EmergencyBackendService _backendService = EmergencyBackendService();

  Future<void> _activateAlert() async {
    if (_isRecording) return;

    final capture = await _captureService.startEmergencyCapture();
    if (!mounted) return;

    if (!capture.hasAnyAction) {
      for (final issue in capture.issues) {
        _showSnackBar(issue);
      }
      return;
    }

    _activeLocationUrl = capture.mapsUrl;

    setState(() {
      _isRecording = true;
      _captureStatus = _buildCaptureStatus(capture);
    });

    for (final issue in capture.issues) {
      _showSnackBar(issue);
    }

    _incidentCreationFuture = _backendService.createIncident(
      locationUrl: capture.mapsUrl,
    );
    unawaited(_rememberIncidentId(_incidentCreationFuture!));
    unawaited(_sendEmergencyAlert(locationUrl: capture.mapsUrl));
    _showAlertDialog();
  }

  Future<void> _deactivateAlert() async {
    final stopResult = await _captureService.stopEmergencyCapture();
    final locationUrl = stopResult.mapsUrl ?? _activeLocationUrl;
    final pendingIncidentFuture = _incidentCreationFuture;
    _activeLocationUrl = null;
    _incidentCreationFuture = null;

    if (!mounted) return;
    setState(() => _isRecording = false);

    for (final issue in stopResult.issues) {
      _showSnackBar(issue);
    }

    final incidentId = await _resolveIncidentId(
      locationUrl: locationUrl,
      pendingIncidentFuture: pendingIncidentFuture,
    );

    if (incidentId != null) {
      final uploadResult = await _backendService.uploadEvidence(
        incidentId: incidentId,
        stopResult: stopResult,
        locationUrl: locationUrl,
      );

      if (mounted && uploadResult.message != null) {
        _showSnackBar(uploadResult.message!);
      }
    }

    final shareResult = await _alertService.shareEvidence(
      stopResult: stopResult,
      locationUrl: locationUrl,
    );

    if (mounted && shareResult.message != null) {
      _showSnackBar(shareResult.message!);
    }

    _activeIncidentId = null;
  }

  Future<void> _sendEmergencyAlert({String? locationUrl}) async {
    if (_isSendingAlert) return;

    setState(() => _isSendingAlert = true);

    try {
      final result = await _alertService.sendLocationAlert(
        locationUrl: locationUrl,
      );

      if (mounted && result.message != null) {
        _showSnackBar(result.message!);
      }
    } catch (_) {
      _showSnackBar('Ocurrio un error al preparar la alerta.');
    } finally {
      if (mounted) {
        setState(() => _isSendingAlert = false);
      }
    }
  }

  Future<void> _callEmergencyContact(ContactModel contact) async {
    final result = await _alertService.callEmergencyContact(contact);
    if (mounted && result.message != null) {
      _showSnackBar(result.message!);
    }
  }

  Future<void> _rememberIncidentId(
    Future<EmergencyIncidentResult> incidentFuture,
  ) async {
    final result = await incidentFuture;
    if (_incidentCreationFuture != incidentFuture) return;

    if (result.success && result.incidentId != null) {
      _activeIncidentId = result.incidentId;
    }
  }

  Future<String?> _resolveIncidentId({
    String? locationUrl,
    Future<EmergencyIncidentResult>? pendingIncidentFuture,
  }) async {
    if (_activeIncidentId != null && _activeIncidentId!.isNotEmpty) {
      return _activeIncidentId;
    }

    if (pendingIncidentFuture != null) {
      final result = await pendingIncidentFuture;
      if (result.success && result.incidentId != null) {
        _activeIncidentId = result.incidentId;
        return result.incidentId;
      }
    }

    final createResult = await _backendService.createIncident(
      locationUrl: locationUrl,
    );
    if (createResult.success && createResult.incidentId != null) {
      _activeIncidentId = createResult.incidentId;
      return createResult.incidentId;
    }

    if (mounted && createResult.message != null) {
      _showSnackBar(createResult.message!);
    }

    return null;
  }

  Future<List<ContactModel>> _loadEmergencyContacts() async {
    final user = await _authService.getSession();
    if (user == null) return [];
    return _contactsService.getContacts(user.id);
  }

  String _buildCaptureStatus(EmergencyCaptureResult capture) {
    final parts = <String>[];
    if (capture.videoStarted) parts.add('video');
    if (capture.audioStarted) parts.add('audio');
    if (capture.position != null) parts.add('ubicacion');

    if (parts.isEmpty) {
      return 'Preparando alerta de emergencia...';
    }

    return 'Activa: ${parts.join(', ')}';
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showAlertDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.crisis_alert,
                color: AppTheme.error,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Alerta activada', style: AppTheme.titleLarge),
          ],
        ),
        content: Text(
          'Se inicio la alerta de emergencia. Video, audio y ubicacion quedan activos mientras mantengas esta alerta. Al detenerla se preparara la evidencia para compartir.',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deactivateAlert();
            },
            child: const Text(
              'Detener y compartir',
              style: TextStyle(color: AppTheme.success),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_captureService.stopEmergencyCapture());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: widget.isEmbedded
          ? AppBar(title: const Text('Alerta de Emergencia'))
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.isEmbedded) ...[
                const SizedBox(height: 24),
                Text('Emergencia', style: AppTheme.headlineLarge),
                const SizedBox(height: 6),
                Text('Alerta rapida y segura', style: AppTheme.bodyMedium),
              ],
              const SizedBox(height: 32),
              if (_isRecording)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.mic, color: AppTheme.error, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _captureStatus,
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.error,
                          ),
                        ),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              Center(child: PanicButton(onActivated: _activateAlert)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isRecording ? null : _activateAlert,
                  icon: Icon(
                    _isRecording ? Icons.shield_outlined : Icons.sos_rounded,
                  ),
                  label: Text(
                    _isRecording ? 'Alerta activa' : 'Activar alerta',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    disabledBackgroundColor: AppTheme.error.withValues(
                      alpha: 0.45,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              const Divider(color: AppTheme.divider),
              const SizedBox(height: 24),
              Text('Acciones rapidas', style: AppTheme.titleLarge),
              const SizedBox(height: 16),
              _ActionCard(
                icon: Icons.share_location_rounded,
                iconColor: const Color(0xFF2196F3),
                title: 'Compartir ubicacion',
                subtitle: 'Abrir WhatsApp o compartir tu alerta',
                onTap: () =>
                    _sendEmergencyAlert(locationUrl: _activeLocationUrl),
              ),
              const SizedBox(height: 10),
              _ActionCard(
                icon: Icons.mic_rounded,
                iconColor: AppTheme.error,
                title: 'Grabar evidencia',
                subtitle: 'Se activa automaticamente con el boton SOS',
                onTap: _activateAlert,
              ),
              const SizedBox(height: 10),
              _ActionCard(
                icon: Icons.message_rounded,
                iconColor: AppTheme.success,
                title: 'Mensaje de auxilio',
                subtitle: 'WhatsApp directo o compartir con varios contactos',
                onTap: () =>
                    _sendEmergencyAlert(locationUrl: _activeLocationUrl),
              ),
              const SizedBox(height: 24),
              Text('Contactos de emergencia', style: AppTheme.titleLarge),
              const SizedBox(height: 12),
              FutureBuilder<List<ContactModel>>(
                future: _loadEmergencyContacts(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primary,
                        ),
                      ),
                    );
                  }

                  final contacts = snapshot.data ?? const <ContactModel>[];

                  if (contacts.isEmpty) {
                    return _ActionCard(
                      icon: Icons.people_outline_rounded,
                      iconColor: AppTheme.warning,
                      title: 'Sin contactos de emergencia',
                      subtitle:
                          'Agrega contactos en tu perfil para poder llamarlos desde aqui',
                      onTap: () {
                        _showSnackBar(
                          'No tienes contactos de emergencia configurados.',
                        );
                      },
                    );
                  }

                  return Column(
                    children: [
                      for (var i = 0; i < contacts.length; i++) ...[
                        _ActionCard(
                          icon: Icons.phone_in_talk_rounded,
                          iconColor: AppTheme.warning,
                          title: 'Llamar a ${contacts[i].name}',
                          subtitle:
                              '${contacts[i].relation} - ${contacts[i].phone}',
                          onTap: () {
                            unawaited(_callEmergencyContact(contacts[i]));
                          },
                        ),
                        if (i != contacts.length - 1)
                          const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.labelLarge),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: AppTheme.bodyMedium.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: AppTheme.textSecondary,
          ),
        ],
      ),
    );
  }
}
