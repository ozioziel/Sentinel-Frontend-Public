import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../auth/presentation/services/auth_service.dart';
import '../../domain/models/incident_record.dart';

class IncidentListResult {
  final List<IncidentRecord> incidents;
  final bool fromCache;
  final String? message;

  const IncidentListResult({
    required this.incidents,
    required this.fromCache,
    this.message,
  });
}

class IncidentMutationResult {
  final bool success;
  final IncidentRecord? incident;
  final String message;

  const IncidentMutationResult({
    required this.success,
    required this.message,
    this.incident,
  });
}

class IncidentService {
  static const _cacheKeyPrefix = 'incident_records_cache_';

  final AuthService _authService;
  final ApiClient _apiClient;

  IncidentService({AuthService? authService, ApiClient? apiClient})
    : _authService = authService ?? AuthService(),
      _apiClient = apiClient ?? ApiClient();

  Future<IncidentListResult> loadIncidents() async {
    final user = await _authService.getSession();
    if (user == null) {
      return const IncidentListResult(
        incidents: [],
        fromCache: true,
        message: 'Inicia sesion para ver tus incidentes.',
      );
    }

    final cached = await _loadCachedIncidents(user.id);

    try {
      final response = await _apiClient.getJson(
        '/incidents',
        accessToken: user.accessToken,
      );
      final incidents = _extractIncidentList(response);
      await _saveCachedIncidents(user.id, incidents);

      return IncidentListResult(
        incidents: incidents,
        fromCache: false,
        message: incidents.isEmpty
            ? 'Todavia no tienes incidentes registrados.'
            : null,
      );
    } on ApiException catch (error) {
      return IncidentListResult(
        incidents: cached,
        fromCache: true,
        message: cached.isEmpty
            ? _mapLoadError(error)
            : 'Mostrando incidentes guardados en este dispositivo.',
      );
    } catch (_) {
      return IncidentListResult(
        incidents: cached,
        fromCache: true,
        message: cached.isEmpty
            ? 'No se pudo cargar tu historial de incidentes.'
            : 'Mostrando incidentes guardados en este dispositivo.',
      );
    }
  }

  Future<IncidentMutationResult> updateIncidentDetails({
    required IncidentRecord incident,
    required String title,
    required String description,
  }) async {
    final normalizedTitle = title.trim().isEmpty
        ? incident.title
        : title.trim();
    final updatedIncident = incident.copyWith(
      title: normalizedTitle,
      description: description.trim(),
    );

    final user = await _authService.getSession();
    if (user != null) {
      await upsertCachedIncident(userId: user.id, incident: updatedIncident);
    }

    if (user == null) {
      return IncidentMutationResult(
        success: true,
        message: 'Los cambios se guardaron solo en este dispositivo.',
        incident: updatedIncident,
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

      return IncidentMutationResult(
        success: true,
        message: 'Incidente actualizado correctamente.',
        incident: updatedIncident,
      );
    } on ApiException catch (error) {
      return IncidentMutationResult(
        success: true,
        message:
            'Se guardo localmente. No se pudo sincronizar el incidente: ${error.message}',
        incident: updatedIncident,
      );
    } catch (_) {
      return IncidentMutationResult(
        success: true,
        message: 'Se guardo localmente. No se pudo sincronizar el incidente.',
        incident: updatedIncident,
      );
    }
  }

  Future<void> upsertCachedIncident({
    required String userId,
    required IncidentRecord incident,
  }) async {
    final incidents = await _loadCachedIncidents(userId);
    final index = incidents.indexWhere((item) => item.id == incident.id);
    if (index == -1) {
      incidents.insert(0, incident);
    } else {
      incidents[index] = incident;
    }
    await _saveCachedIncidents(userId, incidents);
  }

  Future<List<IncidentRecord>> _loadCachedIncidents(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_cacheKeyPrefix$userId');
    if (raw == null || raw.trim().isEmpty) {
      return <IncidentRecord>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <IncidentRecord>[];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => IncidentRecord.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (_) {
      return <IncidentRecord>[];
    }
  }

  Future<void> _saveCachedIncidents(
    String userId,
    List<IncidentRecord> incidents,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_cacheKeyPrefix$userId',
      jsonEncode(incidents.map((item) => item.toJson()).toList()),
    );
  }

  List<IncidentRecord> _extractIncidentList(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map(
            (item) =>
                IncidentRecord.fromBackendJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    }

    if (data is Map) {
      for (final key in const ['incidents', 'items', 'rows']) {
        final nested = data[key];
        if (nested is List) {
          return nested
              .whereType<Map>()
              .map(
                (item) => IncidentRecord.fromBackendJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList();
        }
      }
    }

    return const <IncidentRecord>[];
  }

  String _mapLoadError(ApiException error) {
    final normalized = error.message.toLowerCase();
    if (normalized.contains('no se pudo conectar con el servidor')) {
      return 'No se pudo actualizar el historial de incidentes. Revisa tu conexion.';
    }
    return error.message;
  }
}
