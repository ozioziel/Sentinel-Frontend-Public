import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/localization/app_language_service.dart';
import '../../../../core/theme/app_design_theme.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_card.dart';
import '../../../auth/presentation/models/contact_model.dart';
import '../../../auth/presentation/services/auth_service.dart';
import '../../../auth/presentation/services/contacts_service.dart';
import '../services/emergency_alert_service.dart';
import '../services/emergency_backend_service.dart';
import '../services/emergency_capture_service.dart';
import '../widgets/panic_button.dart';

const String _emergencyShareMapAsset =
    'assets/images/emergency/share_location_map.png';

class EmergencyScreen extends StatefulWidget {
  final bool isEmbedded;

  const EmergencyScreen({super.key, this.isEmbedded = false});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  bool _isRecording = false;
  bool _isSendingAlert = false;
  bool _isProcessingEvidence = false;
  String _captureStatus = AppLanguageService.instance.tr(
    'emergency.capture_recording_all',
  );
  String? _processingStatus;
  String? _activeLocationUrl;
  String? _activeIncidentId;
  DateTime? _activeAlertTriggeredAt;
  Future<EmergencyIncidentResult>? _incidentCreationFuture;

  final AuthService _authService = AuthService();
  final ContactsService _contactsService = ContactsService();
  final EmergencyCaptureService _captureService = EmergencyCaptureService();
  final EmergencyAlertService _alertService = EmergencyAlertService();
  final EmergencyBackendService _backendService = EmergencyBackendService();

  String _t({
    required String es,
    required String en,
    required String ay,
    required String qu,
  }) {
    return AppLanguageService.instance.pick(es: es, en: en, ay: ay, qu: qu);
  }

  Future<void> _activateAlert() async {
    if (_isRecording) return;

    final triggeredAt = DateTime.now();

    setState(() {
      _isRecording = true;
      _captureStatus = AppLanguageService.instance.tr(
        'emergency.capture_preparing_alert',
      );
    });
    _showAlertDialog();

    final capture = await _captureService.startEmergencyCapture();
    if (!mounted) return;

    if (!capture.hasAnyAction) {
      Navigator.of(context).pop();
      setState(() => _isRecording = false);
      for (final issue in capture.issues) {
        _showSnackBar(issue);
      }
      return;
    }

    _activeLocationUrl = capture.mapsUrl;
    _activeAlertTriggeredAt = triggeredAt;

    setState(() {
      _captureStatus = _buildCaptureStatus(capture);
    });

    for (final issue in capture.issues) {
      _showSnackBar(issue);
    }

    _incidentCreationFuture = _backendService.createIncident(
      locationUrl: capture.mapsUrl,
      alertTriggeredAt: triggeredAt,
    );
    unawaited(_rememberIncidentId(_incidentCreationFuture!));
    unawaited(
      _sendEmergencyAlert(
        locationUrl: capture.mapsUrl,
        alertTriggeredAt: triggeredAt,
      ),
    );
  }

