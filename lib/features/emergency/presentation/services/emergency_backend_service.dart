import 'dart:io';

import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

import '../../../../core/services/app_branding_service.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../auth/presentation/services/auth_service.dart';
import '../../../evidence/presentation/services/evidence_library_service.dart';
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
  final String? message;

  const EmergencyEvidenceUploadResult({
    required this.success,
    required this.uploadedCount,
    this.message,
  });
}

class EmergencyBackendService {
  final AuthService _authService;
  final ApiClient _apiClient;
  final EvidenceLibraryService _evidenceLibraryService;

  EmergencyBackendService({
    AuthService? authService,
    ApiClient? apiClient,
    EvidenceLibraryService? evidenceLibraryService,
  })
    : _authService = authService ?? AuthService(),
      _apiClient = apiClient ?? ApiClient(),
      _evidenceLibraryService =
          evidenceLibraryService ?? EvidenceLibraryService();

  Future<EmergencyIncidentResult> createIncident({String? locationUrl}) async {
    final user = await _authService.getSession();
    if (user == null) {
      return const EmergencyIncidentResult(
        success: false,
        message: 'No hay una sesion activa para registrar la alerta.',
      );
    }

    try {
      final incidentTitle = 'Alerta SOS';
      final incidentDescription = _buildIncidentDescription(locationUrl);
      final incidentDate = DateTime.now().toUtc().toIso8601String();
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

      final data = _extractDataMap(response);
      final incidentId = _readString(data['id']);
      if (incidentId.isEmpty) {
        return const EmergencyIncidentResult(
          success: false,
          message: 'El servidor no devolvio un incidente valido.',
        );
      }

      await _evidenceLibraryService.upsertCachedIncident(
        userId: user.id,
        incident: EvidenceIncidentRecord(
          id: incidentId,
          title: incidentTitle,
          description: incidentDescription,
          type: 'sos',
          status: 'registrado',
          riskLevel: 'critico',
          location: locationUrl ?? '',
          recordedAt: incidentDate,
          evidences: const [],
        ),
      );

      return EmergencyIncidentResult(success: true, incidentId: incidentId);
    } on ApiException catch (error) {
      return EmergencyIncidentResult(
        success: false,
        message: _mapIncidentError(error),
      );
    } catch (_) {
      return const EmergencyIncidentResult(
        success: false,
        message: 'No se pudo registrar la alerta en el servidor.',
      );
    }
  }

  Future<EmergencyEvidenceUploadResult> uploadEvidence({
    required String incidentId,
    required EmergencyCaptureStopResult stopResult,
    String? locationUrl,
  }) async {
    final attachmentPaths = stopResult.attachmentPaths;
    if (attachmentPaths.isEmpty) {
      return const EmergencyEvidenceUploadResult(
        success: false,
        uploadedCount: 0,
        message: 'No habia archivos para subir al servidor.',
      );
    }

    final user = await _authService.getSession();
    if (user == null) {
      return const EmergencyEvidenceUploadResult(
        success: false,
        uploadedCount: 0,
        message: 'No hay una sesion activa para subir evidencia.',
      );
    }

    var uploadedCount = 0;
    final issues = <String>[];
    final uploadedEvidenceRecords = <EvidenceAttachmentRecord>[];

    for (final filePath in attachmentPaths) {
      final file = File(filePath);
      if (!await file.exists()) {
        issues.add('No se encontro ${p.basename(filePath)}.');
        continue;
      }

      final mimeType = lookupMimeType(filePath) ?? _fallbackMimeType(filePath);
      final evidenceType = _inferEvidenceType(mimeType);
      if (mimeType == null || evidenceType == null) {
        issues.add('No se pudo reconocer el tipo de ${p.basename(filePath)}.');
        continue;
      }

      try {
        final takenAt = await file.lastModified();
        final evidenceTitle = _buildEvidenceTitle(evidenceType);
        final evidenceDescription = _buildEvidenceDescription(
          evidenceType: evidenceType,
          locationUrl: locationUrl,
        );
        final uploadResponse = await _apiClient.postMultipart(
          '/incidents/$incidentId/evidences',
          accessToken: user.accessToken,
          fileField: 'file',
          filePath: filePath,
          contentType: MediaType.parse(mimeType),
          fields: {
            'tipo_evidencia': evidenceType,
            'titulo': evidenceTitle,
            'descripcion': evidenceDescription,
            'taken_at': takenAt.toUtc().toIso8601String(),
            'is_private': 'true',
          },
        );
        uploadedCount++;

        final responseData = _extractDataMap(uploadResponse);
        uploadedEvidenceRecords.add(
          EvidenceAttachmentRecord(
            id: _readString(
              responseData['id'],
              fallback:
                  '${incidentId}_${p.basenameWithoutExtension(filePath)}_${takenAt.millisecondsSinceEpoch}',
            ),
            incidentId: incidentId,
            title: evidenceTitle,
            description: evidenceDescription,
            type: evidenceType,
            capturedAt: takenAt.toUtc().toIso8601String(),
            filePath: _readString(
              responseData['url'] ??
                  responseData['archivo_url'] ??
                  responseData['file_url'],
              fallback: filePath,
            ),
            isPrivate: true,
          ),
        );
      } on ApiException catch (error) {
        issues.add(_mapUploadError(error, p.basename(filePath)));
      } catch (_) {
        issues.add('No se pudo subir ${p.basename(filePath)}.');
      }
    }

    if (uploadedEvidenceRecords.isNotEmpty) {
      await _evidenceLibraryService.appendCachedEvidences(
        userId: user.id,
        incidentId: incidentId,
        evidences: uploadedEvidenceRecords,
      );
    }

    return EmergencyEvidenceUploadResult(
      success: uploadedCount > 0,
      uploadedCount: uploadedCount,
      message: _buildUploadMessage(
        uploadedCount: uploadedCount,
        issues: issues,
      ),
    );
  }

