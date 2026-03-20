import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../auth/presentation/services/auth_service.dart';

class EvidenceAttachmentRecord {
  final String id;
  final String incidentId;
  final String title;
  final String description;
  final String type;
  final String capturedAt;
  final String filePath;
  final bool isPrivate;

  const EvidenceAttachmentRecord({
    required this.id,
    required this.incidentId,
    required this.title,
    required this.description,
    required this.type,
    required this.capturedAt,
    required this.filePath,
    required this.isPrivate,
  });

  EvidenceAttachmentRecord copyWith({
    String? id,
    String? incidentId,
    String? title,
    String? description,
    String? type,
    String? capturedAt,
    String? filePath,
    bool? isPrivate,
  }) {
    return EvidenceAttachmentRecord(
      id: id ?? this.id,
      incidentId: incidentId ?? this.incidentId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      capturedAt: capturedAt ?? this.capturedAt,
      filePath: filePath ?? this.filePath,
      isPrivate: isPrivate ?? this.isPrivate,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'incidentId': incidentId,
    'title': title,
    'description': description,
    'type': type,
    'capturedAt': capturedAt,
    'filePath': filePath,
    'isPrivate': isPrivate,
  };

  factory EvidenceAttachmentRecord.fromJson(Map<String, dynamic> json) {
    return EvidenceAttachmentRecord(
      id: _readString(json['id']),
      incidentId: _readString(
        json['incidentId'] ?? json['incident_id'] ?? json['incidente_id'],
      ),
      title: _readString(json['title'], fallback: 'Evidencia'),
      description: _readString(json['description']),
      type: _readString(json['type'], fallback: 'archivo'),
      capturedAt: _readString(
        json['capturedAt'] ?? json['captured_at'] ?? json['taken_at'],
      ),
      filePath: _readString(
        json['filePath'] ??
            json['file_path'] ??
            json['url'] ??
            json['archivo_url'] ??
            json['file_url'],
      ),
      isPrivate: _readBool(json['isPrivate'] ?? json['is_private']),
    );
  }

  factory EvidenceAttachmentRecord.fromBackendJson(
    Map<String, dynamic> json, {
    required String incidentId,
  }) {
    final evidenceType = _readString(
      json['tipo_evidencia'] ?? json['type'] ?? json['tipo'],
      fallback: 'archivo',
    );
    final evidenceTitle = _readString(
      json['titulo'] ?? json['title'],
      fallback: _defaultEvidenceTitle(evidenceType),
    );

    return EvidenceAttachmentRecord(
      id: _readString(json['id']),
      incidentId: incidentId,
      title: evidenceTitle,
      description: _readString(json['descripcion'] ?? json['description']),
      type: evidenceType,
      capturedAt: _readString(
        json['taken_at'] ??
            json['captured_at'] ??
            json['fecha_captura'] ??
            json['created_at'],
      ),
      filePath: _readString(
        json['url'] ??
            json['archivo_url'] ??
            json['file_url'] ??
            json['path'],
      ),
      isPrivate: _readBool(json['is_private'] ?? json['private']),
    );
  }
}

class EvidenceIncidentRecord {
  final String id;
  final String title;
  final String description;
  final String type;
  final String status;
  final String riskLevel;
  final String location;
  final String recordedAt;
  final List<EvidenceAttachmentRecord> evidences;

  const EvidenceIncidentRecord({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.status,
    required this.riskLevel,
    required this.location,
    required this.recordedAt,
    required this.evidences,
  });

  EvidenceIncidentRecord copyWith({
    String? id,
    String? title,
    String? description,
    String? type,
    String? status,
    String? riskLevel,
    String? location,
    String? recordedAt,
    List<EvidenceAttachmentRecord>? evidences,
  }) {
    return EvidenceIncidentRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      riskLevel: riskLevel ?? this.riskLevel,
      location: location ?? this.location,
      recordedAt: recordedAt ?? this.recordedAt,
      evidences: evidences ?? this.evidences,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'type': type,
    'status': status,
    'riskLevel': riskLevel,
    'location': location,
    'recordedAt': recordedAt,
    'evidences': evidences.map((evidence) => evidence.toJson()).toList(),
  };

