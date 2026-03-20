import 'dart:convert';
import 'dart:io';

import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../auth/presentation/services/auth_service.dart';
import '../../domain/models/evidence_record.dart';

class EvidenceListResult {
  final List<EvidenceRecord> evidences;
  final bool fromCache;
  final String? message;

  const EvidenceListResult({
    required this.evidences,
    required this.fromCache,
    this.message,
  });
}

class EvidenceDetailResult {
  final bool success;
  final EvidenceRecord? evidence;
  final String? message;

  const EvidenceDetailResult({
    required this.success,
    this.evidence,
    this.message,
  });
}

class EvidenceMutationResult {
  final bool success;
  final EvidenceRecord? evidence;
  final String message;

  const EvidenceMutationResult({
    required this.success,
    required this.message,
    this.evidence,
  });
}

class EvidenceService {
  static const _cacheKeyPrefix = 'evidence_records_cache_';

  final AuthService _authService;
  final ApiClient _apiClient;

  EvidenceService({AuthService? authService, ApiClient? apiClient})
    : _authService = authService ?? AuthService(),
      _apiClient = apiClient ?? ApiClient();

  Future<EvidenceListResult> loadEvidences() async {
    final user = await _authService.getSession();
    if (user == null) {
      return const EvidenceListResult(
        evidences: [],
        fromCache: true,
        message: 'Inicia sesion para ver tus evidencias.',
      );
    }

    final cached = await _loadCachedEvidences(user.id);

    try {
      final response = await _apiClient.getJson(
        '/evidences',
        accessToken: user.accessToken,
      );
      final evidences = _extractEvidenceList(response);
      await _saveCachedEvidences(user.id, evidences);

      return EvidenceListResult(
        evidences: evidences,
        fromCache: false,
        message: evidences.isEmpty
            ? 'Todavia no tienes evidencias registradas.'
            : null,
      );
    } on ApiException catch (error) {
      return EvidenceListResult(
        evidences: cached,
        fromCache: true,
        message: cached.isEmpty
            ? _mapLoadError(error)
            : 'Mostrando evidencias guardadas en este dispositivo.',
      );
    } catch (_) {
      return EvidenceListResult(
        evidences: cached,
        fromCache: true,
        message: cached.isEmpty
            ? 'No se pudo cargar tu bandeja de evidencias.'
            : 'Mostrando evidencias guardadas en este dispositivo.',
      );
    }
  }

  Future<EvidenceDetailResult> getEvidenceDetail(
    String evidenceId, {
    EvidenceRecord? fallback,
  }) async {
    final user = await _authService.getSession();
    if (user == null) {
      return EvidenceDetailResult(
        success: fallback != null,
        evidence: fallback,
        message: 'Inicia sesion para abrir esta evidencia.',
      );
    }

    try {
      final response = await _apiClient.getJson(
        '/evidences/$evidenceId',
        accessToken: user.accessToken,
      );
      final detailedEvidence = _extractEvidenceDetail(response);
      if (detailedEvidence == null) {
        return EvidenceDetailResult(
          success: fallback != null,
          evidence: fallback,
          message: 'No se encontro detalle para esta evidencia.',
        );
      }

      await upsertCachedEvidence(userId: user.id, evidence: detailedEvidence);

      return EvidenceDetailResult(success: true, evidence: detailedEvidence);
    } on ApiException catch (error) {
      final cached = await findCachedEvidence(user.id, evidenceId);
      return EvidenceDetailResult(
        success: cached != null || fallback != null,
        evidence: cached ?? fallback,
        message: cached == null && fallback == null
            ? error.message
            : 'Mostrando el ultimo detalle guardado localmente.',
      );
    } catch (_) {
      final cached = await findCachedEvidence(user.id, evidenceId);
      return EvidenceDetailResult(
        success: cached != null || fallback != null,
        evidence: cached ?? fallback,
        message: cached == null && fallback == null
            ? 'No se pudo abrir el detalle de la evidencia.'
            : 'Mostrando el ultimo detalle guardado localmente.',
      );
    }
  }

