import 'dart:io';

import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

import '../../../../core/localization/app_language_service.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/services/app_branding_service.dart';
import '../../../auth/presentation/services/auth_service.dart';
import '../../../evidence/presentation/services/evidence_service.dart';
import '../../../incidents/domain/models/incident_record.dart';
import '../../../incidents/presentation/services/incident_service.dart';
import 'emergency_capture_service.dart';

class EmergencyIncidentResult {
  final bool success;
  final String? incidentId;
  final String? message;

  const EmergencyIncidentResult({
    required this.success,
    this.incidentId,
    this.message,
  });
}

class EmergencyEvidenceUploadResult {
  final bool success;
  final int uploadedCount;
  final List<String> evidenceIds;
  final String? message;

  const EmergencyEvidenceUploadResult({
    required this.success,
    required this.uploadedCount,
    this.evidenceIds = const [],
    this.message,
  });
}

class EmergencyBackendService {
  final AuthService _authService;
  final ApiClient _apiClient;
  final EvidenceService _evidenceService;
  final IncidentService _incidentService;

  EmergencyBackendService({
    AuthService? authService,
    ApiClient? apiClient,
    EvidenceService? evidenceService,
    IncidentService? incidentService,
  }) : _authService = authService ?? AuthService(),
       _apiClient = apiClient ?? ApiClient(),
       _evidenceService = evidenceService ?? EvidenceService(),
       _incidentService = incidentService ?? IncidentService();

  String _t({
    required String es,
    required String en,
    required String ay,
    required String qu,
  }) {
    return AppLanguageService.instance.pick(
      es: es,
      en: en,
      ay: ay,
      qu: qu,
    );
  }

  Future<EmergencyIncidentResult> createIncident({
    String? locationUrl,
    DateTime? alertTriggeredAt,
  }) async {
    final user = await _authService.getSession();
    if (user == null) {
      return EmergencyIncidentResult(
        success: false,
        message: _t(
          es: 'No hay una sesion activa para registrar la alerta.',
          en: 'There is no active session to register the alert.',
          ay: 'Janiw alerta qillqantatanakax sesion activa utjkiti.',
          qu: 'Alerta qillqanapaq sesion activaqa mana kanchu.',
        ),
      );
    }

    final triggeredAt = alertTriggeredAt ?? DateTime.now();
    final incidentTitle = _t(
      es: 'Alerta SOS',
      en: 'SOS Alert',
      ay: 'SOS Alerta',
      qu: 'SOS Alerta',
    );
    final incidentDescription = _buildIncidentDescription(
      locationUrl,
      alertTriggeredAt: triggeredAt,
    );
    final incidentDate = triggeredAt.toUtc().toIso8601String();
    final incidentDraft = IncidentRecord(
      id: '',
      title: incidentTitle,
      description: incidentDescription,
      type: 'sos',
      status: 'registrado',
      riskLevel: 'critico',
      location: locationUrl ?? '',
      occurredAt: incidentDate,
    );

    try {
      final response = await _apiClient.postJson(
        '/incidents',
        accessToken: user.accessToken,
        body: {
          'titulo': incidentTitle,
          'descripcion': incidentDescription,
          'tipo_incidente': 'sos',
          'fecha_incidente': incidentDate,
          'lugar': locationUrl,
          'nivel_riesgo': 'critico',
          'estado': 'registrado',
        },
      );

      final createdIncident =
          _extractIncidentDetail(response) ?? incidentDraft;
      final storedIncident = createdIncident.id.trim().isEmpty
          ? incidentDraft.copyWith(id: _buildLocalIncidentId())
          : createdIncident;

      await _incidentService.upsertCachedIncident(
        userId: user.id,
        incident: storedIncident,
      );

      if (createdIncident.id.trim().isEmpty) {
        return EmergencyIncidentResult(
          success: true,
          incidentId: storedIncident.id,
          message: _t(
            es:
                'La alerta SOS se guardo localmente porque el servidor no devolvio un incidente valido.',
            en:
                'The SOS alert was saved locally because the server did not return a valid incident.',
            ay:
                'SOS alertax localan imatawa kunatix servidorax janiw valido incidente kuttaykiti.',
            qu:
                'SOS alertaqa localpim waqaychasqa karqan, servidorqa mana allin incidente kutichirqanchu.',
          ),
        );
      }

      return EmergencyIncidentResult(
        success: true,
        incidentId: storedIncident.id,
      );
    } on ApiException catch (error) {
      final localIncident = incidentDraft.copyWith(id: _buildLocalIncidentId());
      await _incidentService.upsertCachedIncident(
        userId: user.id,
        incident: localIncident,
      );

      return EmergencyIncidentResult(
        success: true,
        incidentId: localIncident.id,
        message: _buildLocalIncidentFallbackMessage(error),
      );
    } catch (_) {
      final localIncident = incidentDraft.copyWith(id: _buildLocalIncidentId());
      await _incidentService.upsertCachedIncident(
        userId: user.id,
        incident: localIncident,
      );

      return EmergencyIncidentResult(
        success: true,
        incidentId: localIncident.id,
        message: _t(
          es:
              'La alerta SOS se guardo localmente en este dispositivo mientras vuelve la conexion con el servidor.',
          en:
              'The SOS alert was saved locally on this device while the server connection returns.',
          ay:
              'SOS alertax aka dispositivon localan imatawa servidorampi mayachasiy kutinipkama.',
          qu:
              'SOS alertaqa kay dispositivopi localpim waqaychasqa karqan servidorman tinkanakuy kutimunankama.',
        ),
      );
    }
  }