  factory EvidenceIncidentRecord.fromJson(Map<String, dynamic> json) {
    final rawEvidences = json['evidences'];
    final evidences = rawEvidences is List
        ? rawEvidences
              .whereType<Map>()
              .map(
                (item) => EvidenceAttachmentRecord.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : const <EvidenceAttachmentRecord>[];

    return EvidenceIncidentRecord(
      id: _readString(json['id']),
      title: _readString(json['title'], fallback: 'Incidente'),
      description: _readString(json['description']),
      type: _readString(json['type'], fallback: 'sos'),
      status: _readString(json['status'], fallback: 'registrado'),
      riskLevel: _readString(json['riskLevel'], fallback: 'sin definir'),
      location: _readString(json['location']),
      recordedAt: _readString(json['recordedAt']),
      evidences: evidences,
    );
  }

  factory EvidenceIncidentRecord.fromBackendJson(Map<String, dynamic> json) {
    final incidentId = _readString(json['id']);
    final rawEvidences =
        json['evidencias'] ?? json['evidences'] ?? json['adjuntos'];
    final evidences = rawEvidences is List
        ? rawEvidences
              .whereType<Map>()
              .map(
                (item) => EvidenceAttachmentRecord.fromBackendJson(
                  Map<String, dynamic>.from(item),
                  incidentId: incidentId,
                ),
              )
              .toList()
        : const <EvidenceAttachmentRecord>[];

    return EvidenceIncidentRecord(
      id: incidentId,
      title: _readString(
        json['titulo'] ?? json['title'],
        fallback: 'Incidente SOS',
      ),
      description: _readString(json['descripcion'] ?? json['description']),
      type: _readString(
        json['tipo_incidente'] ?? json['type'],
        fallback: 'sos',
      ),
      status: _readString(json['estado'] ?? json['status'], fallback: 'abierto'),
      riskLevel: _readString(
        json['nivel_riesgo'] ?? json['risk_level'],
        fallback: 'sin definir',
      ),
      location: _readString(json['lugar'] ?? json['location']),
      recordedAt: _readString(
        json['fecha_incidente'] ?? json['recorded_at'] ?? json['created_at'],
      ),
      evidences: evidences,
    );
  }
}

class EvidenceLibraryLoadResult {
  final List<EvidenceIncidentRecord> incidents;
  final bool fromCache;
  final String? message;

  const EvidenceLibraryLoadResult({
    required this.incidents,
    required this.fromCache,
    this.message,
  });
}

class IncidentUpdateResult {
  final bool success;
  final EvidenceIncidentRecord incident;
  final String? message;

  const IncidentUpdateResult({
    required this.success,
    required this.incident,
    this.message,
  });
}

class EvidenceUpdateResult {
  final bool success;
  final EvidenceAttachmentRecord evidence;
  final String? message;

  const EvidenceUpdateResult({
    required this.success,
    required this.evidence,
    this.message,
  });
}

class EvidenceLibraryService {
  static const _cacheKeyPrefix = 'evidence_library_cache_';

  final AuthService _authService;
  final ApiClient _apiClient;

  EvidenceLibraryService({AuthService? authService, ApiClient? apiClient})
    : _authService = authService ?? AuthService(),
      _apiClient = apiClient ?? ApiClient();

  Future<EvidenceLibraryLoadResult> loadLibrary() async {
    final user = await _authService.getSession();
    if (user == null) {
      return const EvidenceLibraryLoadResult(
        incidents: [],
        fromCache: true,
        message: 'Inicia sesion para ver tus incidentes y evidencias.',
      );
    }

    final cachedIncidents = await _loadCachedIncidents(user.id);

    try {
      final remoteIncidents = await _fetchRemoteIncidents(
        accessToken: user.accessToken,
      );
      final mergedIncidents = _mergeIncidentLists(
        remoteIncidents,
        cachedIncidents,
      );
      await _saveCachedIncidents(user.id, mergedIncidents);

      return EvidenceLibraryLoadResult(
        incidents: mergedIncidents,
        fromCache: false,
        message: mergedIncidents.isEmpty
            ? 'Todavia no tienes incidentes registrados.'
            : null,
      );
    } on ApiException catch (error) {
      return EvidenceLibraryLoadResult(
        incidents: cachedIncidents,
        fromCache: true,
        message: cachedIncidents.isEmpty
            ? _mapLoadError(error)
            : 'Mostrando tus incidentes guardados en este dispositivo.',
      );
    } catch (_) {
      return EvidenceLibraryLoadResult(
        incidents: cachedIncidents,
        fromCache: true,
        message: cachedIncidents.isEmpty
            ? 'No se pudo cargar el historial de evidencias.'
            : 'Mostrando tus incidentes guardados en este dispositivo.',
      );
    }
  }

