import 'dart:convert';
import 'dart:io';

import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/localization/app_language_service.dart';
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

  String _t({
    required String es,
    required String en,
    required String ay,
    required String qu,
  }) {
    return AppLanguageService.instance.pick(es: es, en: en, ay: ay, qu: qu);
  }

  Future<EvidenceListResult> loadEvidences() async {
    final user = await _authService.getSession();
    if (user == null) {
      return EvidenceListResult(
        evidences: [],
        fromCache: true,
        message: _t(
          es: 'Inicia sesion para ver tus evidencias.',
          en: 'Sign in to see your evidence.',
          ay: 'Evidencianakama uñjañatakix sesion qalltaya.',
          qu: 'Evidenciaykikunata rikunaykipaq sesionta qallarichiy.',
        ),
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
            ? _t(
                es: 'Todavia no tienes evidencias registradas.',
                en: 'You do not have any registered evidence yet.',
                ay: 'Jichhakamax janiw qillqt\'ata evidencianakaman utjkiti.',
                qu: 'Manaraq evidenciaykikuna qillqasqachu kashan.',
              )
            : null,
      );
    } on ApiException catch (error) {
      return EvidenceListResult(
        evidences: cached,
        fromCache: true,
        message: cached.isEmpty
            ? _mapLoadError(error)
            : _t(
                es: 'Mostrando evidencias guardadas en este dispositivo.',
                en: 'Showing evidence saved on this device.',
                ay: 'Aka dispositivon imata evidencianakwa uñstaski.',
                qu: 'Kay dispositivopi waqaychasqa evidenciakuna rikuchisqa kashan.',
              ),
      );
    } catch (_) {
      return EvidenceListResult(
        evidences: cached,
        fromCache: true,
        message: cached.isEmpty
            ? _t(
                es: 'No se pudo cargar tu bandeja de evidencias.',
                en: 'Your evidence inbox could not be loaded.',
                ay: 'Janiw evidencianakaman bandejax cargañjamakiti.',
                qu: 'Evidenciayki bandejaqa mana cargayta atikurqanchu.',
              )
            : _t(
                es: 'Mostrando evidencias guardadas en este dispositivo.',
                en: 'Showing evidence saved on this device.',
                ay: 'Aka dispositivon imata evidencianakwa uñstaski.',
                qu: 'Kay dispositivopi waqaychasqa evidenciakuna rikuchisqa kashan.',
              ),
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
        message: _t(
          es: 'Inicia sesion para abrir esta evidencia.',
          en: 'Sign in to open this evidence.',
          ay: 'Aka evidencia jist\'arañatakix sesion qalltaya.',
          qu: 'Kay evidenciata kicharinaykipaq sesionta qallarichiy.',
        ),
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
          message: _t(
            es: 'No se encontro detalle para esta evidencia.',
            en: 'No detail was found for this evidence.',
            ay: 'Aka evidenciatakix janiw detalle jikxataskiti.',
            qu: 'Kay evidenciapaq detalleqa mana tarikurqanchu.',
          ),
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
            : _t(
                es: 'Mostrando el ultimo detalle guardado localmente.',
                en: 'Showing the latest detail saved locally.',
                ay: 'Qhipa localan imata detallew uñstaski.',
                qu: 'Qhipa localpi waqaychasqa detalleqa rikuchisqa kashan.',
              ),
      );
    } catch (_) {
      final cached = await findCachedEvidence(user.id, evidenceId);
      return EvidenceDetailResult(
        success: cached != null || fallback != null,
        evidence: cached ?? fallback,
        message: cached == null && fallback == null
            ? _t(
                es: 'No se pudo abrir el detalle de la evidencia.',
                en: 'The evidence detail could not be opened.',
                ay: 'Janiw evidencia detallex jist\'arañjamakiti.',
                qu: 'Evidencia detalleqa mana kichariyta atikurqanchu.',
              )
            : _t(
                es: 'Mostrando el ultimo detalle guardado localmente.',
                en: 'Showing the latest detail saved locally.',
                ay: 'Qhipa localan imata detallew uñstaski.',
                qu: 'Qhipa localpi waqaychasqa detalleqa rikuchisqa kashan.',
              ),
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
      return EvidenceMutationResult(
        success: false,
        message: _t(
          es: 'No hay una sesion activa para subir evidencias.',
          en: 'There is no active session to upload evidence.',
          ay: 'Janiw evidencianak apkatañatakix sesion activa utjkiti.',
          qu: 'Evidenciakuna wicharinapaq sesion activaqa mana kanchu.',
        ),
      );
    }

    final file = File(filePath);
    if (!await file.exists()) {
      return EvidenceMutationResult(
        success: false,
        message: _t(
          es: 'El archivo seleccionado ya no existe.',
          en: 'The selected file no longer exists.',
          ay: 'Ajllita archivox janiw utjxiti.',
          qu: 'Akllasqa archivoqa manan kashanchu.',
        ),
      );
    }

    final sizeBytes = await file.length();
    if (sizeBytes > 20 * 1024 * 1024) {
      return EvidenceMutationResult(
        success: false,
        message: _t(
          es: 'El archivo supera el limite de 20 MB.',
          en: 'The file exceeds the 20 MB limit.',
          ay: 'Archivox 20 MB limite jilankiwa.',
          qu: 'Archivoqa 20 MB limiteta aswan hatunmi.',
        ),
      );
    }

    final mimeType = lookupMimeType(filePath) ?? _fallbackMimeType(filePath);
    final resolvedType = _normalizeRequestedType(
      selectedType,
      inferredType: _inferEvidenceType(mimeType, filePath),
    );

    if (mimeType == null) {
      return EvidenceMutationResult(
        success: false,
        message: _t(
          es: 'No se pudo reconocer el tipo del archivo seleccionado.',
          en: 'The selected file type could not be recognized.',
          ay: 'Ajllita archivon kastapax janiw uñt\'ayaskiti.',
          qu: 'Akllasqa archivopa kastanqa mana reqsiyta atikurqanchu.',
        ),
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

      var storedEvidence = createdEvidence;
      var successMessage = _t(
        es: 'Evidencia creada correctamente.',
        en: 'Evidence created successfully.',
        ay: 'Evidenciax wali sum luratawa.',
        qu: 'Evidenciaqa allinta ruwasqa karqan.',
      );

      if (storedEvidence.isAssociated && storedEvidence.id.trim().isNotEmpty) {
        final detachResult = await updateEvidenceIncident(
          evidence: storedEvidence,
          incidentId: null,
        );
        if (detachResult.success && detachResult.evidence != null) {
          storedEvidence = detachResult.evidence!;
          successMessage = _t(
            es: 'Evidencia creada sin incidente asociado.',
            en: 'Evidence created without an associated incident.',
            ay: 'Evidenciax janiw incidenter mayachatakiti luratawa.',
            qu: 'Evidenciaqa mana incidentewan tinkisqachu ruwasqa karqan.',
          );
        } else {
          successMessage = _t(
            es: 'La evidencia se creo, pero no se pudo quitar la asociacion automatica. Revisa el detalle para corregirla.',
            en: 'The evidence was created, but the automatic association could not be removed. Review the detail to fix it.',
            ay: 'Evidenciax luratawa, ukampis janiw automatico asociacion apaqañjamakiti. Detalle uñakipam askichañataki.',
            qu: 'Evidenciaqa ruwasqa karqan, ichaqa automatico asociacionqa mana qichuyta atikurqanchu. Detalleta qhawariy allichanapaq.',
          );
        }
      }

      await upsertCachedEvidence(userId: user.id, evidence: storedEvidence);

      return EvidenceMutationResult(
        success: true,
        message: successMessage,
        evidence: storedEvidence,
      );
    } on ApiException catch (error) {
      return EvidenceMutationResult(
        success: false,
        message: _mapCreateError(error),
      );
    } catch (_) {
      return EvidenceMutationResult(
        success: false,
        message: _t(
          es: 'No se pudo crear la evidencia.',
          en: 'The evidence could not be created.',
          ay: 'Janiw evidencia lurañjamakiti.',
          qu: 'Evidenciaqa mana ruwayta atikurqanchu.',
        ),
      );
    }
  }

  Future<EvidenceMutationResult> updateEvidenceIncident({
    required EvidenceRecord evidence,
    required String? incidentId,
  }) async {
    final user = await _authService.getSession();
    if (user == null) {
      return EvidenceMutationResult(
        success: false,
        message: _t(
          es: 'No hay una sesion activa para actualizar la asociacion.',
          en: 'There is no active session to update the association.',
          ay: 'Janiw asociacion machaqtayañatakix sesion activa utjkiti.',
          qu: 'Asociacionta musuqyachinapaq sesion activaqa mana kanchu.',
        ),
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
            ? _t(
                es: 'La evidencia quedo sin incidente asociado.',
                en: 'The evidence was left without an associated incident.',
                ay: 'Evidenciax janiw incidenter mayachatakiti.',
                qu: 'Evidenciaqa mana incidentewan tinkisqachu kipakun.',
              )
            : _t(
                es: 'La evidencia ahora esta asociada al incidente.',
                en: 'The evidence is now associated with the incident.',
                ay: 'Evidenciax jichhax incidenter mayachatawa.',
                qu: 'Evidenciaqa kunanqa incidentewan tinkisqa kashan.',
              ),
        evidence: updatedEvidence,
      );
    } on ApiException catch (error) {
      return EvidenceMutationResult(
        success: false,
        message: _mapAssociationError(error),
      );
    } catch (_) {
      return EvidenceMutationResult(
        success: false,
        message: _t(
          es: 'No se pudo actualizar la asociacion de la evidencia.',
          en: 'The evidence association could not be updated.',
          ay: 'Janiw evidencia mayachawix machaqtayañjamakiti.',
          qu: 'Evidenciawan asociacionninqa mana musuqyachiyta atikurqanchu.',
        ),
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
      return _t(
        es: 'No se pudo actualizar la bandeja de evidencias. Revisa tu conexion.',
        en: 'The evidence inbox could not be updated. Check your connection.',
        ay: 'Janiw evidencianak bandejax machaqtayañjamakiti. Conexion uñakipam.',
        qu: 'Evidencia bandejaqa mana musuqyachiyta atikurqanchu. Conexionniykita qhawariy.',
      );
    }
    return error.message;
  }

  String _mapCreateError(ApiException error) {
    final normalized = error.message.toLowerCase();
    if (normalized.contains('uuid invalido')) {
      return _t(
        es: 'La asociacion enviada para esta evidencia no es valida.',
        en: 'The association sent for this evidence is not valid.',
        ay: 'Aka evidenciatak apayata asociacionax janiw validokiti.',
        qu: 'Kay evidenciapaq apasqa asociacionqa mana allinchu.',
      );
    }
    if (normalized.contains('archivo no soportado') ||
        normalized.contains('tipo de archivo no permitido')) {
      return _t(
        es: 'El archivo seleccionado no tiene un formato permitido.',
        en: 'The selected file does not have an allowed format.',
        ay: 'Ajllita archivox janiw iyawsata formato niyki.',
        qu: 'Akllasqa archivoqa mana saqesqa formato niyuqchu.',
      );
    }
    if (normalized.contains('tipo_evidencia no coincide')) {
      return _t(
        es: 'El tipo de evidencia no coincide con el archivo elegido.',
        en: 'The evidence type does not match the chosen file.',
        ay: 'Evidencian kastapax ajllita archivompi janiw kikpkiti.',
        qu: 'Evidencia kastanqa akllasqa archivowan mana tupanchu.',
      );
    }
    return error.message;
  }

  String _mapAssociationError(ApiException error) {
    final normalized = error.message.toLowerCase();
    if (normalized.contains('incidente no encontrado')) {
      return _t(
        es: 'No se encontro el incidente seleccionado.',
        en: 'The selected incident was not found.',
        ay: 'Ajllita incidentex janiw jikxataskiti.',
        qu: 'Akllasqa incidenteqa mana tarikurqanchu.',
      );
    }
    if (normalized.contains('evidencia no encontrada')) {
      return _t(
        es: 'No se encontro la evidencia a actualizar.',
        en: 'The evidence to update was not found.',
        ay: 'Machaqtayañ evidencianix janiw jikxataskiti.',
        qu: 'Musuqyachina evidenciata mana tarikurqanchu.',
      );
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