  Future<EmergencyEvidenceUploadResult> uploadEvidence({
    required String? incidentId,
    required EmergencyCaptureStopResult stopResult,
    String? locationUrl,
  }) async {
    final attachmentPaths = stopResult.attachmentPaths;
    if (attachmentPaths.isEmpty) {
      return EmergencyEvidenceUploadResult(
        success: false,
        uploadedCount: 0,
        message: _t(
          es: 'No habia archivos para subir al servidor.',
          en: 'There were no files to upload to the server.',
          ay: 'Janiw servidorar apkatanatakix archivos utjkiti.',
          qu: 'Servidorman wicharinapaq archivosqa mana karqanchu.',
        ),
      );
    }

    final user = await _authService.getSession();
    if (user == null) {
      return EmergencyEvidenceUploadResult(
        success: false,
        uploadedCount: 0,
        message: _t(
          es: 'No hay una sesion activa para subir evidencia.',
          en: 'There is no active session to upload evidence.',
          ay: 'Janiw evidencia apkatanatakix sesion activa utjkiti.',
          qu: 'Evidencia wicharinapaq sesion activaqa mana kanchu.',
        ),
      );
    }

    var uploadedCount = 0;
    final issues = <String>[];
    final evidenceIds = <String>[];

    for (final filePath in attachmentPaths) {
      final file = File(filePath);
      if (!await file.exists()) {
        issues.add(
          _t(
            es: 'No se encontro ${p.basename(filePath)}.',
            en: '${p.basename(filePath)} was not found.',
            ay: '${p.basename(filePath)} janiw jikxataskiti.',
            qu: '${p.basename(filePath)} mana tarikurqanchu.',
          ),
        );
        continue;
      }

      final mimeType = lookupMimeType(filePath) ?? _fallbackMimeType(filePath);
      final evidenceType = _inferEvidenceType(mimeType);
      if (mimeType == null || evidenceType == null) {
        issues.add(
          _t(
            es: 'No se pudo reconocer el tipo de ${p.basename(filePath)}.',
            en: 'The type of ${p.basename(filePath)} could not be recognized.',
            ay: '${p.basename(filePath)} ukax kuna kasta uk janiw untayaskiti.',
            qu:
                '${p.basename(filePath)} ima kastachus mana reqsiyta atikurqanchu.',
          ),
        );
        continue;
      }

      try {
        final takenAt = await file.lastModified();
        final evidenceTitle = _buildEvidenceTitle(evidenceType);
        final evidenceDescription = _buildEvidenceDescription(
          evidenceType: evidenceType,
          locationUrl: locationUrl,
        );
        final createResult = await _evidenceService.createEvidence(
          filePath: filePath,
          selectedType: evidenceType,
          title: evidenceTitle,
          description: evidenceDescription,
          takenAt: takenAt,
          isPrivate: true,
        );

        if (!createResult.success || createResult.evidence == null) {
          issues.add('${p.basename(filePath)}: ${createResult.message}');
          continue;
        }

        var storedEvidence = createResult.evidence!;
        uploadedCount++;
        if (storedEvidence.id.trim().isNotEmpty) {
          evidenceIds.add(storedEvidence.id);
        }

        if (incidentId != null && incidentId.trim().isNotEmpty) {
          final associationResult = await _evidenceService
              .updateEvidenceIncident(
                evidence: storedEvidence,
                incidentId: incidentId,
              );
          if (associationResult.success && associationResult.evidence != null) {
            storedEvidence = associationResult.evidence!;
          } else {
            issues.add(
              _t(
                es:
                    '${p.basename(filePath)} se subio, pero no se pudo asociar al incidente.',
                en:
                    '${p.basename(filePath)} was uploaded, but it could not be linked to the incident.',
                ay:
                    '${p.basename(filePath)} apkatawa, ukampis janiw incidenter mayachatanjamakiti.',
                qu:
                    '${p.basename(filePath)} wicharisqa karqan, ichaqa incidentewan mana tinkanachiyta atikurqanchu.',
              ),
            );
          }
        }

        await _evidenceService.upsertCachedEvidence(
          userId: user.id,
          evidence: storedEvidence.copyWith(
            title: evidenceTitle,
            description: evidenceDescription,
          ),
        );
      } catch (_) {
        issues.add(
          _t(
            es: 'No se pudo subir ${p.basename(filePath)}.',
            en: '${p.basename(filePath)} could not be uploaded.',
            ay: 'Janiw ${p.basename(filePath)} apkatanjamakiti.',
            qu: '${p.basename(filePath)} mana wichariyta atikurqanchu.',
          ),
        );
      }
    }

    return EmergencyEvidenceUploadResult(
      success: uploadedCount > 0,
      uploadedCount: uploadedCount,
      evidenceIds: evidenceIds,
      message: _buildUploadMessage(
        uploadedCount: uploadedCount,
        issues: issues,
      ),
    );
  }