  Future<IncidentUpdateResult> updateIncidentDetails({
    required EvidenceIncidentRecord incident,
    required String title,
    required String description,
  }) async {
    final updatedIncident = incident.copyWith(
      title: _normalizeTitle(title, fallback: incident.title),
      description: description.trim(),
    );

    final user = await _authService.getSession();
    if (user != null) {
      await _upsertCachedIncident(
        userId: user.id,
        incident: updatedIncident,
      );
    }

    if (user == null) {
      return IncidentUpdateResult(
        success: true,
        incident: updatedIncident,
        message: 'Los cambios se guardaron solo en este dispositivo.',
      );
    }

    try {
      await _apiClient.putJson(
        '/incidents/${incident.id}',
        accessToken: user.accessToken,
        body: {
          'titulo': updatedIncident.title,
          'descripcion': updatedIncident.description,
        },
      );

      return IncidentUpdateResult(
        success: true,
        incident: updatedIncident,
        message: 'Incidente actualizado para tu denuncia.',
      );
    } on ApiException catch (error) {
      return IncidentUpdateResult(
        success: true,
        incident: updatedIncident,
        message:
            'Se guardo localmente. No se pudo sincronizar el incidente: ${error.message}',
      );
    } catch (_) {
      return IncidentUpdateResult(
        success: true,
        incident: updatedIncident,
        message:
            'Se guardo localmente. No se pudo sincronizar el incidente.',
      );
    }
  }

  Future<EvidenceUpdateResult> updateEvidenceDetails({
    required String incidentId,
    required EvidenceAttachmentRecord evidence,
    required String title,
    required String description,
  }) async {
    final updatedEvidence = evidence.copyWith(
      title: _normalizeTitle(title, fallback: evidence.title),
      description: description.trim(),
    );

    final user = await _authService.getSession();
    if (user != null) {
      await _replaceCachedEvidence(
        userId: user.id,
        incidentId: incidentId,
        evidence: updatedEvidence,
      );
    }

    if (user == null) {
      return EvidenceUpdateResult(
        success: true,
        evidence: updatedEvidence,
        message: 'Los cambios se guardaron solo en este dispositivo.',
      );
    }

    try {
      await _apiClient.putJson(
        '/incidents/$incidentId/evidences/${evidence.id}',
        accessToken: user.accessToken,
        body: {
          'titulo': updatedEvidence.title,
          'descripcion': updatedEvidence.description,
        },
      );

      return EvidenceUpdateResult(
        success: true,
        evidence: updatedEvidence,
        message: 'Evidencia actualizada para tu denuncia.',
      );
    } on ApiException catch (error) {
      return EvidenceUpdateResult(
        success: true,
        evidence: updatedEvidence,
        message:
            'Se guardo localmente. No se pudo sincronizar la evidencia: ${error.message}',
      );
    } catch (_) {
      return EvidenceUpdateResult(
        success: true,
        evidence: updatedEvidence,
        message:
            'Se guardo localmente. No se pudo sincronizar la evidencia.',
      );
    }
  }

  Future<void> upsertCachedIncident({
    required String userId,
    required EvidenceIncidentRecord incident,
  }) async {
    await _upsertCachedIncident(userId: userId, incident: incident);
  }

  Future<void> appendCachedEvidences({
    required String userId,
    required String incidentId,
    required List<EvidenceAttachmentRecord> evidences,
  }) async {
    final cachedIncidents = await _loadCachedIncidents(userId);
    final incidentIndex = cachedIncidents.indexWhere(
      (incident) => _incidentKey(incident) == incidentId,
    );

    if (incidentIndex == -1) {
      cachedIncidents.insert(
        0,
        EvidenceIncidentRecord(
          id: incidentId,
          title: 'Incidente SOS',
          description: '',
          type: 'sos',
          status: 'registrado',
          riskLevel: 'sin definir',
          location: '',
          recordedAt: DateTime.now().toUtc().toIso8601String(),
          evidences: _sortEvidences(evidences),
        ),
      );
      await _saveCachedIncidents(userId, cachedIncidents);
      return;
    }

    final currentIncident = cachedIncidents[incidentIndex];
    final updatedIncident = currentIncident.copyWith(
      evidences: _mergeEvidenceLists(currentIncident.evidences, evidences),
    );
    cachedIncidents[incidentIndex] = updatedIncident;
    await _saveCachedIncidents(userId, cachedIncidents);
  }