  Future<void> _deactivateAlert() async {
    if (_isProcessingEvidence) return;

    setState(() {
      _isProcessingEvidence = true;
      _processingStatus = AppLanguageService.instance.tr(
        'emergency.processing_save_close',
      );
    });

    EmergencyCaptureStopResult? stopResult;
    String? locationUrl;
    final pendingIncidentFuture = _incidentCreationFuture;
    final previousLocationUrl = _activeLocationUrl;
    final previousAlertTriggeredAt = _activeAlertTriggeredAt;
    _activeLocationUrl = null;
    _activeAlertTriggeredAt = null;
    _incidentCreationFuture = null;

    try {
      stopResult = await _captureService.stopEmergencyCapture();
      locationUrl = stopResult.mapsUrl ?? previousLocationUrl;

      if (!mounted) return;
      setState(() => _isRecording = false);

      for (final issue in stopResult.issues) {
        _showSnackBar(issue);
      }

      final hasEvidence = stopResult.attachmentPaths.isNotEmpty;

      final incidentId = await _resolveIncidentId(
        locationUrl: locationUrl,
        pendingIncidentFuture: pendingIncidentFuture,
        alertTriggeredAt: previousAlertTriggeredAt,
      );

      List<String> uploadedEvidenceIds = [];

      if (hasEvidence) {
        setState(() {
          _processingStatus = AppLanguageService.instance.tr(
            'emergency.processing_upload',
          );
        });

        final uploadResult = await _backendService.uploadEvidence(
          incidentId: incidentId,
          stopResult: stopResult,
          locationUrl: locationUrl,
        );

        uploadedEvidenceIds = uploadResult.evidenceIds;

        if (mounted && uploadResult.message != null) {
          _showSnackBar(uploadResult.message!);
        }
      }

      if (uploadedEvidenceIds.isNotEmpty) {
        setState(() {
          _processingStatus = AppLanguageService.instance.tr(
            'emergency.processing_prepare_email',
            fallback: 'Enviando correo de emergencia...',
          );
        });

        final emailResult = await _alertService.sendEvidenceEmailViaBackend(
          evidenceIds: uploadedEvidenceIds,
          alertTriggeredAt: previousAlertTriggeredAt ?? DateTime.now(),
          locationUrl: locationUrl,
          hasVideo: stopResult.videoPath != null,
          hasAudio: stopResult.audioPath != null,
        );

        if (mounted && emailResult.message != null) {
          _showSnackBar(emailResult.message!);
        }
      }
    } finally {
      _activeIncidentId = null;
      if (mounted) {
        setState(() {
          _isProcessingEvidence = false;
          _processingStatus = null;
        });
      }
    }
  }

  Future<void> _sendEmergencyAlert({
    String? locationUrl,
    DateTime? alertTriggeredAt,
  }) async {
    if (_isSendingAlert) return;

    setState(() => _isSendingAlert = true);

    try {
      final result = await _alertService.sendLocationAlert(
        locationUrl: locationUrl,
        alertTriggeredAt: alertTriggeredAt ?? _activeAlertTriggeredAt,
      );

      if (mounted && result.message != null) {
        _showSnackBar(result.message!);
      }
    } catch (_) {
      _showSnackBar(
        AppLanguageService.instance.tr('emergency.unexpected_alert_error'),
      );
    } finally {
      if (mounted) {
        setState(() => _isSendingAlert = false);
      }
    }
  }