  Future<EvidenceMutationResult> createEvidence({
    required String filePath,
    String? selectedType,
    String? title,
    String? description,
    DateTime? takenAt,
    bool isPrivate = true,
  }) async {
    final user = await _authService.getSession();
    if (user == null) {
      return const EvidenceMutationResult(
        success: false,
        message: 'No hay una sesion activa para subir evidencias.',
      );
    }

    final file = File(filePath);
    if (!await file.exists()) {
      return const EvidenceMutationResult(
        success: false,
        message: 'El archivo seleccionado ya no existe.',
      );
    }

    final sizeBytes = await file.length();
    if (sizeBytes > 20 * 1024 * 1024) {
      return const EvidenceMutationResult(
        success: false,
        message: 'El archivo supera el limite de 20 MB.',
      );
    }

    final mimeType = lookupMimeType(filePath) ?? _fallbackMimeType(filePath);
    final resolvedType = _normalizeRequestedType(
      selectedType,
      inferredType: _inferEvidenceType(mimeType, filePath),
    );

    if (mimeType == null) {
      return const EvidenceMutationResult(
        success: false,
        message: 'No se pudo reconocer el tipo del archivo seleccionado.',
      );
    }

    final fields = <String, String>{'is_private': isPrivate.toString()};

    if (resolvedType != null) {
      fields['tipo_evidencia'] = resolvedType;
    }
    if ((title ?? '').trim().isNotEmpty) {
      fields['titulo'] = title!.trim();
    }
    if ((description ?? '').trim().isNotEmpty) {
      fields['descripcion'] = description!.trim();
    }
    if (takenAt != null) {
      fields['taken_at'] = takenAt.toUtc().toIso8601String();
    }

    try {
      final response = await _apiClient.postMultipart(
        '/evidences',
        accessToken: user.accessToken,
        fileField: 'file',
        filePath: filePath,
        contentType: MediaType.parse(mimeType),
        fields: fields,
      );

      final createdEvidence =
          _extractEvidenceDetail(response) ??
          EvidenceRecord(
            id: '',
            title: title?.trim().isNotEmpty == true
                ? title!.trim()
                : p.basename(filePath),
            description: description?.trim() ?? '',
            type:
                resolvedType ??
                _inferEvidenceType(mimeType, filePath) ??
                'documento',
            createdAt: DateTime.now().toUtc().toIso8601String(),
            takenAt: takenAt?.toUtc().toIso8601String() ?? '',
            incidentId: null,
            fileUrl: filePath,
            fileName: p.basename(filePath),
            mimeType: mimeType,
            isPrivate: isPrivate,
            sizeBytes: sizeBytes,
          );

      await upsertCachedEvidence(userId: user.id, evidence: createdEvidence);

      return EvidenceMutationResult(
        success: true,
        message: 'Evidencia creada correctamente.',
        evidence: createdEvidence,
      );
    } on ApiException catch (error) {
      return EvidenceMutationResult(
        success: false,
        message: _mapCreateError(error),
      );
    } catch (_) {
      return const EvidenceMutationResult(
        success: false,
        message: 'No se pudo crear la evidencia.',
      );
    }
  }

  Future<EvidenceMutationResult> updateEvidenceIncident({
    required EvidenceRecord evidence,
    required String? incidentId,
  }) async {
    final user = await _authService.getSession();
    if (user == null) {
      return const EvidenceMutationResult(
        success: false,
        message: 'No hay una sesion activa para actualizar la asociacion.',
      );
    }

    try {
      final response = await _apiClient.putJson(
        '/evidences/${evidence.id}/incident',
        accessToken: user.accessToken,
        body: {'incident_id': incidentId},
      );

      final updatedEvidence =
          _extractEvidenceDetail(response) ??
          evidence.copyWith(
            incidentId: incidentId,
            clearIncidentId: incidentId == null,
          );

      await upsertCachedEvidence(userId: user.id, evidence: updatedEvidence);

      return EvidenceMutationResult(
        success: true,
        message: incidentId == null
            ? 'La evidencia quedo sin incidente asociado.'
            : 'La evidencia ahora esta asociada al incidente.',
        evidence: updatedEvidence,
      );
    } on ApiException catch (error) {
      return EvidenceMutationResult(
        success: false,
        message: _mapAssociationError(error),
      );
    } catch (_) {
      return const EvidenceMutationResult(
        success: false,
        message: 'No se pudo actualizar la asociacion de la evidencia.',
      );
    }
  }

  Future<void> upsertCachedEvidence({
    required String userId,
    required EvidenceRecord evidence,
  }) async {
    final evidences = await _loadCachedEvidences(userId);
    final index = evidences.indexWhere((item) => item.id == evidence.id);
    if (index == -1) {
      evidences.insert(0, evidence);
    } else {
      evidences[index] = evidence;
    }
    await _saveCachedEvidences(userId, evidences);
  }