  Future<List<EvidenceIncidentRecord>> _fetchRemoteIncidents({
    required String accessToken,
  }) async {
    final response = await _apiClient.getJson(
      '/incidents',
      accessToken: accessToken,
    );

    final incidents = _extractList(
      response['data'],
      candidateKeys: const ['incidents', 'items', 'rows'],
    ).map(EvidenceIncidentRecord.fromBackendJson).toList();

    final enrichedIncidents = <EvidenceIncidentRecord>[];
    for (final incident in incidents) {
      if (incident.id.isEmpty) {
        continue;
      }

      if (incident.evidences.isNotEmpty) {
        enrichedIncidents.add(
          incident.copyWith(evidences: _sortEvidences(incident.evidences)),
        );
        continue;
      }

      try {
        final evidenceResponse = await _apiClient.getJson(
          '/incidents/${incident.id}/evidences',
          accessToken: accessToken,
        );
        final evidences = _extractList(
          evidenceResponse['data'],
          candidateKeys: const ['evidences', 'items', 'rows'],
        )
            .map(
              (item) => EvidenceAttachmentRecord.fromBackendJson(
                item,
                incidentId: incident.id,
              ),
            )
            .toList();

        enrichedIncidents.add(
          incident.copyWith(evidences: _sortEvidences(evidences)),
        );
      } catch (_) {
        enrichedIncidents.add(incident);
      }
    }

    enrichedIncidents.sort(_compareIncidents);
    return enrichedIncidents;
  }

  Future<List<EvidenceIncidentRecord>> _loadCachedIncidents(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_cacheKeyPrefix$userId');
    if (raw == null || raw.trim().isEmpty) {
      return <EvidenceIncidentRecord>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <EvidenceIncidentRecord>[];
      }

      final incidents = decoded
          .whereType<Map>()
          .map(
            (item) =>
                EvidenceIncidentRecord.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
      incidents.sort(_compareIncidents);
      return incidents;
    } catch (_) {
      return <EvidenceIncidentRecord>[];
    }
  }

  Future<void> _saveCachedIncidents(
    String userId,
    List<EvidenceIncidentRecord> incidents,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedIncidents = incidents
        .map(
          (incident) => incident.copyWith(
            evidences: _sortEvidences(incident.evidences),
          ),
        )
        .toList()
      ..sort(_compareIncidents);

    await prefs.setString(
      '$_cacheKeyPrefix$userId',
      jsonEncode(
        normalizedIncidents.map((incident) => incident.toJson()).toList(),
      ),
    );
  }

  Future<void> _upsertCachedIncident({
    required String userId,
    required EvidenceIncidentRecord incident,
  }) async {
    final cachedIncidents = await _loadCachedIncidents(userId);
    final incidentIndex = cachedIncidents.indexWhere(
      (item) => _incidentKey(item) == _incidentKey(incident),
    );

    if (incidentIndex == -1) {
      cachedIncidents.insert(0, incident);
    } else {
      final currentIncident = cachedIncidents[incidentIndex];
      cachedIncidents[incidentIndex] = currentIncident.copyWith(
        title: incident.title,
        description: incident.description,
        type: _preferFilled(incident.type, currentIncident.type),
        status: _preferFilled(incident.status, currentIncident.status),
        riskLevel: _preferFilled(incident.riskLevel, currentIncident.riskLevel),
        location: _preferFilled(incident.location, currentIncident.location),
        recordedAt: _preferFilled(incident.recordedAt, currentIncident.recordedAt),
        evidences: _mergeEvidenceLists(
          currentIncident.evidences,
          incident.evidences,
        ),
      );
    }

    await _saveCachedIncidents(userId, cachedIncidents);
  }

  Future<void> _replaceCachedEvidence({
    required String userId,
    required String incidentId,
    required EvidenceAttachmentRecord evidence,
  }) async {
    final cachedIncidents = await _loadCachedIncidents(userId);
    final incidentIndex = cachedIncidents.indexWhere(
      (incident) => _incidentKey(incident) == incidentId,
    );
    if (incidentIndex == -1) {
      return;
    }

    final incident = cachedIncidents[incidentIndex];
    final evidenceIndex = incident.evidences.indexWhere(
      (item) => _evidenceKey(item) == _evidenceKey(evidence),
    );
    final updatedEvidences = [...incident.evidences];

    if (evidenceIndex == -1) {
      updatedEvidences.insert(0, evidence);
    } else {
      updatedEvidences[evidenceIndex] = evidence;
    }

    cachedIncidents[incidentIndex] = incident.copyWith(
      evidences: _sortEvidences(updatedEvidences),
    );

    await _saveCachedIncidents(userId, cachedIncidents);
  }