  Future<void> _shareLocationOnly() async {
    if (_isSendingAlert) return;

    final locationUrl = await _resolveShareLocationUrl();
    if (locationUrl == null || locationUrl.isEmpty) {
      _showSnackBar(
        _t(
          es: 'No se pudo obtener la ubicacion para compartirla.',
          en: 'The location could not be fetched to share it.',
          ay: 'Ubicacion apnaqañataki janiw apsusiskaspati.',
          qu: 'Ubicacion rakinaykipaq mana tarikusqachu.',
        ),
      );
      return;
    }

    setState(() => _isSendingAlert = true);

    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          text: _buildLocationShareText(locationUrl),
          title: _t(
            es: 'Ubicacion actual',
            en: 'Current location',
            ay: 'Jichha ubicaciona',
            qu: 'Kunan pachapi ubicacion',
          ),
          subject: _t(
            es: 'Ubicacion actual',
            en: 'Current location',
            ay: 'Jichha ubicaciona',
            qu: 'Kunan pachapi ubicacion',
          ),
        ),
      );

      if (!mounted) return;
      if (result.status == ShareResultStatus.unavailable) {
        _showSnackBar(
          _t(
            es: 'No se pudo abrir el menu para compartir la ubicacion.',
            en: 'The share menu for the location could not be opened.',
            ay: 'Ubicacion apnaqañ menu janiw jist\'arañjamakiti.',
            qu: 'Ubicacion rakinapaq menuqa mana kichariyta atikurqanchu.',
          ),
        );
      } else if (result.status != ShareResultStatus.dismissed) {
        _showSnackBar(
          _t(
            es: 'Se abrio el menu para compartir la ubicacion.',
            en: 'The share menu for the location was opened.',
            ay: 'Ubicacion apnaqañ menu jist\'aratäwa.',
            qu: 'Ubicacion rakinapaq menuqa kicharisqa karqan.',
          ),
        );
      }
    } catch (_) {
      _showSnackBar(
        _t(
          es: 'No se pudo compartir la ubicacion.',
          en: 'The location could not be shared.',
          ay: 'Ubicacion apnaqañax janiw utjkiti.',
          qu: 'Ubicacion rakiyta mana atikurqanchu.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSendingAlert = false);
      }
    }
  }

  Future<void> _sendTextOnlyAlert() async {
    if (_isSendingAlert) return;

    setState(() => _isSendingAlert = true);

    try {
      final result = await _alertService.sendTextAlert(
        alertTriggeredAt: _activeAlertTriggeredAt,
      );

      if (mounted && result.message != null) {
        _showSnackBar(result.message!);
      }
    } catch (_) {
      _showSnackBar(
        AppLanguageService.instance.tr('emergency.unexpected_alert_error'),
      );
    } finally {
      if (mounted) {
        setState(() => _isSendingAlert = false);
      }
    }
  }

  Future<String?> _resolveShareLocationUrl() async {
    final activeLocationUrl = _activeLocationUrl?.trim();
    if (activeLocationUrl != null && activeLocationUrl.isNotEmpty) {
      return activeLocationUrl;
    }

    final locationResult = await _captureService.captureCurrentLocation();
    for (final issue in locationResult.issues) {
      _showSnackBar(issue);
    }

    final locationUrl = locationResult.mapsUrl?.trim();
    if (locationUrl == null || locationUrl.isEmpty) {
      return null;
    }

    if (mounted) {
      setState(() => _activeLocationUrl = locationUrl);
    } else {
      _activeLocationUrl = locationUrl;
    }

    return locationUrl;
  }

  String _buildLocationShareText(String locationUrl) {
    return _t(
      es: 'Ubicacion actual:\n$locationUrl',
      en: 'Current location:\n$locationUrl',
      ay: 'Jichha ubicaciona:\n$locationUrl',
      qu: 'Kunan pachapi ubicacion:\n$locationUrl',
    );
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
      if (mounted) {
        setState(() => _activeIncidentId = result.incidentId);
      } else {
        _activeIncidentId = result.incidentId;
      }
      if (mounted &&
          result.message != null &&
          result.message!.trim().isNotEmpty) {
        _showSnackBar(result.message!);
      }
    }
  }

  Future<String?> _resolveIncidentId({
    String? locationUrl,
    Future<EmergencyIncidentResult>? pendingIncidentFuture,
    DateTime? alertTriggeredAt,
  }) async {
    if (_activeIncidentId != null && _activeIncidentId!.isNotEmpty) {
      return _activeIncidentId;
    }

    if (pendingIncidentFuture != null) {
      final result = await pendingIncidentFuture;
      if (result.success && result.incidentId != null) {
        if (mounted) {
          setState(() => _activeIncidentId = result.incidentId);
        } else {
          _activeIncidentId = result.incidentId;
        }
        if (mounted &&
            result.message != null &&
            result.message!.trim().isNotEmpty) {
          _showSnackBar(result.message!);
        }
        return result.incidentId;
      }
    }

    final createResult = await _backendService.createIncident(
      locationUrl: locationUrl,
      alertTriggeredAt: alertTriggeredAt,
    );
    if (createResult.success && createResult.incidentId != null) {
      if (mounted) {
        setState(() => _activeIncidentId = createResult.incidentId);
      } else {
        _activeIncidentId = createResult.incidentId;
      }
      if (mounted &&
          createResult.message != null &&
          createResult.message!.trim().isNotEmpty) {
        _showSnackBar(createResult.message!);
      }
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
      return AppLanguageService.instance.tr(
        'emergency.capture_preparing_alert',
      );
    }

    return AppLanguageService.instance.tr(
      'emergency.capture_active',
      params: {'parts': parts.join(', ')},
    );
  }

  String? _incidentProgressNote() {
    if (_activeIncidentId == null || _activeIncidentId!.trim().isEmpty) {
      return null;
    }

    if (_isProcessingEvidence) {
      return _t(
        es: 'El incidente SOS ya esta listo. Ahora estamos adjuntando las evidencias registradas.',
        en: 'The SOS incident is already ready. We are now attaching the recorded evidence.',
        ay: 'SOS incidentex wakichatawa. Jichhax qillqtata evidencianak mayachasktanwa.',
        qu: 'SOS incidenteqa wakichisqanam kashan. Kunanqa qillqasqa evidenciakunatam hukllachkuchkan.',
      );
    }

    return _t(
      es: 'El incidente SOS ya fue creado. Cuando detengas la alerta, el video, el audio y la ubicacion se adjuntaran automaticamente.',
      en: 'The SOS incident has already been created. When you stop the alert, the video, audio, and location will be attached automatically.',
      ay: 'SOS incidentex niyaw lurataxi. Alerta saytayasax video, audio ukat ubicacionax automatico mayachasiniwa.',
      qu: 'SOS incidenteqa nispallam ruwasqa. Alertata sayachispaykiqa, video, audio hinaspa ubicacionqa kikillantam hukllachisqa kanqa.',
    );
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
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: AppFloatingSurface(
          borderRadius: 28,
          amplitude: 2.4,
          phase: math.pi / 4,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.cardBg.withValues(alpha: 0.98),
              AppTheme.primaryDark.withValues(alpha: 0.94),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.crisis_alert,
                      color: AppTheme.error,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr('emergency.dialog_title'),
                      style: AppTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                context.tr(
                  'emergency.dialog_body',
                  fallback:
                      'Se inicio la alerta de emergencia. Video, audio y ubicacion quedan activos mientras mantengas esta alerta. Al detenerla se preparara la evidencia para correo de emergencia o para compartirla.',
                ),
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textPrimary.withValues(alpha: 0.82),
                ),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _deactivateAlert();
                  },
                  child: Text(
                    context.tr('emergency.dialog_action'),
                    style: const TextStyle(color: AppTheme.success),
                  ),
                ),
              ),
            ],
          ),
        ),
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
    final incidentProgressNote = _incidentProgressNote();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: widget.isEmbedded
          ? AppBar(title: Text(context.tr('emergency.title_embedded')))
          : null,
      body: Stack(
        children: [
          const Positioned.fill(child: _EmergencyBackdrop()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.isEmbedded) ...[
                    _EmergencyHeroCard(
                      title: context.tr('emergency.title'),
                      subtitle: context.tr('emergency.subtitle'),
                    ),
                    const SizedBox(height: 24),
                  ],
                  // if (_isRecording || _isProcessingEvidence) ...[
                  //   AppFloatingSurface(
                  //     padding: const EdgeInsets.all(14),
                  //     borderRadius: 20,
                  //     amplitude: 2.6,
                  //     phase: math.pi / 2,
                  //     gradient: LinearGradient(
                  //       begin: Alignment.topLeft,
                  //       end: Alignment.bottomRight,
                  //       colors: [
                  //         (_isProcessingEvidence
                  //                 ? AppTheme.warning
                  //                 : AppTheme.error)
                  //             .withValues(alpha: 0.22),
                  //         AppTheme.cardBg.withValues(alpha: 0.90),
                  //       ],
                  //     ),
                  //     borderColor:
                  //         (_isProcessingEvidence
                  //                 ? AppTheme.warning
                  //                 : AppTheme.error)
                  //             .withValues(alpha: 0.55),
                  //     child: Row(
                  //       children: [
                  //         Icon(
                  //           _isProcessingEvidence
                  //               ? Icons.hourglass_top
                  //               : Icons.mic,
                  //           color: _isProcessingEvidence
                  //               ? AppTheme.warning
                  //               : AppTheme.error,
                  //           size: 18,
                  //         ),
                  //         const SizedBox(width: 10),
                  //         Expanded(
                  //           child: Column(
                  //             crossAxisAlignment: CrossAxisAlignment.start,
                  //             mainAxisSize: MainAxisSize.min,
                  //             children: [
                  //               Text(
                  //                 _isProcessingEvidence
                  //                     ? (_processingStatus ??
                  //                           context.tr(
                  //                             'emergency.processing_default',
                  //                           ))
                  //                     : _captureStatus,
                  //                 style: AppTheme.bodyMedium.copyWith(
                  //                   color: AppTheme.textPrimary.withValues(
                  //                     alpha: 0.88,
                  //                   ),
                  //                 ),
                  //               ),
                  //               if (incidentProgressNote != null) ...[
                  //                 const SizedBox(height: 4),
                  //                 Text(
                  //                   incidentProgressNote,
                  //                   style: AppTheme.bodyMedium.copyWith(
                  //                     fontSize: 12,
                  //                     color: AppTheme.textPrimary.withValues(
                  //                       alpha: 0.72,
                  //                     ),
                  //                   ),
                  //                 ),
                  //               ],
                  //             ],
                  //           ),
                  //         ),
                  //         if (_isProcessingEvidence)
                  //           const SizedBox(
                  //             width: 16,
                  //             height: 16,
                  //             child: CircularProgressIndicator(
                  //               strokeWidth: 2,
                  //               color: AppTheme.warning,
                  //             ),
                  //           )
                  //         else
                  //           Container(
                  //             width: 8,
                  //             height: 8,
                  //             decoration: const BoxDecoration(
                  //               color: AppTheme.error,
                  //               shape: BoxShape.circle,
                  //             ),
                  //           ),
                  //       ],
                  //     ),
                  //   ),
                  //   const SizedBox(height: 20),
                  // ],
                  AppFloatingSurface(
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                    borderRadius: 34,
                    amplitude: 4.1,
                    phase: math.pi / 6,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.cardBg.withValues(alpha: 0.98),
                        AppTheme.primaryDark.withValues(alpha: 0.94),
                      ],
                    ),
                    child: Column(
                      children: [
                        Center(child: PanicButton(onActivated: _activateAlert)),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: (_isRecording || _isProcessingEvidence)
                                ? null
                                : _activateAlert,
                            icon: Icon(
                              _isRecording
                                  ? Icons.shield_outlined
                                  : Icons.sos_rounded,
                            ),
                            label: Text(
                              _isRecording
                                  ? context.tr('emergency.active_button')
                                  : context.tr('emergency.activate_button'),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.error,
                              foregroundColor: AppTheme.textPrimary,
                              disabledBackgroundColor: AppTheme.error
                                  .withValues(alpha: 0.45),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _FloatingSectionBadge(
                    icon: Icons.auto_awesome_rounded,
                    label: context.tr('emergency.quick_actions'),
                    phase: math.pi / 3,
                  ),
                  const SizedBox(height: 16),
                  _EmergencyQuickActionCard(
                    title: context.tr('emergency.share_title'),
                    subtitle: context.tr(
                      'emergency.share_subtitle',
                      fallback: 'Abrir WhatsApp o compartir tu alerta',
                    ),
                    badgeIcon: (_activeLocationUrl?.trim().isNotEmpty ?? false)
                        ? Icons.gps_fixed_rounded
                        : Icons.share_location_rounded,
                    badgeLabel: (_activeLocationUrl?.trim().isNotEmpty ?? false)
                        ? 'GPS'
                        : 'SOS',
                    footerIcon: Icons.send_rounded,
                    footerLabel: 'SMS / WA',
                    actionIcon: Icons.share_location_rounded,
                    accentColor: AppTheme.error,
                    floatPhase: 0.2,
                    backgroundAsset: _emergencyShareMapAsset,
                    onTap: _shareLocationOnly,
                  ),
                  const SizedBox(height: 10),
                  _EmergencyQuickActionCard(
                    title: context.tr('emergency.record_title'),
                    subtitle: context.tr(
                      'emergency.record_subtitle',
                      fallback:
                          'La alerta SOS la registra automaticamente. Tambien puedes crear evidencias manuales desde su modulo.',
                    ),
                    badgeIcon: Icons.perm_camera_mic_rounded,
                    badgeLabel: 'VIDEO / AUDIO',
                    footerIcon: Icons.fiber_manual_record_rounded,
                    footerLabel: 'SOS AUTO',
                    actionIcon: Icons.perm_camera_mic_rounded,
                    accentColor: AppTheme.warning,
                    floatPhase: 0.9,
                    onTap: _activateAlert,
                  ),
                  const SizedBox(height: 10),
                  _EmergencyQuickActionCard(
                    title: context.tr('emergency.help_title'),
                    subtitle: context.tr(
                      'emergency.help_subtitle',
                      fallback:
                          'WhatsApp directo, SMS sin internet y reintento si vuelve la conexion',
                    ),
                    badgeIcon: Icons.send_rounded,
                    badgeLabel: 'SMS / WA',
                    footerIcon: Icons.campaign_rounded,
                    footerLabel: 'SOS',
                    actionIcon: Icons.message_rounded,
                    accentColor: AppTheme.success,
                    floatPhase: 1.5,
                    onTap: _sendTextOnlyAlert,
                  ),
                  const SizedBox(height: 24),
                  _FloatingSectionBadge(
                    icon: Icons.favorite_outline_rounded,
                    label: context.tr('emergency.contacts_title'),
                    phase: math.pi / 1.8,
                  ),
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
                          title: context.tr('emergency.contacts_empty_title'),
                          subtitle: context.tr(
                            'emergency.contacts_empty_subtitle',
                          ),
                          floatPhase: 1.1,
                          onTap: () {
                            _showSnackBar(
                              context.tr('emergency.contacts_empty_snackbar'),
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
                              title: context.tr(
                                'emergency.call_contact',
                                params: {'name': contacts[i].name},
                              ),
                              subtitle:
                                  '${contacts[i].relation} - ${contacts[i].phone}',
                              floatPhase: 1.2 + (i * 0.35),
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
                ],
              ),
            ),
          ),
          if (_isProcessingEvidence)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.42),
                child: Center(
                  child: SizedBox(
                    width: 280,
                    child: AppFloatingSurface(
                      borderRadius: 26,
                      amplitude: 2.2,
                      phase: math.pi / 5,
                      padding: const EdgeInsets.all(20),
                      backgroundColor: AppTheme.cardBg,
                      borderColor: AppTheme.divider.withValues(alpha: 0.85),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.cardBg.withValues(alpha: 0.98),
                          AppTheme.primaryDark.withValues(alpha: 0.92),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: AppTheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _processingStatus ??
                                context.tr('emergency.processing_default'),
                            style: AppTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tr('emergency.processing_wait'),
                            style: AppTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmergencyBackdrop extends StatelessWidget {
  const _EmergencyBackdrop();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Colors.black);
  }
}

class _EmergencyHeroCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmergencyHeroCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return AppFloatingSurface(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      borderRadius: 28,
      amplitude: 3.6,
      phase: 0.12,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppTheme.cardBg.withValues(alpha: 0.98),
          AppTheme.primaryDark.withValues(alpha: 0.94),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppTheme.icedMint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppTheme.icedMint.withValues(alpha: 0.20),
              ),
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: AppTheme.icedMint,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textPrimary.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingSectionBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final double phase;

  const _FloatingSectionBadge({
    required this.icon,
    required this.label,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    return AppFloatingSurface(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: 22,
      amplitude: 2.4,
      phase: phase,
      backgroundColor: AppTheme.cardBg.withValues(alpha: 0.86),
      borderColor: AppTheme.divider.withValues(alpha: 0.68),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: AppTheme.primaryLight),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: AppTheme.labelLarge.copyWith(
              fontSize: 13.5,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final double floatPhase;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.floatPhase = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: 20,
      floatPhase: floatPhase,
      floatAmplitude: 2.9,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppTheme.cardBg.withValues(alpha: 0.96),
          AppTheme.primaryDark.withValues(alpha: 0.88),
        ],
      ),
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

class _EmergencyQuickActionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData badgeIcon;
  final String badgeLabel;
  final IconData footerIcon;
  final String footerLabel;
  final IconData actionIcon;
  final Color accentColor;
  final double floatPhase;
  final VoidCallback onTap;
  final String? backgroundAsset;

  const _EmergencyQuickActionCard({
    required this.title,
    this.subtitle,
    required this.badgeIcon,
    required this.badgeLabel,
    required this.footerIcon,
    required this.footerLabel,
    required this.actionIcon,
    required this.accentColor,
    required this.floatPhase,
    required this.onTap,
    this.backgroundAsset,
  });

  @override
  Widget build(BuildContext context) {
    final hasBackgroundAsset =
        backgroundAsset != null && backgroundAsset!.trim().isNotEmpty;

    return Semantics(
      button: true,
      label: title,
      child: CustomCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        borderRadius: 30,
        floatPhase: floatPhase,
        floatAmplitude: 3.4,
        backgroundColor: AppTheme.cardBg,
        borderColor: AppTheme.divider.withValues(alpha: 0.86),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: SizedBox(
            height: 180,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasBackgroundAsset)
                  Image.asset(backgroundAsset!, fit: BoxFit.cover),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: hasBackgroundAsset
                          ? [
                              AppTheme.espressoDeep.withValues(alpha: 0.88),
                              AppTheme.espresso.withValues(alpha: 0.44),
                              accentColor.withValues(alpha: 0.22),
                            ]
                          : [
                              accentColor.withValues(alpha: 0.34),
                              AppTheme.secondary.withValues(alpha: 0.92),
                              AppTheme.espressoDeep.withValues(alpha: 0.98),
                            ],
                      stops: const [0, 0.6, 1],
                    ),
                  ),
                ),
                if (!hasBackgroundAsset) ...[
                  Positioned(
                    top: -26,
                    right: -18,
                    child: Container(
                      width: 132,
                      height: 132,
                      decoration: BoxDecoration(
                        color: AppTheme.peonySoft.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -42,
                    left: -26,
                    child: Container(
                      width: 144,
                      height: 144,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                      colors: [
                        Colors.black.withValues(alpha: 0.24),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _MapShareTag(icon: badgeIcon, label: badgeLabel),
                            const Spacer(),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 220),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.headlineMedium.copyWith(
                                      fontSize: subtitle == null ? 24 : 22,
                                      height: 0.98,
                                      color: AppTheme.textPrimary,
                                      shadows: const [
                                        Shadow(
                                          color: Color(0x66000000),
                                          blurRadius: 14,
                                          offset: Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (subtitle != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      subtitle!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTheme.bodyMedium.copyWith(
                                        fontSize: 12,
                                        height: 1.28,
                                        color: AppTheme.textPrimary.withValues(
                                          alpha: 0.82,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  _MapShareTag(
                                    icon: footerIcon,
                                    label: footerLabel,
                                    compact: true,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Align(
                        alignment: Alignment.topRight,
                        child: Container(
                          width: 78,
                          height: 78,
                          decoration: BoxDecoration(
                            color: AppTheme.peonySoft,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              actionIcon,
                              color: accentColor,
                              size: 34,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapShareTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool compact;

  const _MapShareTag({
    required this.icon,
    required this.label,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: AppTheme.espressoDeep.withValues(alpha: compact ? 0.74 : 0.62),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.peonySoft.withValues(alpha: 0.40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 15 : 16, color: AppTheme.textPrimary),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTheme.labelLarge.copyWith(
              fontSize: compact ? 10.5 : 11.5,
              color: AppTheme.textPrimary,
              letterSpacing: compact ? 0.65 : 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
