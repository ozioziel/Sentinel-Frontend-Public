import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/localization/app_language_service.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/services/offline_sync_service.dart';
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

  String _t({
    required String es,
    required String en,
    required String ay,
    required String qu,
  }) {
    return AppLanguageService.instance.pick(es: es, en: en, ay: ay, qu: qu);
  }

  Future<IncidentListResult> loadIncidents() async {
    final user = await _authService.getSession();
    if (user == null) {
      return IncidentListResult(
        incidents: [],
        fromCache: true,
        message: _t(
          es: 'Inicia sesion para ver tus incidentes.',
          en: 'Sign in to see your incidents.',
          ay: 'Incidentenakama uñjañatakix sesion qalltaya.',
          qu: 'Incidenteykikunata rikunaykipaq sesionta qallarichiy.',
        ),
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
            ? _t(
                es: 'Todavia no tienes incidentes registrados.',
                en: 'You do not have any registered incidents yet.',
                ay: 'Jichhakamax janiw qillqtata incidentenakam utjkiti.',
                qu: 'Manaraq incidenteykikuna qillqasqachu kashan.',
              )
            : null,
      );
    } on ApiException catch (error) {
      return IncidentListResult(
        incidents: cached,
        fromCache: true,
        message: cached.isEmpty
            ? _mapLoadError(error)
            : _t(
                es: 'Mostrando incidentes guardados en este dispositivo.',
                en: 'Showing incidents saved on this device.',
                ay: 'Aka dispositivon imata incidentenakwa uñstaski.',
                qu: 'Kay dispositivopi waqaychasqa incidentekuna rikuchisqa kashan.',
              ),
      );
    } catch (_) {
      return IncidentListResult(
        incidents: cached,
        fromCache: true,
        message: cached.isEmpty
            ? _t(
                es: 'No se pudo cargar tu historial de incidentes.',
                en: 'Your incident history could not be loaded.',
                ay: 'Janiw incidentenakan historialamax cargañjamakiti.',
                qu: 'Incidente historiaykiqa mana cargayta atikurqanchu.',
              )
            : _t(
                es: 'Mostrando incidentes guardados en este dispositivo.',
                en: 'Showing incidents saved on this device.',
                ay: 'Aka dispositivon imata incidentenakwa uñstaski.',
                qu: 'Kay dispositivopi waqaychasqa incidentekuna rikuchisqa kashan.',
              ),
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
        message: _t(
          es: 'Los cambios se guardaron solo en este dispositivo.',
          en: 'The changes were saved only on this device.',
          ay: 'Mayjtawinakax aka dispositivon sapaki imatawa.',
          qu: 'Tukuy tikraykunaqa kay dispositivollapim waqaychasqa karqan.',
        ),
        incident: updatedIncident,
      );
    }

    if (_isLocalId(updatedIncident.id)) {
      await OfflineSyncService.instance.enqueueUpdateIncident(
        userId: user.id,
        incident: updatedIncident,
      );
      return IncidentMutationResult(
        success: true,
        message: _t(
          es: 'Los cambios se guardaron localmente y se sincronizaran cuando vuelva la conexion.',
          en: 'The changes were saved locally and will sync when the connection returns.',
          ay: 'Mayjtawinakax localan imatawa ukat conexion kuttanxasax sincronizataniwa.',
          qu: 'Tikraykunaqa localpim waqaychasqa kashan hinaspa conexion kutimuptin sincronizakunqa.',
        ),
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
        message: _t(
          es: 'Incidente actualizado correctamente.',
          en: 'Incident updated successfully.',
          ay: 'Incidentex wali sum machaqtayatawa.',
          qu: 'Incidenteqa allinta musuqyachisqa karqan.',
        ),
        incident: updatedIncident,
      );
    } on ApiException catch (error) {
      if (_shouldSaveLocally(error)) {
        await OfflineSyncService.instance.enqueueUpdateIncident(
          userId: user.id,
          incident: updatedIncident,
        );
        return IncidentMutationResult(
          success: true,
          message:
              '${_t(es: 'Se guardo localmente.', en: 'It was saved locally.', ay: 'Localan imatawa.', qu: 'Localpim waqaychasqa karqan.')} ${_t(es: 'Se sincronizara cuando vuelva la conexion.', en: 'It will sync when the connection returns.', ay: 'Conexion kuttanxasax sincronizataniwa.', qu: 'Conexion kutimuptinmi sincronizakunqa.')}',
          incident: updatedIncident,
        );
      }

      return IncidentMutationResult(
        success: true,
        message:
            '${_t(es: 'Se guardo localmente.', en: 'It was saved locally.', ay: 'Localan imatawa.', qu: 'Localpim waqaychasqa karqan.')} ${_t(es: 'No se pudo sincronizar el incidente:', en: 'The incident could not be synced:', ay: 'Janiw incidentex sincronizañjamakiti:', qu: 'Incidenteqa mana sincronizayta atikurqanchu:')} ${error.message}',
        incident: updatedIncident,
      );
    } catch (_) {
      await OfflineSyncService.instance.enqueueUpdateIncident(
        userId: user.id,
        incident: updatedIncident,
      );
      return IncidentMutationResult(
        success: true,
        message:
            '${_t(es: 'Se guardo localmente.', en: 'It was saved locally.', ay: 'Localan imatawa.', qu: 'Localpim waqaychasqa karqan.')} ${_t(es: 'Se sincronizara cuando vuelva la conexion.', en: 'It will sync when the connection returns.', ay: 'Conexion kuttanxasax sincronizataniwa.', qu: 'Conexion kutimuptinmi sincronizakunqa.')}',
        incident: updatedIncident,
      );
    }
  }

  Future<IncidentMutationResult> createIncident({
    required String title,
    String description = '',
    String type = 'violencia',
    String status = 'registrado',
    String riskLevel = 'medio',
    String location = '',
    DateTime? occurredAt,
  }) async {
    final user = await _authService.getSession();
    if (user == null) {
      return IncidentMutationResult(
        success: false,
        message: _t(
          es: 'No hay una sesion activa para crear incidentes.',
          en: 'There is no active session to create incidents.',
          ay: 'Janiw incidentenak lurañatakix sesion activa utjkiti.',
          qu: 'Incidentekunata ruwanapaq sesion activaqa mana kanchu.',
        ),
      );
    }

    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      return IncidentMutationResult(
        success: false,
        message: _t(
          es: 'Escribe un titulo para el incidente.',
          en: 'Enter a title for the incident.',
          ay: 'Incidentetaki maya titulo qillqtam.',
          qu: 'Incidentepaqqa huk sutita qillqay.',
        ),
      );
    }

    final responseDate = (occurredAt ?? DateTime.now())
        .toUtc()
        .toIso8601String();

    try {
      final response = await _apiClient.postJson(
        '/incidents',
        accessToken: user.accessToken,
        body: {
          'titulo': normalizedTitle,
          'descripcion': description.trim(),
          'tipo_incidente': type.trim().isEmpty ? 'general' : type.trim(),
          'fecha_incidente': responseDate,
          'lugar': location.trim(),
          'nivel_riesgo': riskLevel.trim().isEmpty
              ? 'sin definir'
              : riskLevel.trim(),
          'estado': status.trim().isEmpty ? 'registrado' : status.trim(),
        },
      );

      final createdIncident =
          _extractIncidentDetail(response) ??
          IncidentRecord(
            id: '',
            title: normalizedTitle,
            description: description.trim(),
            type: type.trim().isEmpty ? 'general' : type.trim(),
            status: status.trim().isEmpty ? 'registrado' : status.trim(),
            riskLevel: riskLevel.trim().isEmpty
                ? 'sin definir'
                : riskLevel.trim(),
            location: location.trim(),
            occurredAt: responseDate,
          );

      if (createdIncident.id.trim().isEmpty) {
        return IncidentMutationResult(
          success: false,
          message: _t(
            es: 'El servidor no devolvio un incidente valido.',
            en: 'The server did not return a valid incident.',
            ay: 'Servidorax janiw valido incidente kuttaykiti.',
            qu: 'Servidorqa mana allin incidente kutichirqanchu.',
          ),
        );
      }

      await upsertCachedIncident(userId: user.id, incident: createdIncident);

      return IncidentMutationResult(
        success: true,
        message: _t(
          es: 'Incidente creado correctamente.',
          en: 'Incident created successfully.',
          ay: 'Incidentex wali sum luratawa.',
          qu: 'Incidenteqa allinta ruwasqa karqan.',
        ),
        incident: createdIncident,
      );
    } on ApiException catch (error) {
      if (_shouldSaveLocally(error)) {
        final localIncident = IncidentRecord(
          id: _buildLocalIncidentId(),
          title: normalizedTitle,
          description: description.trim(),
          type: type.trim().isEmpty ? 'violencia' : type.trim(),
          status: status.trim().isEmpty ? 'registrado' : status.trim(),
          riskLevel: riskLevel.trim().isEmpty ? 'medio' : riskLevel.trim(),
          location: location.trim(),
          occurredAt: responseDate,
        );

        await upsertCachedIncident(userId: user.id, incident: localIncident);
        await OfflineSyncService.instance.enqueueCreateIncident(
          userId: user.id,
          incident: localIncident,
        );

        return IncidentMutationResult(
          success: true,
          message: _t(
            es: 'El incidente se guardo localmente y se sincronizara cuando vuelva la conexion.',
            en: 'The incident was saved locally and will sync when the connection returns.',
            ay: 'Incidentex localan imatawa ukat conexion kuttanxasax sincronizataniwa.',
            qu: 'Incidenteqa localpim waqaychasqa karqan hinaspa conexion kutimuptin sincronizakunqa.',
          ),
          incident: localIncident,
        );
      }

      return IncidentMutationResult(
        success: false,
        message: _mapCreateError(error),
      );
    } catch (_) {
      final localIncident = IncidentRecord(
        id: _buildLocalIncidentId(),
        title: normalizedTitle,
        description: description.trim(),
        type: type.trim().isEmpty ? 'violencia' : type.trim(),
        status: status.trim().isEmpty ? 'registrado' : status.trim(),
        riskLevel: riskLevel.trim().isEmpty ? 'medio' : riskLevel.trim(),
        location: location.trim(),
        occurredAt: responseDate,
      );

      await upsertCachedIncident(userId: user.id, incident: localIncident);
      await OfflineSyncService.instance.enqueueCreateIncident(
        userId: user.id,
        incident: localIncident,
      );

      return IncidentMutationResult(
        success: true,
        message: _t(
          es: 'El incidente se guardo localmente y se sincronizara cuando vuelva la conexion.',
          en: 'The incident was saved locally and will sync when the connection returns.',
          ay: 'Incidentex localan imatawa ukat conexion kuttanxasax sincronizataniwa.',
          qu: 'Incidenteqa localpim waqaychasqa karqan hinaspa conexion kutimuptin sincronizakunqa.',
        ),
        incident: localIncident,
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

  IncidentRecord? _extractIncidentDetail(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return IncidentRecord.fromBackendJson(data);
    }
    if (data is Map) {
      return IncidentRecord.fromBackendJson(Map<String, dynamic>.from(data));
    }
    if (response['id'] != null) {
      return IncidentRecord.fromBackendJson(response);
    }
    return null;
  }

  String _mapLoadError(ApiException error) {
    if (_isSchemaCacheError(error)) {
      return _t(
        es: 'El servidor esta actualizando el esquema de incidentes. Si tienes datos locales, se mostraran mientras tanto.',
        en: 'The server is refreshing the incident schema. If you have local data, it will be shown in the meantime.',
        ay: 'Servidorax incidentenakan esquemap machaqtayaski. Local datonakax utjchi ukhax ukañkamaw uñstani.',
        qu: 'Servidorqa incidentekunapa esquemanta musuqyachishan. Local datokuna kaptinqa, chaykamallam rikuchisqa kanqa.',
      );
    }

    final normalized = error.message.toLowerCase();
    if (normalized.contains('no se pudo conectar con el servidor')) {
      return _t(
        es: 'No se pudo actualizar el historial de incidentes. Revisa tu conexion.',
        en: 'The incident history could not be updated. Check your connection.',
        ay: 'Janiw incidenten historialapax machaqtayañjamakiti. Conexion uñakipam.',
        qu: 'Incidente historiaykiqa mana musuqyachiyta atikurqanchu. Conexionniykita qhawariy.',
      );
    }
    return error.message;
  }

  String _mapCreateError(ApiException error) {
    if (_isSchemaCacheError(error)) {
      return _t(
        es: 'El servidor esta actualizando el esquema de incidentes. Reintenta en unos minutos si necesitas sincronizar.',
        en: 'The server is refreshing the incident schema. Retry in a few minutes if you need to sync.',
        ay: 'Servidorax incidentenakan esquemap machaqtayaski. Sincronizañ munasax maya juka minutonakat qhipat wasitat yantam.',
        qu: 'Servidorqa incidentekunapa esquemanta musuqyachishan. Sincronizayta munaspaykiqa huk chhika minutokunamanta qhipaman yapamanta yantay.',
      );
    }

    final normalized = error.message.toLowerCase();
    if (normalized.contains('perfil no encontrado')) {
      return _t(
        es: 'La cuenta esta autenticada, pero no tiene perfil en el backend.',
        en: 'The account is authenticated, but it does not have a backend profile.',
        ay: 'Cuentax autenticatawa, ukampis backend ukanx janiw perfilani.',
        qu: 'Cuentaqa autenticada kashan, ichaqa backendpi perfilninta mana kanchu.',
      );
    }
    if (normalized.contains('no se pudo conectar con el servidor')) {
      return _t(
        es: 'No se pudo crear el incidente. Revisa tu conexion.',
        en: 'The incident could not be created. Check your connection.',
        ay: 'Janiw incidente lurañjamakiti. Conexion uñakipam.',
        qu: 'Incidenteqa mana ruwayta atikurqanchu. Conexionniykita qhawariy.',
      );
    }
    return error.message;
  }

  bool _isSchemaCacheError(ApiException error) {
    final detailsText = error.details?.toString() ?? '';
    final normalized = '${error.message} $detailsText'.toLowerCase();
    return normalized.contains('schema cache') ||
        normalized.contains('schema_cache') ||
        normalized.contains('pgrst204') ||
        normalized.contains('pgrst205') ||
        (normalized.contains('could not find') &&
            (normalized.contains('schema') ||
                normalized.contains('column') ||
                normalized.contains('relation'))) ||
        normalized.contains('no se encontro la columna') ||
        normalized.contains('no se encontro la relacion');
  }

  bool _shouldSaveLocally(ApiException error) {
    final normalized = '${error.message} ${error.details ?? ''}'.toLowerCase();
    return _isSchemaCacheError(error) ||
        normalized.contains('no se pudo conectar con el servidor') ||
        (error.statusCode != null && error.statusCode! >= 500);
  }

  bool _isLocalId(String id) {
    return id.trim().startsWith('local-');
  }

  String _buildLocalIncidentId() {
    return 'local-incident-${DateTime.now().microsecondsSinceEpoch}';
  }
}