  List<EvidenceIncidentRecord> _mergeIncidentLists(
    List<EvidenceIncidentRecord> remoteIncidents,
    List<EvidenceIncidentRecord> cachedIncidents,
  ) {
    final cachedById = {
      for (final incident in cachedIncidents) _incidentKey(incident): incident,
    };

    final merged = remoteIncidents.map((incident) {
      final cached = cachedById.remove(_incidentKey(incident));
      if (cached == null) {
        return incident.copyWith(evidences: _sortEvidences(incident.evidences));
      }

      return incident.copyWith(
        title: _preferFilled(cached.title, incident.title),
        description: _preferFilled(cached.description, incident.description),
        type: _preferFilled(incident.type, cached.type),
        status: _preferFilled(incident.status, cached.status),
        riskLevel: _preferFilled(incident.riskLevel, cached.riskLevel),
        location: _preferFilled(incident.location, cached.location),
        recordedAt: _preferFilled(incident.recordedAt, cached.recordedAt),
        evidences: _mergeEvidenceLists(incident.evidences, cached.evidences),
      );
    }).toList();

    merged.addAll(cachedById.values);
    merged.sort(_compareIncidents);
    return merged;
  }

  List<EvidenceAttachmentRecord> _mergeEvidenceLists(
    List<EvidenceAttachmentRecord> primary,
    List<EvidenceAttachmentRecord> secondary,
  ) {
    final secondaryById = {
      for (final evidence in secondary) _evidenceKey(evidence): evidence,
    };

    final merged = primary.map((evidence) {
      final cached = secondaryById.remove(_evidenceKey(evidence));
      if (cached == null) {
        return evidence;
      }

      return evidence.copyWith(
        title: _preferFilled(cached.title, evidence.title),
        description: _preferFilled(cached.description, evidence.description),
        type: _preferFilled(evidence.type, cached.type),
        capturedAt: _preferFilled(evidence.capturedAt, cached.capturedAt),
        filePath: _preferFilled(evidence.filePath, cached.filePath),
        isPrivate: evidence.isPrivate || cached.isPrivate,
      );
    }).toList();

    merged.addAll(secondaryById.values);
    return _sortEvidences(merged);
  }

  List<EvidenceAttachmentRecord> _sortEvidences(
    List<EvidenceAttachmentRecord> evidences,
  ) {
    final sorted = [...evidences];
    sorted.sort((left, right) => _compareDateStrings(
      right.capturedAt,
      left.capturedAt,
    ));
    return sorted;
  }

  int _compareIncidents(
    EvidenceIncidentRecord left,
    EvidenceIncidentRecord right,
  ) {
    return _compareDateStrings(right.recordedAt, left.recordedAt);
  }

  int _compareDateStrings(String left, String right) {
    final leftDate = DateTime.tryParse(left);
    final rightDate = DateTime.tryParse(right);

    if (leftDate == null && rightDate == null) {
      return 0;
    }
    if (leftDate == null) {
      return 1;
    }
    if (rightDate == null) {
      return -1;
    }

    return leftDate.compareTo(rightDate);
  }

  List<Map<String, dynamic>> _extractList(
    dynamic source, {
    List<String> candidateKeys = const <String>[],
  }) {
    if (source is List) {
      return source
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    if (source is Map) {
      for (final key in candidateKeys) {
        final nested = source[key];
        if (nested is List) {
          return nested
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      }
    }

    return const <Map<String, dynamic>>[];
  }

  String _mapLoadError(ApiException error) {
    final lowerMessage = error.message.toLowerCase();
    if (lowerMessage.contains('no se pudo conectar con el servidor')) {
      return 'No se pudo actualizar el historial. Vuelve a intentarlo con internet.';
    }

    return 'No se pudo cargar tu historial de incidentes y evidencias.';
  }

  String _normalizeTitle(String value, {required String fallback}) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    return normalized.isEmpty ? fallback : normalized;
  }

  String _incidentKey(EvidenceIncidentRecord incident) {
    if (incident.id.trim().isNotEmpty) {
      return incident.id.trim();
    }

    return '${incident.recordedAt}|${incident.title}';
  }

  String _evidenceKey(EvidenceAttachmentRecord evidence) {
    if (evidence.id.trim().isNotEmpty) {
      return evidence.id.trim();
    }

    return '${evidence.incidentId}|${evidence.capturedAt}|${evidence.title}';
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

bool _readBool(dynamic value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == '0') {
      return false;
    }
  }
  return fallback;
}

String _preferFilled(String primary, String fallback) {
  return primary.trim().isNotEmpty ? primary : fallback;
}

String _defaultEvidenceTitle(String type) {
  switch (type) {
    case 'video':
      return 'Video';
    case 'audio':
      return 'Audio';
    case 'imagen':
      return 'Imagen';
    default:
      return 'Archivo';
  }
}
