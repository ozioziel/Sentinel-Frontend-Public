import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/presentation/models/contact_model.dart';
import '../../features/auth/presentation/services/auth_identity_mapper.dart';
import '../../features/auth/presentation/services/auth_service.dart';
import '../../features/evidence/domain/models/evidence_record.dart';
import '../../features/incidents/domain/models/incident_record.dart';
import '../localization/app_language_service.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';

class OfflineSyncResult {
  final int syncedCount;
  final int remainingCount;
  final String message;

  const OfflineSyncResult({
    required this.syncedCount,
    required this.remainingCount,
    required this.message,
  });
}

class OfflineSyncService {
  OfflineSyncService._internal({
    AuthService? authService,
    ApiClient? apiClient,
    Connectivity? connectivity,
  }) : _authService = authService ?? AuthService(),
       _apiClient = apiClient ?? ApiClient(),
       _connectivity = connectivity ?? Connectivity();

  static final OfflineSyncService instance = OfflineSyncService._internal();

  static const _queueKey = 'offline_sync_queue_v1';
  static const _idMapPrefix = 'offline_sync_id_map_';
  static const _contactsCachePrefix = 'contacts_cache_';
  static const _contactEmailsPrefix = 'contact_emails_';
  static const _incidentCachePrefix = 'incident_records_cache_';
  static const _evidenceCachePrefix = 'evidence_records_cache_';

  static const _entityContact = 'contact';
  static const _entityIncident = 'incident';
  static const _entityEvidence = 'evidence';

  static const _actionCreate = 'create';
  static const _actionUpdate = 'update';
  static const _actionDelete = 'delete';
  static const _actionAttachIncident = 'attach_incident';

  final AuthService _authService;
  final ApiClient _apiClient;
  final Connectivity _connectivity;

  String _t({
    required String es,
    required String en,
    required String ay,
    required String qu,
  }) {
    return AppLanguageService.instance.pick(es: es, en: en, ay: ay, qu: qu);
  }