  Future<EvidenceRecord?> findCachedEvidence(
    String userId,
    String evidenceId,
  ) async {
    final evidences = await _loadCachedEvidences(userId);
    for (final evidence in evidences) {
      if (evidence.id == evidenceId) {
        return evidence;
      }
    }
    return null;
  }

  Future<List<EvidenceRecord>> loadCachedEvidencesForUser(String userId) {
    return _loadCachedEvidences(userId);
  }

  List<EvidenceRecord> _extractEvidenceList(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map(
            (item) =>
                EvidenceRecord.fromBackendJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    }

    if (data is Map) {
      for (final key in const ['evidences', 'items', 'rows']) {
        final nested = data[key];
        if (nested is List) {
          return nested
              .whereType<Map>()
              .map(
                (item) => EvidenceRecord.fromBackendJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList();
        }
      }
    }

    return const <EvidenceRecord>[];
  }

  EvidenceRecord? _extractEvidenceDetail(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return EvidenceRecord.fromBackendJson(data);
    }
    if (data is Map) {
      return EvidenceRecord.fromBackendJson(Map<String, dynamic>.from(data));
    }
    return null;
  }

  Future<List<EvidenceRecord>> _loadCachedEvidences(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_cacheKeyPrefix$userId');
    if (raw == null || raw.trim().isEmpty) {
      return <EvidenceRecord>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <EvidenceRecord>[];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => EvidenceRecord.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (_) {
      return <EvidenceRecord>[];
    }
  }

  Future<void> _saveCachedEvidences(
    String userId,
    List<EvidenceRecord> evidences,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_cacheKeyPrefix$userId',
      jsonEncode(evidences.map((item) => item.toJson()).toList()),
    );
  }

  String _mapLoadError(ApiException error) {
    final normalized = error.message.toLowerCase();
    if (normalized.contains('no se pudo conectar con el servidor')) {
      return 'No se pudo actualizar la bandeja de evidencias. Revisa tu conexion.';
    }
    return error.message;
  }

  String _mapCreateError(ApiException error) {
    final normalized = error.message.toLowerCase();
    if (normalized.contains('uuid invalido')) {
      return 'La asociacion enviada para esta evidencia no es valida.';
    }
    if (normalized.contains('archivo no soportado') ||
        normalized.contains('tipo de archivo no permitido')) {
      return 'El archivo seleccionado no tiene un formato permitido.';
    }
    if (normalized.contains('tipo_evidencia no coincide')) {
      return 'El tipo de evidencia no coincide con el archivo elegido.';
    }
    return error.message;
  }

  String _mapAssociationError(ApiException error) {
    final normalized = error.message.toLowerCase();
    if (normalized.contains('incidente no encontrado')) {
      return 'No se encontro el incidente seleccionado.';
    }
    if (normalized.contains('evidencia no encontrada')) {
      return 'No se encontro la evidencia a actualizar.';
    }
    return error.message;
  }

  String? _normalizeRequestedType(
    String? selectedType, {
    String? inferredType,
  }) {
    final normalized = (selectedType ?? '').trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'auto') {
      return inferredType;
    }
    return normalized;
  }

  String? _fallbackMimeType(String filePath) {
    final extension = p.extension(filePath).toLowerCase();
    switch (extension) {
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.mp4':
      case '.mov':
        return 'video/mp4';
      case '.m4a':
        return 'audio/mp4';
      case '.aac':
        return 'audio/aac';
      case '.mp3':
        return 'audio/mpeg';
      case '.pdf':
        return 'application/pdf';
      case '.txt':
        return 'text/plain';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.rtf':
        return 'application/rtf';
      case '.odt':
        return 'application/vnd.oasis.opendocument.text';
      default:
        return null;
    }
  }

  String? _inferEvidenceType(String? mimeType, String filePath) {
    if (mimeType == null || mimeType.trim().isEmpty) {
      return null;
    }

    if (mimeType.startsWith('image/')) {
      return 'imagen';
    }
    if (mimeType.startsWith('video/')) {
      return 'video';
    }
    if (mimeType.startsWith('audio/')) {
      return 'audio';
    }
    if (mimeType == 'text/plain') {
      return 'texto';
    }

    final extension = p.extension(filePath).toLowerCase();
    if (extension == '.txt') {
      return 'texto';
    }
    if (const ['.pdf', '.doc', '.docx', '.rtf', '.odt'].contains(extension)) {
      return 'documento';
    }

    return null;
  }
}