  String _buildIncidentDescription(
    String? locationUrl, {
    required DateTime alertTriggeredAt,
  }) {
    final appName = AppBrandingService.instance.displayName;
    final formattedTimestamp = _formatAlertTimestamp(alertTriggeredAt);
    if (locationUrl == null || locationUrl.trim().isEmpty) {
      return _t(
        es:
            'Alerta SOS activada desde la app $appName. Fecha y hora: $formattedTimestamp.',
        en:
            'SOS alert activated from the $appName app. Date and time: $formattedTimestamp.',
        ay:
            '$appName app tuqit SOS alertax activatawa. Uru ukat hora: $formattedTimestamp.',
        qu:
            '$appName appmanta SOS alerta qallarichisqa karqan. Punchawwan horawan: $formattedTimestamp.',
      );
    }

    return _t(
      es:
          'Alerta SOS activada desde la app $appName. Fecha y hora: $formattedTimestamp. Ubicacion reportada: $locationUrl',
      en:
          'SOS alert activated from the $appName app. Date and time: $formattedTimestamp. Reported location: $locationUrl',
      ay:
          '$appName app tuqit SOS alertax activatawa. Uru ukat hora: $formattedTimestamp. Yatiyata ubicacion: $locationUrl',
      qu:
          '$appName appmanta SOS alerta qallarichisqa karqan. Punchawwan horawan: $formattedTimestamp. Willasqa ubicacion: $locationUrl',
    );
  }

