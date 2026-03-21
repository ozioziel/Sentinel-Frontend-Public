import 'dart:async';
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

  String? detectEvidenceTypeForFile(String filePath) {
    final mimeType = lookupMimeType(filePath) ?? _fallbackMimeType(filePath);
    return _inferEvidenceType(mimeType, filePath);
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
      if (_isSchemaCacheError(error)) {
        final localEvidence = EvidenceRecord(
          id: _buildLocalEvidenceId(),
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

        await upsertCachedEvidence(userId: user.id, evidence: localEvidence);

        return EvidenceMutationResult(
          success: true,
          message: _schemaCacheLocalSaveMessage(
            es: 'La evidencia se guardo solo en este dispositivo mientras el servidor actualiza su esquema.',
            en: 'The evidence was saved only on this device while the server refreshes its schema.',
            ay: 'Servidorax esquema machaqt\'ayaskipanx evidenciax aka dispositivon sapaki imatawa.',
            qu: 'Servidorqa esquema musuqyachisqankama evidenciataqa kay dispositivollapim waqaychasqa karqan.',
          ),
          evidence: localEvidence,
        );
      }

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
    final normalizedEvidenceId = evidence.id.trim();
    final normalizedIncidentId = _normalizeNullableId(incidentId);

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

    if (normalizedEvidenceId.isEmpty) {
      return EvidenceMutationResult(
        success: false,
        message: _t(
          es: 'La evidencia no tiene un identificador valido para sincronizar su asociacion.',
          en: 'The evidence does not have a valid identifier to sync its association.',
          ay: 'Evidenciax janiw valido identificadoranix asociacion sincronizañataki.',
          qu: 'Evidenciaqa mana allin identificadoryuqchu asociacionninta sincronizanapaq.',
        ),
      );
    }

    if (_isLocalId(normalizedIncidentId)) {
      return EvidenceMutationResult(
        success: false,
        message: _t(
          es: 'El incidente seleccionado aun no esta sincronizado con el servidor. Espera a que se registre y vuelve a intentarlo.',
          en: 'The selected incident is not yet synced with the server. Wait for it to be registered and try again.',
          ay: 'Ajllita incidentex janiw servidorampi sincronizatakiti. Qillqantatañap suyt\'am ukat wasitat yant\'am.',
          qu: 'Akllasqa incidenteqa manaraqmi servidorwan sincronizakunchu. Qillqasqa kananpaq suyay hinaspa yapamanta yant\'ay.',
        ),
      );
    }

    if (_isLocalId(normalizedEvidenceId)) {
      if (normalizedIncidentId == null) {
        return _saveAssociationLocally(
          userId: user.id,
          evidence: evidence,
          incidentId: null,
        );
      }

      return EvidenceMutationResult(
        success: false,
        message: _t(
          es: 'La evidencia aun no esta sincronizada con el servidor. Cuando termine de registrarse podras asociarla a un incidente.',
          en: 'The evidence is not yet synced with the server. Once it finishes registering, you will be able to link it to an incident.',
          ay: 'Evidenciax janiw servidorampi sincronizatakiti. Qillqantasiñ tukuyatatxa incidenteru mayachasmawa.',
          qu: 'Evidenciaqa manaraqmi servidorwan sincronizakunchu. Qillqakuyta tukuruptinmi incidenteman tinkichiyta atinki.',
        ),
      );
    }

    if (normalizedIncidentId == null && _isLocalId(evidence.incidentId)) {
      return _saveAssociationLocally(
        userId: user.id,
        evidence: evidence,
        incidentId: null,
      );
    }

    try {
      final response = await _retryWithBackoff(
        () => _apiClient.putJson(
          '/evidences/$normalizedEvidenceId/incident',
          accessToken: user.accessToken,
          body: {'incident_id': normalizedIncidentId},
        ),
        (error) => error is ApiException && _isSchemaCacheError(error),
        3, // Máximo 3 reintentos
      );

      final updatedEvidence =
          _extractEvidenceDetail(response) ??
          evidence.copyWith(
            incidentId: normalizedIncidentId,
            clearIncidentId: normalizedIncidentId == null,
          );

      await upsertCachedEvidence(userId: user.id, evidence: updatedEvidence);

      return EvidenceMutationResult(
        success: true,
        message: normalizedIncidentId == null
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
      final confirmedEvidence = await _confirmAssociationState(
        accessToken: user.accessToken,
        evidenceId: normalizedEvidenceId,
        expectedIncidentId: normalizedIncidentId,
      );
      if (confirmedEvidence != null) {
        await upsertCachedEvidence(
          userId: user.id,
          evidence: confirmedEvidence,
        );
        return EvidenceMutationResult(
          success: true,
          message: _associationSuccessMessage(normalizedIncidentId),
          evidence: confirmedEvidence,
        );
      }

      if (_isSchemaCacheError(error)) {
        if (normalizedIncidentId == null) {
          return _saveAssociationLocally(
            userId: user.id,
            evidence: evidence,
            incidentId: null,
          );
        }

        return EvidenceMutationResult(
          success: false,
          message: _t(
            es: 'No se pudo sincronizar la asociacion con el incidente porque el servidor esta actualizando su esquema. Reintenta en unos minutos.',
            en: 'The association with the incident could not be synced because the server is updating its schema. Try again in a few minutes.',
            ay: 'Servidorax esquema machaqt\'ayaskipanwa incidente mayachawix janiw sincronizaskaspati. Mä juk\'a minutonakat qhipat wasitat yant\'am.',
            qu: 'Servidorqa esquemanta musuqyachisqanrayku incidentewan asociacionqa mana sincronizakuyta atikurqanchu. Huk chhika minutokunamanta qhipaman yapamanta yant\'ay.',
          ),
        );
      }

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
    if (_isSchemaCacheError(error)) {
      return _t(
        es: 'El servidor esta actualizando el esquema de evidencias. Si tienes datos locales, se mostraran mientras tanto.',
        en: 'The server is refreshing the evidence schema. If you have local data, it will be shown in the meantime.',
        ay: 'Servidorax evidencianakan esquemap machaqt\'ayaski. Local datonakax utjchi ukhax ukañkamaw uñstani.',
        qu: 'Servidorqa evidenciakunapa esquemanta musuqyachishan. Local datokuna kaptinqa, chaykamallam rikuchisqa kanqa.',
      );
    }

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
    if (_isSchemaCacheError(error)) {
      return _schemaCacheLocalSaveMessage(
        es: 'El servidor esta actualizando el esquema de evidencias. Reintenta en unos minutos si necesitas sincronizar.',
        en: 'The server is refreshing the evidence schema. Retry in a few minutes if you need to sync.',
        ay: 'Servidorax evidencianakan esquemap machaqt\'ayaski. Sincronizañ munasax mä juk\'a minutonakat qhipat wasitat yant\'am.',
        qu: 'Servidorqa evidenciakunapa esquemanta musuqyachishan. Sincronizayta munaspaykiqa huk chhika minutokunamanta qhipaman yapamanta yant\'ay.',
      );
    }

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
    if (_isSchemaCacheError(error)) {
      return _schemaCacheLocalSaveMessage(
        es: 'La asociacion se guardo solo de forma local mientras el servidor actualiza su esquema.',
        en: 'The association was saved only locally while the server refreshes its schema.',
        ay: 'Servidorax esquema machaqt\'ayaskipanx asociacionax localan sapaki imatawa.',
        qu: 'Servidorqa esquema musuqyachishankama asociacionqa localllapim waqaychasqa karqan.',
      );
    }

    final normalized = error.message.toLowerCase();
    if (_isGenericHttpError(error, statusCode: 400)) {
      return _t(
        es: 'El servidor rechazo la asociacion de la evidencia (HTTP 400). El endpoint PUT /evidences/:id/incident no esta aceptando la solicitud correctamente.',
        en: 'The server rejected the evidence association (HTTP 400). The PUT /evidences/:id/incident endpoint is not accepting the request correctly.',
        ay: 'Servidorax evidencia mayachawiruxa janiw katuqkiti (HTTP 400). PUT /evidences/:id/incident endpoint ukax mayiw sum katuqkiti.',
        qu: 'Servidorqa evidencia asociacionta mana chaskirqanchu (HTTP 400). PUT /evidences/:id/incident endpoint nisqaqa mañakuyta mana allintachu chaskishan.',
      );
    }
    if (_isGenericHttpError(error, statusCode: 404)) {
      return _t(
        es: 'El endpoint de asociacion PUT /evidences/:id/incident no esta disponible en el servidor actual.',
        en: 'The PUT /evidences/:id/incident association endpoint is not available on the current server.',
        ay: 'PUT /evidences/:id/incident endpoint ukax jichha servidoranx janiw utjkiti.',
        qu: 'PUT /evidences/:id/incident endpoint nisqaqa kay servidorpin mana kanchu.',
      );
    }
    if (normalized.contains('uuid invalido') ||
        normalized.contains('invalid input syntax for type uuid')) {
      return _t(
        es: 'El identificador del incidente o de la evidencia no tiene un formato UUID valido.',
        en: 'The incident or evidence identifier does not have a valid UUID format.',
        ay: 'Incidente jan ukax evidencia identificadorapax janiw UUID valido formato niykiti.',
        qu: 'Incidente utaq evidencia identificadorninqa mana allin UUID formato niyuqchu.',
      );
    }
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

  Future<T> _retryWithBackoff<T>(
    Future<T> Function() operation,
    bool Function(dynamic) isRetryableError,
    int maxRetries,
  ) async {
    int attempt = 0;
    while (attempt < maxRetries) {
      try {
        return await operation();
      } catch (error) {
        attempt++;
        if (attempt >= maxRetries || !isRetryableError(error)) {
          rethrow;
        }
        // Backoff exponencial: 1s, 2s, 4s, etc.
        final delay = Duration(seconds: 1 << (attempt - 1));
        await Future.delayed(delay);
      }
    }
    throw Exception('Max retries exceeded');
  }

  bool _isGenericHttpError(ApiException error, {required int statusCode}) {
    final normalized = error.message.trim().toLowerCase();
    return error.statusCode == statusCode &&
        (normalized.isEmpty ||
            normalized == 'error del servidor.' ||
            normalized == 'operacion fallida.' ||
            normalized == 'server error.' ||
            normalized == 'operation failed.');
  }

  bool _isLocalId(String? value) {
    final normalized = (value ?? '').trim();
    return normalized.startsWith('local-');
  }

  String? _normalizeNullableId(String? value) {
    final normalized = (value ?? '').trim();
    return normalized.isEmpty ? null : normalized;
  }

  String _buildLocalEvidenceId() {
    return 'local-evidence-${DateTime.now().microsecondsSinceEpoch}';
  }

  String _schemaCacheLocalSaveMessage({
    required String es,
    required String en,
    required String ay,
    required String qu,
  }) {
    return _t(es: es, en: en, ay: ay, qu: qu);
  }

  String _associationSuccessMessage(String? incidentId) {
    return incidentId == null
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
          );
  }

  Future<EvidenceRecord?> _confirmAssociationState({
    required String accessToken,
    required String evidenceId,
    required String? expectedIncidentId,
  }) async {
    try {
      final response = await _apiClient.getJson(
        '/evidences/$evidenceId',
        accessToken: accessToken,
      );
      final refreshedEvidence = _extractEvidenceDetail(response);
      if (refreshedEvidence == null) {
        return null;
      }

      final normalizedRefreshedIncidentId = _normalizeNullableId(
        refreshedEvidence.incidentId,
      );
      if (normalizedRefreshedIncidentId == expectedIncidentId) {
        return refreshedEvidence;
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<EvidenceMutationResult> _saveAssociationLocally({
    required String userId,
    required EvidenceRecord evidence,
    required String? incidentId,
  }) async {
    final updatedEvidence = evidence.copyWith(
      incidentId: incidentId,
      clearIncidentId: incidentId == null,
    );

    await upsertCachedEvidence(userId: userId, evidence: updatedEvidence);

    return EvidenceMutationResult(
      success: true,
      message: incidentId == null
          ? _t(
              es: 'La evidencia quedo sin incidente asociado en este dispositivo.',
              en: 'The evidence was left without an associated incident on this device.',
              ay: 'Evidenciax aka dispositivon janiw incidenter mayachatakiti.',
              qu: 'Evidenciaqa kay dispositivopi mana incidentewan tinkisqachu kipakun.',
            )
          : _t(
              es: 'La asociacion de la evidencia se guardo localmente en este dispositivo.',
              en: 'The evidence association was saved locally on this device.',
              ay: 'Evidencia mayachawix aka dispositivon localan imatawa.',
              qu: 'Evidencia asociacionninqa kay dispositivopi localpim waqaychasqa karqan.',
            ),
      evidence: updatedEvidence,
    );
  }
}