  String _buildIncidentDescription(String? locationUrl) {
    final appName = AppBrandingService.instance.displayName;
    if (locationUrl == null || locationUrl.trim().isEmpty) {
      return 'Alerta SOS activada desde la app $appName.';
    }

    return 'Alerta SOS activada desde la app $appName. Ubicacion reportada: $locationUrl';
  }

  String _buildEvidenceTitle(String evidenceType) {
    switch (evidenceType) {
      case 'video':
        return 'Video SOS';
      case 'audio':
        return 'Audio SOS';
      case 'imagen':
        return 'Imagen SOS';
      default:
        return 'Evidencia SOS';
    }
  }

  String _buildEvidenceDescription({
    required String evidenceType,
    String? locationUrl,
  }) {
    final typeLabel = switch (evidenceType) {
      'video' => 'Video registrado durante la alerta SOS.',
      'audio' => 'Audio registrado durante la alerta SOS.',
      'imagen' => 'Imagen registrada durante la alerta SOS.',
      _ => 'Evidencia registrada durante la alerta SOS.',
    };

    if (locationUrl == null || locationUrl.trim().isEmpty) {
      return typeLabel;
    }

    return '$typeLabel Ubicacion asociada: $locationUrl';
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
      return 'No se pudo subir evidencia al servidor.';
    }

    if (uploadedCount == 0) {
      return 'No se pudo subir la evidencia al servidor. ${issues.first}';
    }

    if (issues.isEmpty) {
      return uploadedCount == 1
          ? 'La evidencia se subio al servidor $appName.'
          : 'Se subieron $uploadedCount archivos al servidor $appName.';
    }

    return 'Se subieron $uploadedCount archivos al servidor. ${issues.first}';
  }

  String _mapIncidentError(ApiException error) {
    final lowerMessage = error.message.toLowerCase();
    final appName = AppBrandingService.instance.displayName;

    if (lowerMessage.contains('no se pudo conectar con el servidor')) {
      return 'No se pudo conectar con $appName para registrar la alerta.';
    }

    if (lowerMessage.contains('perfil no encontrado')) {
      return 'La cuenta esta autenticada, pero no tiene perfil en el backend.';
    }

    return error.message;
  }

  String _mapUploadError(ApiException error, String filename) {
    final lowerMessage = error.message.toLowerCase();
    final appName = AppBrandingService.instance.displayName;

    if (lowerMessage.contains('tipo de archivo no permitido')) {
      return '$filename no tiene un formato permitido por el backend.';
    }

    if (lowerMessage.contains('request entity too large') ||
        lowerMessage.contains('payload too large')) {
      return '$filename es demasiado grande para subir al servidor.';
    }

    if (lowerMessage.contains('no se pudo conectar con el servidor')) {
      return 'No se pudo conectar con $appName para subir $filename.';
    }

    return 'No se pudo subir $filename: ${error.message}';
  }

  Map<String, dynamic> _extractDataMap(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return <String, dynamic>{};
  }
}

String _readString(dynamic value, {String fallback = ''}) {
  if (value is String) {
    return value;
  }
  if (value == null) {
    return fallback;
  }
  return value.toString();
}