  String _buildEvidenceTitle(String evidenceType) {
    switch (evidenceType) {
      case 'video':
        return _t(
          es: 'Video SOS',
          en: 'SOS Video',
          ay: 'SOS Video',
          qu: 'SOS Video',
        );
      case 'audio':
        return _t(
          es: 'Audio SOS',
          en: 'SOS Audio',
          ay: 'SOS Audio',
          qu: 'SOS Audio',
        );
      case 'imagen':
        return _t(
          es: 'Imagen SOS',
          en: 'SOS Image',
          ay: 'SOS Imagen',
          qu: 'SOS Imagen',
        );
      default:
        return _t(
          es: 'Evidencia SOS',
          en: 'SOS Evidence',
          ay: 'SOS Evidencia',
          qu: 'SOS Evidencia',
        );
    }
  }

  String _buildEvidenceDescription({
    required String evidenceType,
    String? locationUrl,
  }) {
    final typeLabel = switch (evidenceType) {
      'video' => _t(
        es: 'Video registrado durante la alerta SOS.',
        en: 'Video recorded during the SOS alert.',
        ay: 'SOS alerta pachan qillqtata video.',
        qu: 'SOS alerta pachapi qillqasqa video.',
      ),
      'audio' => _t(
        es: 'Audio registrado durante la alerta SOS.',
        en: 'Audio recorded during the SOS alert.',
        ay: 'SOS alerta pachan qillqtata audio.',
        qu: 'SOS alerta pachapi qillqasqa audio.',
      ),
      'imagen' => _t(
        es: 'Imagen registrada durante la alerta SOS.',
        en: 'Image recorded during the SOS alert.',
        ay: 'SOS alerta pachan qillqtata imagen.',
        qu: 'SOS alerta pachapi qillqasqa imagen.',
      ),
      _ => _t(
        es: 'Evidencia registrada durante la alerta SOS.',
        en: 'Evidence recorded during the SOS alert.',
        ay: 'SOS alerta pachan qillqtata evidencia.',
        qu: 'SOS alerta pachapi qillqasqa evidencia.',
      ),
    };

    if (locationUrl == null || locationUrl.trim().isEmpty) {
      return typeLabel;
    }

    return '$typeLabel ${_t(
      es: 'Ubicacion asociada: $locationUrl',
      en: 'Linked location: $locationUrl',
      ay: 'Mayachata ubicacion: $locationUrl',
      qu: 'Tinkisqa ubicacion: $locationUrl',
    )}';
  }

  String? _fallbackMimeType(String filePath) {
    final extension = p.extension(filePath).toLowerCase();
    switch (extension) {
      case '.mp4':
        return 'video/mp4';
      case '.m4a':
        return 'audio/mp4';
      case '.aac':
        return 'audio/aac';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      default:
        return null;
    }
  }

  String? _inferEvidenceType(String? mimeType) {
    if (mimeType == null || mimeType.isEmpty) {
      return null;
    }

    if (mimeType.startsWith('video/')) {
      return 'video';
    }

    if (mimeType.startsWith('audio/')) {
      return 'audio';
    }

    if (mimeType.startsWith('image/')) {
      return 'imagen';
    }

    return null;
  }

  String _buildUploadMessage({
    required int uploadedCount,
    required List<String> issues,
  }) {
    final appName = AppBrandingService.instance.displayName;
    if (uploadedCount == 0 && issues.isEmpty) {
      return _t(
        es: 'No se pudo subir evidencia al servidor.',
        en: 'The evidence could not be uploaded to the server.',
        ay: 'Janiw evidencia servidorar apkatanjamakiti.',
        qu: 'Evidenciaqa servidorman mana wichariyta atikurqanchu.',
      );
    }

    if (uploadedCount == 0) {
      return '${_t(
        es: 'No se pudo subir la evidencia al servidor.',
        en: 'The evidence could not be uploaded to the server.',
        ay: 'Janiw evidencia servidorar apkatanjamakiti.',
        qu: 'Evidenciaqa servidorman mana wichariyta atikurqanchu.',
      )} ${issues.first}';
    }

    if (issues.isEmpty) {
      return uploadedCount == 1
          ? _t(
              es: 'La evidencia se subio al servidor $appName.',
              en: 'The evidence was uploaded to the $appName server.',
              ay: 'Evidenciax $appName servidorar apkatawa.',
              qu: 'Evidenciaqa $appName servidorman wicharisqa karqan.',
            )
          : _t(
              es: 'Se subieron $uploadedCount archivos al servidor $appName.',
              en: '$uploadedCount files were uploaded to the $appName server.',
              ay: '$uploadedCount archivonakax $appName servidorar apkatatawa.',
              qu:
                  '$uploadedCount archivosqa $appName servidorman wicharisqa karqanku.',
            );
    }

    return '${_t(
      es: 'Se subieron $uploadedCount archivos al servidor.',
      en: '$uploadedCount files were uploaded to the server.',
      ay: '$uploadedCount archivonakax servidorar apkatatawa.',
      qu: '$uploadedCount archivosqa servidorman wicharisqa karqanku.',
    )} ${issues.first}';
  }

  String _buildLocalIncidentFallbackMessage(ApiException error) {
    final lowerMessage = error.message.toLowerCase();
    final appName = AppBrandingService.instance.displayName;

    if (lowerMessage.contains('no se pudo conectar con el servidor')) {
      return _t(
        es:
            'No se pudo conectar con $appName, pero la alerta SOS se guardo localmente.',
        en:
            'Could not connect to $appName, but the SOS alert was saved locally.',
        ay:
            'Janiw $appName ukamp mayachasiyjamakiti, ukampis SOS alertax localan imatawa.',
        qu:
            '${appName}wan mana tinkanakuyta atikurqanchu, ichaqa SOS alertaqa localpim waqaychasqa karqan.',
      );
    }

    if (lowerMessage.contains('perfil no encontrado')) {
      return _t(
        es:
            'La cuenta esta autenticada, pero no tiene perfil en el backend. La alerta SOS quedo guardada localmente.',
        en:
            'The account is authenticated, but it does not have a backend profile. The SOS alert was saved locally.',
        ay:
            'Cuentax autenticatawa, ukampis backend ukanx janiw perfilani. SOS alertax localan imatawa.',
        qu:
            'Cuentaqa autenticada kashan, ichaqa backendpi perfilninta mana kanchu. SOS alertaqa localpim waqaychasqa karqan.',
      );
    }

    return _t(
      es:
          'La alerta SOS se guardo localmente. $appName sincronizara el incidente cuando el servicio vuelva a responder.',
      en:
          'The SOS alert was saved locally. $appName will sync the incident when the service responds again.',
      ay:
          'SOS alertax localan imatawa. $appName ukax incidente sincronizaniwa serviciox wasitat kuttanipkani ukhaxa.',
      qu:
          'SOS alertaqa localpim waqaychasqa karqan. Servicio kutimuptinqa ${appName}qa incidenteta sincronizanan.',
    );
  }

  String _formatAlertTimestamp(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString().padLeft(4, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }
}

IncidentRecord? _extractIncidentDetail(Map<String, dynamic> response) {
  final directData = response['data'];
  if (directData is Map<String, dynamic>) {
    return IncidentRecord.fromBackendJson(directData);
  }

  if (directData is Map) {
    final normalized = Map<String, dynamic>.from(directData);
    for (final key in const ['incident', 'item', 'row']) {
      final nested = normalized[key];
      if (nested is Map<String, dynamic>) {
        return IncidentRecord.fromBackendJson(nested);
      }
      if (nested is Map) {
        return IncidentRecord.fromBackendJson(Map<String, dynamic>.from(nested));
      }
    }
    return IncidentRecord.fromBackendJson(normalized);
  }

  for (final key in const ['incident', 'item', 'row']) {
    final nested = response[key];
    if (nested is Map<String, dynamic>) {
      return IncidentRecord.fromBackendJson(nested);
    }
    if (nested is Map) {
      return IncidentRecord.fromBackendJson(Map<String, dynamic>.from(nested));
    }
  }

  if (response['id'] != null) {
    return IncidentRecord.fromBackendJson(response);
  }

  return null;
}

String _buildLocalIncidentId() {
  return 'local-incident-${DateTime.now().microsecondsSinceEpoch}';
}