  Future<void> enqueueCreateContact({
    required String userId,
    required ContactModel contact,
  }) {
    return _enqueueOperation(
      _PendingSyncOperation(
        id: _buildOperationId(),
        userId: userId,
        entity: _entityContact,
        action: _actionCreate,
        payload: {'contact': contact.toJson()},
        createdAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }

  Future<void> enqueueUpdateContact({
    required String userId,
    required ContactModel contact,
  }) {
    return _enqueueOperation(
      _PendingSyncOperation(
        id: _buildOperationId(),
        userId: userId,
        entity: _entityContact,
        action: _actionUpdate,
        payload: {'contact': contact.toJson()},
        createdAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }

  Future<void> enqueueDeleteContact({
    required String userId,
    required String contactId,
  }) {
    return _enqueueOperation(
      _PendingSyncOperation(
        id: _buildOperationId(),
        userId: userId,
        entity: _entityContact,
        action: _actionDelete,
        payload: {'contact_id': contactId},
        createdAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }

  Future<void> enqueueCreateIncident({
    required String userId,
    required IncidentRecord incident,
  }) {
    return _enqueueOperation(
      _PendingSyncOperation(
        id: _buildOperationId(),
        userId: userId,
        entity: _entityIncident,
        action: _actionCreate,
        payload: {'incident': incident.toJson()},
        createdAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }

  Future<void> enqueueUpdateIncident({
    required String userId,
    required IncidentRecord incident,
  }) {
    return _enqueueOperation(
      _PendingSyncOperation(
        id: _buildOperationId(),
        userId: userId,
        entity: _entityIncident,
        action: _actionUpdate,
        payload: {'incident': incident.toJson()},
        createdAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }

  Future<void> enqueueCreateEvidence({
    required String userId,
    required EvidenceRecord evidence,
  }) {
    return _enqueueOperation(
      _PendingSyncOperation(
        id: _buildOperationId(),
        userId: userId,
        entity: _entityEvidence,
        action: _actionCreate,
        payload: {'evidence': evidence.toJson()},
        createdAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }

  Future<void> enqueueEvidenceAssociation({
    required String userId,
    required String evidenceId,
    required String? incidentId,
  }) {
    return _enqueueOperation(
      _PendingSyncOperation(
        id: _buildOperationId(),
        userId: userId,
        entity: _entityEvidence,
        action: _actionAttachIncident,
        payload: {'evidence_id': evidenceId, 'incident_id': incidentId},
        createdAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }

  Future<OfflineSyncResult?> retryPendingOperations() async {
    final session = await _authService.getSession();
    if (session == null || !await _hasInternetLikeConnection()) {
      return null;
    }

    final queue = await _loadQueue();
    final currentUserQueue = queue
        .where((item) => item.userId == session.id)
        .toList();
    if (currentUserQueue.isEmpty) {
      return null;
    }

    var remainingForUser = List<_PendingSyncOperation>.from(currentUserQueue);
    var syncedCount = 0;
    var madeProgress = false;
    var pass = 0;

    while (remainingForUser.isNotEmpty && pass < currentUserQueue.length + 2) {
      pass += 1;
      var progressedThisPass = false;
      final nextPass = <_PendingSyncOperation>[];

      for (var index = 0; index < remainingForUser.length; index += 1) {
        final operation = remainingForUser[index];
        final attempt = await _processOperation(
          session: session,
          operation: operation,
        );

        if (attempt.disposition == _SyncDisposition.done) {
          syncedCount += 1;
          progressedThisPass = true;
          madeProgress = true;
          continue;
        }

        if (attempt.disposition == _SyncDisposition.halt) {
          nextPass.add(operation);
          nextPass.addAll(remainingForUser.skip(index + 1));
          remainingForUser = nextPass;
          await _persistRemainingQueue(
            userId: session.id,
            queue: queue,
            remainingForUser: remainingForUser,
          );
          return madeProgress
              ? OfflineSyncResult(
                  syncedCount: syncedCount,
                  remainingCount: remainingForUser.length,
                  message: _buildSyncMessage(
                    syncedCount: syncedCount,
                    remainingCount: remainingForUser.length,
                  ),
                )
              : null;
        }

        nextPass.add(operation);
      }

      remainingForUser = nextPass;
      if (!progressedThisPass) {
        break;
      }
    }

    await _persistRemainingQueue(
      userId: session.id,
      queue: queue,
      remainingForUser: remainingForUser,
    );

    if (!madeProgress) {
      return null;
    }

    return OfflineSyncResult(
      syncedCount: syncedCount,
      remainingCount: remainingForUser.length,
      message: _buildSyncMessage(
        syncedCount: syncedCount,
        remainingCount: remainingForUser.length,
      ),
    );
  }

  Future<void> _enqueueOperation(_PendingSyncOperation operation) async {
    final queue = await _loadQueue();
    queue.add(operation);
    await _saveQueue(queue);
  }

  Future<_SyncAttemptResult> _processOperation({
    required UserModel session,
    required _PendingSyncOperation operation,
  }) async {
    try {
      if (operation.entity == _entityContact &&
          operation.action == _actionCreate) {
        return await _syncContactCreate(
          userId: session.id,
          accessToken: session.accessToken,
          operation: operation,
        );
      }
      if (operation.entity == _entityContact &&
          operation.action == _actionUpdate) {
        return await _syncContactUpdate(
          userId: session.id,
          accessToken: session.accessToken,
          operation: operation,
        );
      }
      if (operation.entity == _entityContact &&
          operation.action == _actionDelete) {
        return await _syncContactDelete(
          userId: session.id,
          accessToken: session.accessToken,
          operation: operation,
        );
      }
      if (operation.entity == _entityIncident &&
          operation.action == _actionCreate) {
        return await _syncIncidentCreate(
          userId: session.id,
          accessToken: session.accessToken,
          operation: operation,
        );
      }
      if (operation.entity == _entityIncident &&
          operation.action == _actionUpdate) {
        return await _syncIncidentUpdate(
          userId: session.id,
          accessToken: session.accessToken,
          operation: operation,
        );
      }
      if (operation.entity == _entityEvidence &&
          operation.action == _actionCreate) {
        return await _syncEvidenceCreate(
          userId: session.id,
          accessToken: session.accessToken,
          operation: operation,
        );
      }
      if (operation.entity == _entityEvidence &&
          operation.action == _actionAttachIncident) {
        return await _syncEvidenceAssociation(
          userId: session.id,
          accessToken: session.accessToken,
          operation: operation,
        );
      }
    } on ApiException catch (error) {
      if (_isTemporarySyncError(error)) {
        return const _SyncAttemptResult(_SyncDisposition.halt);
      }
      return const _SyncAttemptResult(_SyncDisposition.keep);
    } catch (_) {
      return const _SyncAttemptResult(_SyncDisposition.halt);
    }

    return const _SyncAttemptResult(_SyncDisposition.keep);
  }

  Future<void> _persistRemainingQueue({
    required String userId,
    required List<_PendingSyncOperation> queue,
    required List<_PendingSyncOperation> remainingForUser,
  }) async {
    final others = queue.where((item) => item.userId != userId).toList();
    others.addAll(remainingForUser);
    await _saveQueue(others);
  }

  Future<List<_PendingSyncOperation>> _loadQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey);
    if (raw == null || raw.trim().isEmpty) {
      return <_PendingSyncOperation>[];
    }

    try {
      final decoded = List<Map<String, dynamic>>.from(jsonDecode(raw) as List);
      return decoded.map(_PendingSyncOperation.fromJson).toList();
    } catch (_) {
      return <_PendingSyncOperation>[];
    }
  }

  Future<void> _saveQueue(List<_PendingSyncOperation> queue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _queueKey,
      jsonEncode(queue.map((item) => item.toJson()).toList()),
    );
  }

  Future<Map<String, String>> _loadIdMap(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_idMapPrefix$userId');
    if (raw == null || raw.trim().isEmpty) {
      return <String, String>{};
    }

    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return decoded.map((key, value) => MapEntry(key, _readString(value)))
        ..removeWhere((key, value) => value.trim().isEmpty);
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<void> _saveIdMap(String userId, Map<String, String> values) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_idMapPrefix$userId', jsonEncode(values));
  }

  Future<String?> _resolveRemoteId(String userId, String? value) async {
    final normalized = _readNullableString(value);
    if (normalized == null) {
      return null;
    }
    if (!_isLocalId(normalized)) {
      return normalized;
    }

    final idMap = await _loadIdMap(userId);
    return _readNullableString(idMap[normalized]);
  }

  Future<void> _rememberRemoteId({
    required String userId,
    required String localId,
    required String remoteId,
  }) async {
    if (!_isLocalId(localId) || remoteId.trim().isEmpty) {
      return;
    }

    final idMap = await _loadIdMap(userId);
    idMap[localId] = remoteId;
    await _saveIdMap(userId, idMap);

    if (localId.startsWith('local-incident-')) {
      await _replaceIncidentIdInCachedEvidences(
        userId: userId,
        previousIncidentId: localId,
        remoteIncidentId: remoteId,
      );
    }
  }

  Future<bool> _hasInternetLikeConnection() async {
    final result = await _connectivity.checkConnectivity();
    return result.any((item) => item != ConnectivityResult.none);
  }

  Future<_SyncAttemptResult> _syncContactCreate({
    required String userId,
    required String accessToken,
    required _PendingSyncOperation operation,
  }) async {
    final contact = ContactModel.fromJson(
      Map<String, dynamic>.from(operation.payload['contact'] as Map),
    );
    await _apiClient.postJson(
      '/contacts',
      accessToken: accessToken,
      body: contact.copyWith(id: '').toBackendPayload(),
    );

    final refreshedContacts = await _fetchContacts(userId, accessToken);
    final remoteContact = refreshedContacts.cast<ContactModel?>().firstWhere(
      (item) =>
          item != null &&
          AuthIdentityMapper.normalizePhone(item.phone) ==
              AuthIdentityMapper.normalizePhone(contact.phone),
      orElse: () => null,
    );
    if (remoteContact == null) {
      return const _SyncAttemptResult(_SyncDisposition.keep);
    }

    await _rememberRemoteId(
      userId: userId,
      localId: contact.id,
      remoteId: remoteContact.id,
    );
    return const _SyncAttemptResult(_SyncDisposition.done);
  }

  Future<_SyncAttemptResult> _syncContactUpdate({
    required String userId,
    required String accessToken,
    required _PendingSyncOperation operation,
  }) async {
    final contact = ContactModel.fromJson(
      Map<String, dynamic>.from(operation.payload['contact'] as Map),
    );
    final remoteId = await _resolveRemoteId(userId, contact.id);
    if (remoteId == null) {
      return const _SyncAttemptResult(_SyncDisposition.keep);
    }

    await _apiClient.putJson(
      '/contacts/$remoteId',
      accessToken: accessToken,
      body: contact.copyWith(id: remoteId).toBackendPayload(),
    );
    await _fetchContacts(userId, accessToken);
    return const _SyncAttemptResult(_SyncDisposition.done);
  }

  Future<_SyncAttemptResult> _syncContactDelete({
    required String userId,
    required String accessToken,
    required _PendingSyncOperation operation,
  }) async {
    final remoteId = await _resolveRemoteId(
      userId,
      _readString(operation.payload['contact_id']),
    );
    if (remoteId == null) {
      return const _SyncAttemptResult(_SyncDisposition.done);
    }

    await _apiClient.deleteJson(
      '/contacts/$remoteId',
      accessToken: accessToken,
    );
    await _fetchContacts(userId, accessToken);
    return const _SyncAttemptResult(_SyncDisposition.done);
  }

  Future<List<ContactModel>> _fetchContacts(
    String userId,
    String accessToken,
  ) async {
    final response = await _apiClient.getJson(
      '/contacts',
      accessToken: accessToken,
    );
    final data = response['data'];
    if (data is! List) {
      return <ContactModel>[];
    }

    final contacts =
        data
            .map(
              (item) => ContactModel.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList()
          ..sort((a, b) => a.priority.compareTo(b.priority));

    final mergedContacts = await _mergeLocalContactEmails(userId, contacts);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_contactsCachePrefix$userId',
      jsonEncode(mergedContacts.map((item) => item.toJson()).toList()),
    );
    return mergedContacts;
  }

  Future<List<ContactModel>> _mergeLocalContactEmails(
    String userId,
    List<ContactModel> contacts,
  ) async {
    final localEmails = await _loadLocalEmails(userId);
    if (localEmails.isEmpty) {
      return contacts;
    }

    return contacts.map((contact) {
      for (final key in _emailAliasesForContact(contact)) {
        final email = localEmails[key];
        if (email != null && email.trim().isNotEmpty) {
          return contact.copyWith(email: email);
        }
      }
      return contact;
    }).toList();
  }

  Future<Map<String, String>> _loadLocalEmails(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_contactEmailsPrefix$userId');
    if (raw == null || raw.trim().isEmpty) {
      return <String, String>{};
    }

    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return decoded.map(
        (key, value) => MapEntry(key, readContactString(value)),
      )..removeWhere((key, value) => value.trim().isEmpty);
    } catch (_) {
      return <String, String>{};
    }
  }

  List<String> _emailAliasesForContact(ContactModel contact) {
    final aliases = <String>[];
    if (contact.id.trim().isNotEmpty) {
      aliases.add('id:${contact.id.trim()}');
    }
    final normalizedPhone = AuthIdentityMapper.normalizePhone(contact.phone);
    if (normalizedPhone.isNotEmpty) {
      aliases.add('phone:$normalizedPhone');
    }
    return aliases;
  }

  Future<_SyncAttemptResult> _syncIncidentCreate({
    required String userId,
    required String accessToken,
    required _PendingSyncOperation operation,
  }) async {
    final incident = IncidentRecord.fromJson(
      Map<String, dynamic>.from(operation.payload['incident'] as Map),
    );
    final response = await _apiClient.postJson(
      '/incidents',
      accessToken: accessToken,
      body: {
        'titulo': incident.title,
        'descripcion': incident.description,
        'tipo_incidente': incident.type,
        'fecha_incidente': incident.occurredAt,
        'lugar': incident.location,
        'nivel_riesgo': incident.riskLevel,
        'estado': incident.status,
      },
    );

    final createdIncident =
        _extractIncidentDetail(response) ??
        incident.copyWith(id: _readString(response['id']));
    if (createdIncident.id.trim().isEmpty) {
      return const _SyncAttemptResult(_SyncDisposition.keep);
    }

    await _replaceCachedIncident(
      userId: userId,
      previousId: incident.id,
      incident: createdIncident,
    );
    await _rememberRemoteId(
      userId: userId,
      localId: incident.id,
      remoteId: createdIncident.id,
    );
    return const _SyncAttemptResult(_SyncDisposition.done);
  }

  Future<_SyncAttemptResult> _syncIncidentUpdate({
    required String userId,
    required String accessToken,
    required _PendingSyncOperation operation,
  }) async {
    final incident = IncidentRecord.fromJson(
      Map<String, dynamic>.from(operation.payload['incident'] as Map),
    );
    final remoteId = await _resolveRemoteId(userId, incident.id);
    if (remoteId == null) {
      return const _SyncAttemptResult(_SyncDisposition.keep);
    }

    await _apiClient.putJson(
      '/incidents/$remoteId',
      accessToken: accessToken,
      body: {'titulo': incident.title, 'descripcion': incident.description},
    );
    await _replaceCachedIncident(
      userId: userId,
      previousId: incident.id,
      incident: incident.copyWith(id: remoteId),
    );
    return const _SyncAttemptResult(_SyncDisposition.done);
  }

  Future<_SyncAttemptResult> _syncEvidenceCreate({
    required String userId,
    required String accessToken,
    required _PendingSyncOperation operation,
  }) async {
    final evidence = EvidenceRecord.fromJson(
      Map<String, dynamic>.from(operation.payload['evidence'] as Map),
    );
    final file = File(evidence.fileUrl);
    if (!await file.exists()) {
      return const _SyncAttemptResult(_SyncDisposition.keep);
    }

    final mimeType = evidence.mimeType.trim().isNotEmpty
        ? evidence.mimeType
        : (lookupMimeType(evidence.fileUrl) ??
              _fallbackMimeType(evidence.fileUrl));
    if (mimeType == null) {
      return const _SyncAttemptResult(_SyncDisposition.keep);
    }

    final fields = <String, String>{
      'is_private': evidence.isPrivate.toString(),
    };
    if (evidence.type.trim().isNotEmpty) {
      fields['tipo_evidencia'] = evidence.type;
    }
    if (evidence.title.trim().isNotEmpty) {
      fields['titulo'] = evidence.title;
    }
    if (evidence.description.trim().isNotEmpty) {
      fields['descripcion'] = evidence.description;
    }
    if (evidence.takenAt.trim().isNotEmpty) {
      fields['taken_at'] = evidence.takenAt;
    }

    final response = await _apiClient.postMultipart(
      '/evidences',
      accessToken: accessToken,
      fileField: 'file',
      filePath: evidence.fileUrl,
      contentType: MediaType.parse(mimeType),
      fields: fields,
    );

    var createdEvidence =
        _extractEvidenceDetail(response) ??
        evidence.copyWith(id: _readString(response['id']), mimeType: mimeType);
    if (createdEvidence.id.trim().isEmpty) {
      return const _SyncAttemptResult(_SyncDisposition.keep);
    }

    if (createdEvidence.isAssociated) {
      try {
        final detachResponse = await _apiClient.putJson(
          '/evidences/${createdEvidence.id}/incident',
          accessToken: accessToken,
          body: {'incident_id': null},
        );
        createdEvidence =
            _extractEvidenceDetail(detachResponse) ??
            createdEvidence.copyWith(clearIncidentId: true);
      } on ApiException catch (error) {
        if (_isTemporarySyncError(error)) {
          await _replaceCachedEvidence(
            userId: userId,
            previousId: evidence.id,
            evidence: createdEvidence.copyWith(clearIncidentId: true),
          );
          await _rememberRemoteId(
            userId: userId,
            localId: evidence.id,
            remoteId: createdEvidence.id,
          );
          await enqueueEvidenceAssociation(
            userId: userId,
            evidenceId: createdEvidence.id,
            incidentId: null,
          );
          return const _SyncAttemptResult(_SyncDisposition.done);
        }
      }
    }

    await _replaceCachedEvidence(
      userId: userId,
      previousId: evidence.id,
      evidence: createdEvidence,
    );
    await _rememberRemoteId(
      userId: userId,
      localId: evidence.id,
      remoteId: createdEvidence.id,
    );
    return const _SyncAttemptResult(_SyncDisposition.done);
  }

  Future<_SyncAttemptResult> _syncEvidenceAssociation({
    required String userId,
    required String accessToken,
    required _PendingSyncOperation operation,
  }) async {
    final rawEvidenceId = _readString(operation.payload['evidence_id']);
    final rawIncidentId = _readNullableString(operation.payload['incident_id']);

    final remoteEvidenceId = await _resolveRemoteId(userId, rawEvidenceId);
    if (remoteEvidenceId == null) {
      return const _SyncAttemptResult(_SyncDisposition.keep);
    }

    final remoteIncidentId = rawIncidentId == null
        ? null
        : await _resolveRemoteId(userId, rawIncidentId);
    if (rawIncidentId != null && remoteIncidentId == null) {
      return const _SyncAttemptResult(_SyncDisposition.keep);
    }

    final response = await _apiClient.putJson(
      '/evidences/$remoteEvidenceId/incident',
      accessToken: accessToken,
      body: {'incident_id': remoteIncidentId},
    );

    final updatedEvidence =
        _extractEvidenceDetail(response) ??
        (await _findCachedEvidence(userId, rawEvidenceId))?.copyWith(
          id: remoteEvidenceId,
          incidentId: remoteIncidentId,
          clearIncidentId: remoteIncidentId == null,
        );
    if (updatedEvidence != null) {
      await _replaceCachedEvidence(
        userId: userId,
        previousId: rawEvidenceId,
        evidence: updatedEvidence.copyWith(
          id: remoteEvidenceId,
          incidentId: remoteIncidentId,
          clearIncidentId: remoteIncidentId == null,
        ),
      );
    }

    return const _SyncAttemptResult(_SyncDisposition.done);
  }

  Future<void> _replaceCachedIncident({
    required String userId,
    required String previousId,
    required IncidentRecord incident,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final incidents = await _loadCachedIncidents(userId);
    incidents.removeWhere(
      (item) => item.id == previousId || item.id == incident.id,
    );
    incidents.insert(0, incident);
    await prefs.setString(
      '$_incidentCachePrefix$userId',
      jsonEncode(incidents.map((item) => item.toJson()).toList()),
    );
  }

  Future<List<IncidentRecord>> _loadCachedIncidents(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_incidentCachePrefix$userId');
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

  Future<void> _replaceCachedEvidence({
    required String userId,
    required String previousId,
    required EvidenceRecord evidence,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final evidences = await _loadCachedEvidences(userId);
    evidences.removeWhere(
      (item) => item.id == previousId || item.id == evidence.id,
    );
    evidences.insert(0, evidence);
    await prefs.setString(
      '$_evidenceCachePrefix$userId',
      jsonEncode(evidences.map((item) => item.toJson()).toList()),
    );
  }

  Future<EvidenceRecord?> _findCachedEvidence(
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

  Future<List<EvidenceRecord>> _loadCachedEvidences(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_evidenceCachePrefix$userId');
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

  Future<void> _replaceIncidentIdInCachedEvidences({
    required String userId,
    required String previousIncidentId,
    required String remoteIncidentId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final evidences = await _loadCachedEvidences(userId);
    final updated = evidences.map((item) {
      if (item.incidentId == previousIncidentId) {
        return item.copyWith(incidentId: remoteIncidentId);
      }
      return item;
    }).toList();
    await prefs.setString(
      '$_evidenceCachePrefix$userId',
      jsonEncode(updated.map((item) => item.toJson()).toList()),
    );
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

  EvidenceRecord? _extractEvidenceDetail(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return EvidenceRecord.fromBackendJson(data);
    }
    if (data is Map) {
      return EvidenceRecord.fromBackendJson(Map<String, dynamic>.from(data));
    }
    if (response['id'] != null) {
      return EvidenceRecord.fromBackendJson(response);
    }
    return null;
  }

  bool _isTemporarySyncError(ApiException error) {
    final normalized = '${error.message} ${error.details ?? ''}'.toLowerCase();
    return normalized.contains('no se pudo conectar con el servidor') ||
        normalized.contains('schema cache') ||
        normalized.contains('schema_cache') ||
        normalized.contains('pgrst204') ||
        normalized.contains('pgrst205') ||
        (error.statusCode != null && error.statusCode! >= 500);
  }

  bool _isLocalId(String value) {
    return value.trim().startsWith('local-');
  }

  String _buildSyncMessage({
    required int syncedCount,
    required int remainingCount,
  }) {
    if (remainingCount == 0) {
      return _t(
        es: 'Tus cambios guardados sin conexion ya se sincronizaron.',
        en: 'Your offline changes have been synced.',
        ay: 'Conexion jan utjkipan imata mayjt\'awinakamax jichhax sincronizatawa.',
        qu: 'Mana conexion kaptin waqaychasqa tikrayniykikunaqa kunanqa sincronizakusqañam.',
      );
    }

    return _t(
      es: 'Se sincronizaron $syncedCount cambios. Aun quedan $remainingCount pendientes.',
      en: '$syncedCount changes were synced. $remainingCount are still pending.',
      ay: '$syncedCount mayjt\'awinakaw sincronizata. $remainingCount ukax suyt\'askakiwa.',
      qu: '$syncedCount tikraykuna sincronizakusqanna. $remainingCount raqmi suyashan.',
    );
  }

  String _buildOperationId() {
    return 'offline-op-${DateTime.now().microsecondsSinceEpoch}';
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
}

class _PendingSyncOperation {
  final String id;
  final String userId;
  final String entity;
  final String action;
  final Map<String, dynamic> payload;
  final String createdAt;

  const _PendingSyncOperation({
    required this.id,
    required this.userId,
    required this.entity,
    required this.action,
    required this.payload,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'entity': entity,
    'action': action,
    'payload': payload,
    'createdAt': createdAt,
  };

  factory _PendingSyncOperation.fromJson(Map<String, dynamic> json) {
    return _PendingSyncOperation(
      id: _readString(json['id']),
      userId: _readString(json['userId']),
      entity: _readString(json['entity']),
      action: _readString(json['action']),
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? const {}),
      createdAt: _readString(json['createdAt']),
    );
  }
}

enum _SyncDisposition { done, keep, halt }

class _SyncAttemptResult {
  final _SyncDisposition disposition;

  const _SyncAttemptResult(this.disposition);
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

String? _readNullableString(dynamic value) {
  final normalized = _readString(value);
  return normalized.trim().isEmpty ? null : normalized;
}
