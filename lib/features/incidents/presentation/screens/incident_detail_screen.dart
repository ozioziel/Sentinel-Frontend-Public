import 'package:flutter/material.dart';

import '../../../../core/localization/app_language_service.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/translated_text.dart';
import '../../../auth/presentation/services/auth_service.dart';
import '../../../evidence/domain/models/evidence_record.dart';
import '../../../evidence/presentation/screens/evidence_detail_screen.dart';
import '../../../evidence/presentation/services/evidence_service.dart';
import '../../../evidence/presentation/widgets/evidence_components.dart';
import '../../domain/models/incident_record.dart';
import '../services/incident_service.dart';
import '../services/legal_info_service.dart';

class IncidentDetailScreen extends StatefulWidget {
  final IncidentRecord initialIncident;

  const IncidentDetailScreen({super.key, required this.initialIncident});

  @override
  State<IncidentDetailScreen> createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends State<IncidentDetailScreen> {
  final IncidentService _incidentService = IncidentService();
  final EvidenceService _evidenceService = EvidenceService();
  final LegalInfoService _legalInfoService = LegalInfoService();
  final AuthService _authService = AuthService();
  final ApiClient _apiClient = ApiClient();

  late IncidentRecord _incident;
  List<EvidenceRecord> _allEvidences = [];
  List<EvidenceRecord> _incidentEvidences = [];
  bool _isLoadingEvidences = true;
  bool _isRefreshing = false;
  bool _isSavingIncident = false;
  bool _isUpdatingAssociation = false;
  bool _isSendingToInstitution = false;
  bool _isDeletingIncident = false;
  String? _statusMessage;

  List<LegalLaw> _legalLaws = [];
  bool _isLoadingLegal = false;
  bool _legalLoaded = false;
  String? _legalError;

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

  @override
  void initState() {
    super.initState();
    _incident = widget.initialIncident;
    _loadIncidentData();
  }

  Future<void> _loadIncidentData({bool refreshing = false}) async {
    if (refreshing) {
      setState(() => _isRefreshing = true);
    } else {
      setState(() => _isLoadingEvidences = true);
    }

    final result = await _evidenceService.loadEvidences();
    if (!mounted) return;

    final allEvidences = result.evidences;
    setState(() {
      _allEvidences = allEvidences;
      _incidentEvidences = allEvidences
          .where((evidence) => evidence.incidentId == _incident.id)
          .toList();
      _statusMessage = result.message;
      _isLoadingEvidences = false;
      _isRefreshing = false;
    });
  }

  Future<void> _editIncidentContext() async {
    final draft = await showModalBottomSheet<_IncidentDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _IncidentEditSheet(
        initialTitle: _incident.title,
        initialDescription: _incident.description,
      ),
    );

    if (!mounted || draft == null) return;

    setState(() => _isSavingIncident = true);

    final result = await _incidentService.updateIncidentDetails(
      incident: _incident,
      title: draft.title,
      description: draft.description,
    );
    if (!mounted) return;

    setState(() {
      if (result.incident != null) {
        _incident = result.incident!;
      }
      _statusMessage = result.message;
      _isSavingIncident = false;
    });

    _showSnackBar(result.message);
  }

  Future<void> _openEvidence(EvidenceRecord evidence) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => EvidenceDetailScreen(initialEvidence: evidence),
      ),
    );
    if (!mounted) return;
    await _loadIncidentData(refreshing: true);
  }

  Future<void> _attachExistingEvidence() async {
    final selectedEvidence = await showModalBottomSheet<EvidenceRecord>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EvidencePickerSheet(
        currentIncidentId: _incident.id,
        evidences: _allEvidences,
      ),
    );

    if (!mounted || selectedEvidence == null) {
      return;
    }

    await _updateEvidenceAssociation(
      evidence: selectedEvidence,
      incidentId: _incident.id,
    );
  }

  Future<void> _removeEvidence(EvidenceRecord evidence) async {
    await _updateEvidenceAssociation(evidence: evidence, incidentId: null);
  }

  Future<void> _deleteIncident() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Text(
          _t(
            es: 'Eliminar incidente',
            en: 'Delete incident',
            ay: 'Incidente juchukaña',
            qu: 'Incidente juchukaychiy',
          ),
        ),
        content: Text(
          _t(
            es: 'Se desvincularan todas las evidencias y el incidente se eliminara permanentemente. Esta accion no se puede deshacer.',
            en: 'All evidence will be unlinked and the incident will be permanently deleted. This action cannot be undone.',
            ay: 'Evidencia tukuy wakichañapax juchukañatanix incidentex kimsa juchukataski. Aka lurawinax janiw aruskipasiñjamakiti.',
            qu: 'Evidencia tukuy tinkikunaqa juchukasqa kanqa hinaspa incidenteqa wiñaypaq juchukaykusqa kanqa. Kay ruwaytaqa mana kutichiyta atikuchu.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              _t(es: 'Cancelar', en: 'Cancel', ay: 'Amuyt\'aña', qu: 'Saqiy'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              _t(es: 'Eliminar', en: 'Delete', ay: 'Juchukaña', qu: 'Juchukaychiy'),
              style: const TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeletingIncident = true);

    // 1. Unlink all associated evidences first.
    for (final evidence in List<EvidenceRecord>.from(_incidentEvidences)) {
      await _evidenceService.updateEvidenceIncident(
        evidence: evidence,
        incidentId: null,
      );
    }

    if (!mounted) return;

    // 2. Delete the incident.
    final result = await _incidentService.deleteIncident(incident: _incident);

    if (!mounted) return;
    setState(() => _isDeletingIncident = false);

    if (result.success) {
      Navigator.of(context).pop(true);
    } else {
      _showSnackBar(result.message);
    }
  }

  Future<void> _updateEvidenceAssociation({
    required EvidenceRecord evidence,
    required String? incidentId,
  }) async {
    setState(() => _isUpdatingAssociation = true);

    final result = await _evidenceService.updateEvidenceIncident(
      evidence: evidence,
      incidentId: incidentId,
    );
    if (!mounted) return;

    setState(() {
      _statusMessage = result.message;
      _isUpdatingAssociation = false;
    });

    if (result.success) {
      final updatedEvidence =
          result.evidence ??
          evidence.copyWith(
            incidentId: incidentId,
            clearIncidentId: incidentId == null,
          );
      setState(() {
        _allEvidences = [
          for (final e in _allEvidences)
            if (e.id == updatedEvidence.id) updatedEvidence else e,
        ];
        _incidentEvidences =
            _allEvidences
                .where((e) => e.incidentId == _incident.id)
                .toList();
      });
      await _loadIncidentData(refreshing: true);
    }

    _showSnackBar(result.message);
  }

  Future<void> _sendToInstitution(_SupportInstitution institution) async {
    if (_incidentEvidences.isEmpty) {
      _showSnackBar(
        _t(
          es:
              'Debes asociar al menos una evidencia antes de enviar este incidente.',
          en:
              'You must attach at least one piece of evidence before sending this incident.',
          ay:
              'Paya sinti evidencia mayachasiskama aka incidente apayañatak.',
          qu:
              'Huk evidenciata tinkichinapuniyki kay incidenteta apachinaykipaq.',
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(institution.name),
        content: Text(
          _t(
            es:
                'Se enviaran ${_incidentEvidences.length} evidencia(s) a ${institution.name}. '
                '¿Deseas continuar?',
            en:
                '${_incidentEvidences.length} evidence file(s) will be sent to ${institution.name}. '
                'Do you want to continue?',
            ay:
                '${_incidentEvidences.length} evidencia(s) ${institution.name} ukar apayataniwa. '
                '¿Sarantayañ munista?',
            qu:
                '${_incidentEvidences.length} evidencia(s) ${institution.name}man apachisqa kanqa. '
                '¿Kaytachu munankis?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              _t(es: 'Cancelar', en: 'Cancel', ay: 'Janiwa', qu: 'Mana'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              _t(es: 'Enviar', en: 'Send', ay: 'Apaya', qu: 'Apachiy'),
            ),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    setState(() => _isSendingToInstitution = true);

    final user = await _authService.getSession();
    if (!mounted) return;

    if (user == null) {
      setState(() => _isSendingToInstitution = false);
      _showSnackBar(
        _t(
          es: 'No hay una sesion activa.',
          en: 'There is no active session.',
          ay: 'Janiw sesion activa utjkiti.',
          qu: 'Sesion activaqa mana kanchu.',
        ),
      );
      return;
    }

    final evidenceIds =
        _incidentEvidences
            .where((e) => e.id.trim().isNotEmpty)
            .map((e) => e.id)
            .toList();

    final hasVideo = _incidentEvidences.any((e) => e.type == 'video');
    final hasAudio = _incidentEvidences.any((e) => e.type == 'audio');

    try {
      final locationUrl = _incident.location.trim();
      final bodyFields = <String, dynamic>{
        'alert_message':
            '${_t(
              es: 'Incidente reportado a ${institution.name}',
              en: 'Incident reported to ${institution.name}',
              ay: '${institution.name} ukax incidente willjtawa',
              qu: '${institution.name}man incidente willaykusqa',
            )}.\n\n${_incident.description}',
        'alert_triggered_at': _incident.occurredAt,
        'has_video': hasVideo,
        'has_audio': hasAudio,
      };
      if (locationUrl.startsWith('http://') ||
          locationUrl.startsWith('https://')) {
        bodyFields['location_url'] = locationUrl;
      }

      await _apiClient.postJson(
        '/emergency/send-email',
        accessToken: user.accessToken,
        body: {
          'recipients': [institution.email],
          'subject':
              '${_t(
                es: 'Denuncia de incidente',
                en: 'Incident report',
                ay: 'Incidente denuncia',
                qu: 'Incidente denuncia',
              )}: ${_incident.title} — ${institution.name}',
          'body': bodyFields,
          'evidence_ids': evidenceIds,
        },
      );

      if (mounted) {
        _showSnackBar(
          _t(
            es:
                'Incidente enviado correctamente a ${institution.name}.',
            en: 'Incident successfully sent to ${institution.name}.',
            ay: '${institution.name} ukar incidente apayatäwa.',
            qu: '${institution.name}man incidenteqa allinmanta apachisqa.',
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar(
          _t(
            es: 'No se pudo enviar a ${institution.name}. Intenta de nuevo.',
            en:
                'Could not send to ${institution.name}. Please try again.',
            ay:
                'Janiw ${institution.name} ukar apayañjamakiti. Wakiskt\'ata lura.',
            qu:
                '${institution.name}man mana apachikurqanchu. Kutipayta tink\'iy.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingToInstitution = false);
    }
  }

  Future<void> _loadLegalInfo() async {
    final evidencia = [
      _incident.title,
      _incident.description,
      ..._incidentEvidences.map((e) => e.description).where((d) => d.trim().isNotEmpty),
    ].join('. ');

    setState(() {
      _isLoadingLegal = true;
      _legalError = null;
    });

    final result = await _legalInfoService.fetchApplicableLaws(
      evidencia: evidencia,
    );
    if (!mounted) return;

    setState(() {
      _isLoadingLegal = false;
      _legalLoaded = true;
      if (result.success) {
        _legalLaws = result.leyes;
        _legalError = null;
      } else {
        _legalLaws = [];
        _legalError = result.errorMessage;
      }
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final riskColor = _riskColorFor(_incident.riskLevel);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(
          _t(
            es: 'Detalle de incidente',
            en: 'Incident detail',
            ay: 'Incidente detalle',
            qu: 'Incidente detalle',
          ),
        ),
        actions: [
          IconButton(
            icon: _isDeletingIncident
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.error,
                    ),
                  )
                : const Icon(Icons.delete_outline_rounded),
            color: AppTheme.error,
            tooltip: _t(
              es: 'Eliminar incidente',
              en: 'Delete incident',
              ay: 'Incidente juchukaña',
              qu: 'Incidente juchukaychiy',
            ),
            onPressed: _isDeletingIncident ? null : _deleteIncident,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadIncidentData(refreshing: true),
          color: AppTheme.primary,
          backgroundColor: AppTheme.cardBg,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              if (_statusMessage != null) ...[
                StatusBanner(message: _statusMessage!),
                const SizedBox(height: 16),
              ],
              if (_isRefreshing)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: LinearProgressIndicator(color: AppTheme.primary),
                ),
              Text(
                _t(
                  es: '1. Incidente principal',
                  en: '1. Main incident',
                  ay: '1. Nayriri incidente',
                  qu: '1. Hatun incidente',
                ),
                style: AppTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: riskColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.description_rounded,
                            color: riskColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TranslatedText(
                                _incident.title,
                                style: AppTheme.headlineMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                formatEvidenceDate(_incident.occurredAt),
                                style: AppTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _IncidentChip(
                          label: _incident.status,
                          color: AppTheme.primaryLight,
                        ),
                        _IncidentChip(
                          label: _incident.riskLevel,
                          color: riskColor,
                        ),
                        _IncidentChip(
                          label: _incident.type,
                          color: AppTheme.textSecondary,
                        ),
                      ],
                    ),
                    if (_incident.location.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: AppTheme.textSecondary,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TranslatedText(
                              _incident.location,
                              style: AppTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    if (_incident.description.trim().isEmpty)
                      Text(
                        _t(
                          es: 'Todavia no hay contexto adicional registrado para este incidente.',
                          en: 'There is still no additional context recorded for this incident.',
                          ay: 'Aka incidentetakejj janiw yaqha contexto qillqt\'atakiti.',
                          qu: 'Kay incidentepaqqa manaraq yapasqa contexto qillqasqachu.',
                        ),
                        style: AppTheme.bodyLarge,
                      )
                    else
                      TranslatedText(
                        _incident.description,
                        style: AppTheme.bodyLarge,
                      ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: _t(
                              es: 'Editar contexto',
                              en: 'Edit context',
                              ay: 'Contexto askicha',
                              qu: 'Contextota allichay',
                            ),
                            icon: Icons.edit_outlined,
                            variant: ButtonVariant.secondary,
                            isLoading: _isSavingIncident,
                            onPressed: _editIncidentContext,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _t(
                        es: 'Enviar a institución de apoyo',
                        en: 'Send to support institution',
                        ay: 'Yanapt\'iri institucionar apaya',
                        qu: 'Yanapayniyuq institucionman apachiy',
                      ),
                      style: AppTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _t(
                        es:
                            'Se enviaran todas las evidencias asociadas a este incidente.',
                        en:
                            'All evidence linked to this incident will be sent.',
                        ay:
                            'Aka incidenten mayachata evidencianak apayataniwa.',
                        qu:
                            'Kay incidentewan tinkisqa evidenciakunaqa apachisqa kanqa.',
                      ),
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._kSupportInstitutions.map(
                      (inst) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _InstitutionButton(
                          institution: inst,
                          isLoading: _isSendingToInstitution,
                          onTap: () => _sendToInstitution(inst),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _t(
                  es: '2. Evidencias de este incidente',
                  en: '2. Evidence for this incident',
                  ay: '2. Aka incidenten evidencianakapa',
                  qu: '2. Kay incidentepa evidenciankuna',
                ),
                style: AppTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              StatusBanner(
                message: _t(
                  es:
                      'Este incidente es el caso principal. Aqui puedes reunir varias evidencias para mantener todo el contexto en un solo lugar.',
                  en:
                      'This incident is the main case. Here you can gather multiple pieces of evidence to keep the full context in one place.',
                  ay:
                      'Aka incidentex nayriri caso satawa. Akan walja evidencianak tantachtasma taqi contexto maya chiqana utjañapataki.',
                  qu:
                      'Kay incidenteqa hatun kasom kashan. Kaypim achka evidenciakunata huñunki lliw contextota hukllapi waqaychanaykipaq.',
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _t(
                              es: '${_incidentEvidences.length} vinculadas',
                              en: '${_incidentEvidences.length} linked',
                              ay: '${_incidentEvidences.length} mayachata',
                              qu: '${_incidentEvidences.length} tinkisqa',
                            ),
                            style: AppTheme.titleLarge,
                          ),
                        ),
                        CustomButton(
                          text: _t(
                            es: 'Agregar existentes',
                            en: 'Add existing',
                            ay: 'Utjir katxaru',
                            qu: 'Kachkaqkunata yapay',
                          ),
                          icon: Icons.add_link_rounded,
                          variant: ButtonVariant.secondary,
                          fullWidth: false,
                          height: 42,
                          onPressed:
                              _allEvidences.isEmpty || _isUpdatingAssociation
                              ? null
                              : _attachExistingEvidence,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _t(
                        es:
                            'Puedes traer evidencias desde tu bandeja o moverlas desde otro incidente. La idea es que este caso junte todo lo importante en un solo lugar.',
                        en:
                            'You can bring evidence from your inbox or move it from another incident. The goal is for this case to gather everything important in one place.',
                        ay:
                            'Bandejamat evidencianak apxatasmawa jan ukax yaqha incidentet apaqasmawa. Amtax aka cason taqi wakiskiri yatiyanak maya chiqana tantacht\'añawa.',
                        qu:
                            'Bandejaykimanta evidenciakunata apamuyta atinki utaq huk incidentemanta kuyuchiyta atinki. Kay kasoqa tukuy wakisqakunata hukllapi huñunanpaqmi.',
                      ),
                      style: AppTheme.bodyMedium.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    if (_isLoadingEvidences)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: CircularProgressIndicator(
                            color: AppTheme.primary,
                          ),
                        ),
                      )
                    else if (_incidentEvidences.isEmpty)
                      EmptyStateCard(
                        icon: Icons.link_off_rounded,
                        title: _t(
                          es: 'Sin evidencias asociadas',
                          en: 'No linked evidence',
                          ay: 'Janiw mayachata evidencianakax utjkiti',
                          qu: 'Mana tinkisqa evidenciakuna kanchu',
                        ),
                        subtitle: _t(
                          es:
                              'Todavia no agregaste archivos a este caso. Puedes traerlos desde tu bandeja de evidencias cuando los necesites.',
                          en:
                              'You have not added files to this case yet. You can bring them from your evidence inbox when needed.',
                          ay:
                              'Aka casarax janiw archivonak yapxatktati. Munasax bandejamat evidencianak apxatasmawa.',
                          qu:
                              'Kay kasomanqa manaraq archivokunata yapanchu. Munaspaykiqa bandejaykimanta evidenciakunata apamuyta atinki.',
                        ),
                      )
                    else
                      ..._incidentEvidences.map(
                        (evidence) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: EvidenceCard(
                            evidence: evidence,
                            compact: true,
                            showAssociation: false,
                            onTap: () => _openEvidence(evidence),
                            trailing: IconButton(
                              onPressed: _isUpdatingAssociation
                                  ? null
                                  : () => _removeEvidence(evidence),
                              icon: const Icon(Icons.link_off_rounded),
                              color: AppTheme.warning,
                              tooltip: _t(
                                es: 'Quitar del incidente',
                                en: 'Remove from incident',
                                ay: 'Incidente tuqit apsu',
                                qu: 'Incidentemanta qichuy',
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _t(
                  es: '3. Informacion legal',
                  en: '3. Legal information',
                  ay: '3. Legal informacion',
                  qu: '3. Legal informacion',
                ),
                style: AppTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.gavel_rounded,
                          color: AppTheme.primaryLight,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _t(
                            es: 'Marco legal aplicable',
                            en: 'Applicable legal framework',
                            ay: 'Aplicable legal marco',
                            qu: 'Aplicable legal marco',
                          ),
                          style: AppTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (!_legalLoaded && !_isLoadingLegal)
                      CustomButton(
                        text: _t(
                          es: 'Analizar marco legal',
                          en: 'Analyze legal framework',
                          ay: 'Legal marco analizam',
                          qu: 'Legal marcota analizay',
                        ),
                        icon: Icons.auto_awesome_rounded,
                        variant: ButtonVariant.outline,
                        onPressed: _loadLegalInfo,
                      ),
                    if (_isLoadingLegal)
                      Column(
                        children: [
                          const LinearProgressIndicator(
                            color: AppTheme.primary,
                            backgroundColor: AppTheme.divider,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _t(
                              es: 'Consultando base legal...',
                              en: 'Querying legal database...',
                              ay: 'Legal base jiskt\'ataski...',
                              qu: 'Legal baseta tapunaykishan...',
                            ),
                            style: AppTheme.bodyMedium,
                          ),
                        ],
                      ),
                    if (_legalLoaded && !_isLoadingLegal) ...[
                      if (_legalError != null) ...[
                        StatusBanner(message: _legalError!),
                        const SizedBox(height: 12),
                        CustomButton(
                          text: _t(
                            es: 'Reintentar',
                            en: 'Retry',
                            ay: 'Wasit yant\'am',
                            qu: 'Yapamanta yant\'ay',
                          ),
                          icon: Icons.refresh_rounded,
                          variant: ButtonVariant.outline,
                          onPressed: _loadLegalInfo,
                        ),
                      ] else if (_legalLaws.isEmpty)
                        Text(
                          _t(
                            es: 'No se encontraron leyes aplicables para este caso.',
                            en: 'No applicable laws were found for this case.',
                            ay: 'Aka kasotakix janiw aplicable leynakax jikxatakiti.',
                            qu: 'Kay kasopaqqa mana aplicable leykuna tarisqachu karqan.',
                          ),
                          style: AppTheme.bodyMedium,
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (int i = 0; i < _legalLaws.length; i++) ...[
                              if (i > 0) const SizedBox(height: 14),
                              _LegalLawCard(law: _legalLaws[i]),
                            ],
                            const SizedBox(height: 14),
                            CustomButton(
                              text: _t(
                                es: 'Actualizar analisis',
                                en: 'Refresh analysis',
                                ay: 'Analisis machaqtaya',
                                qu: 'Analisisni musuqyachiy',
                              ),
                              icon: Icons.refresh_rounded,
                              variant: ButtonVariant.ghost,
                              onPressed: _loadLegalInfo,
                            ),
                          ],
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalLawCard extends StatelessWidget {
  final LegalLaw law;

  const _LegalLawCard({required this.law});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            law.ley,
            style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w700),
          ),
          if (law.articulos.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: law.articulos
                  .map(
                    (art) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        art,
                        style: AppTheme.bodyMedium.copyWith(
                          fontSize: 12,
                          color: AppTheme.primaryLight,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (law.descripcionBreve.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(law.descripcionBreve, style: AppTheme.bodyMedium),
          ],
          if (law.porQueAplica.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    law.porQueAplica,
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EvidencePickerSheet extends StatelessWidget {
  final String currentIncidentId;
  final List<EvidenceRecord> evidences;

  const _EvidencePickerSheet({
    required this.currentIncidentId,
    required this.evidences,
  });

  @override
  Widget build(BuildContext context) {
    String t({
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

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t(
              es: 'Agregar evidencias existentes',
              en: 'Add existing evidence',
              ay: 'Utjir evidencianak yapxata',
              qu: 'Kachkaq evidenciakunata yapay',
            ),
            style: AppTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            t(
              es:
                  'Selecciona archivos de tu bandeja. Si ya pertenecen a otro incidente, se moveran a este caso.',
              en:
                  'Select files from your inbox. If they already belong to another incident, they will be moved to this case.',
              ay:
                  'Bandejamat archivonak ajllim. Yaqha incidentenkx utt\'askchi ukhax aka casar apaqataniwa.',
              qu:
                  'Bandejaykimanta archivokunata akllay. Huk incidentemanña kaptinqa, kay kasoman kuyuchisqa kanqa.',
            ),
            style: AppTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (evidences.isEmpty)
            EmptyStateCard(
              icon: Icons.perm_media_outlined,
              title: t(
                es: 'No hay evidencias disponibles',
                en: 'No evidence available',
                ay: 'Janiw evidencianakax utjkiti',
                qu: 'Mana evidenciakuna kanchu',
              ),
              subtitle: t(
                es:
                    'Primero crea evidencias en su modulo para poder asociarlas aqui.',
                en:
                    'First create evidence in its module so you can associate it here.',
                ay:
                    'Nayraqata moduloapan evidencianak luram ukhamat akank mayachañataki.',
                qu:
                    'Ñawpaqta modulonpi evidenciakunata ruway hinaspa kaypi tinkichinaykipaq.',
              ),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: evidences.map((evidence) {
                  final isCurrent = evidence.incidentId == currentIncidentId;
                  final actionLabel = isCurrent
                      ? t(
                          es: 'Ya asociada',
                          en: 'Already linked',
                          ay: 'Niy mayachata',
                          qu: 'Ñan tinkisqa',
                        )
                      : evidence.isAssociated
                      ? t(
                          es: 'Mover',
                          en: 'Move',
                          ay: 'Apaqam',
                          qu: 'Kuyuchiy',
                        )
                      : t(
                          es: 'Agregar',
                          en: 'Add',
                          ay: 'Yapxata',
                          qu: 'Yapay',
                        );

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: EvidenceCard(
                      evidence: evidence,
                      compact: true,
                      onTap: isCurrent
                          ? null
                          : () => Navigator.pop(context, evidence),
                      trailing: TextButton(
                        onPressed: isCurrent
                            ? null
                            : () => Navigator.pop(context, evidence),
                        child: Text(actionLabel),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _IncidentDraft {
  final String title;
  final String description;

  const _IncidentDraft({required this.title, required this.description});
}

class _IncidentEditSheet extends StatefulWidget {
  final String initialTitle;
  final String initialDescription;

  const _IncidentEditSheet({
    required this.initialTitle,
    required this.initialDescription,
  });

  @override
  State<_IncidentEditSheet> createState() => _IncidentEditSheetState();
}

class _IncidentEditSheetState extends State<_IncidentEditSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _descriptionController = TextEditingController(
      text: widget.initialDescription,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String t({
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

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t(
                es: 'Editar contexto',
                en: 'Edit context',
                ay: 'Contexto askicha',
                qu: 'Contextota allichay',
              ),
              style: AppTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              t(
                es: 'Ajusta el titulo y el contexto principal del incidente.',
                en: 'Adjust the title and main context of the incident.',
                ay: 'Incidente titulo ukat nayriri contextop askicham.',
                qu: 'Incidentepa sutinwan hatun contextonwan allichay.',
              ),
              style: AppTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _titleController,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: t(
                  es: 'Titulo del incidente',
                  en: 'Incident title',
                  ay: 'Incidente titulo',
                  qu: 'Incidente titulo',
                ),
                prefixIcon: Icon(Icons.title_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              minLines: 5,
              maxLines: 7,
              decoration: InputDecoration(
                labelText: t(
                  es: 'Contexto completo',
                  en: 'Full context',
                  ay: 'Phuqhata contexto',
                  qu: 'Hunt\'asqa contexto',
                ),
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 76),
                  child: Icon(Icons.notes_rounded),
                ),
              ),
            ),
            const SizedBox(height: 18),
            CustomButton(
              text: t(
                es: 'Guardar cambios',
                en: 'Save changes',
                ay: 'Mayjt\'awinak ima',
                qu: 'Tikraykunata waqaychay',
              ),
              icon: Icons.save_outlined,
              onPressed: () {
                Navigator.pop(
                  context,
                  _IncidentDraft(
                    title: _titleController.text,
                    description: _descriptionController.text,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportInstitution {
  final String name;
  final String description;
  final String email;
  final IconData icon;

  const _SupportInstitution({
    required this.name,
    required this.description,
    required this.email,
    required this.icon,
  });
}

const List<_SupportInstitution> _kSupportInstitutions = [
  _SupportInstitution(
    name: 'Alianza por la Solidaridad Bolivia',
    description:
        'Organización que apoya los derechos de las mujeres, la reducción de desigualdades y el acceso a apoyo social.',
    email: 'daniel.b.rueda.munoz@gmail.com',
    icon: Icons.diversity_3_outlined,
  ),
  _SupportInstitution(
    name: 'Ipas Bolivia',
    description:
        'Institución que trabaja en salud y derechos sexuales y reproductivos, además de apoyo ante violencia sexual.',
    email: 'daniel.b.rueda.munoz@gmail.com',
    icon: Icons.favorite_outline,
  ),
  _SupportInstitution(
    name: 'Pro Mujer Bolivia',
    description:
        'Institución que brinda apoyo integral a mujeres mediante orientación, bienestar, capacitación y acompañamiento.',
    email: 'daniel.b.rueda.munoz@gmail.com',
    icon: Icons.support_agent_outlined,
  ),
  _SupportInstitution(
    name: 'Fundación Munasim Kullakita',
    description:
        'Fundación enfocada en prevención de violencia, protección de personas en riesgo y atención integral a víctimas.',
    email: 'daniel.b.rueda.munoz@gmail.com',
    icon: Icons.shield_outlined,
  ),
];

class _InstitutionButton extends StatelessWidget {
  final _SupportInstitution institution;
  final bool isLoading;
  final VoidCallback onTap;

  const _InstitutionButton({
    required this.institution,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.divider),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                institution.icon,
                size: 22,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      institution.name,
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      institution.description,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.send_outlined,
                size: 18,
                color: isLoading ? AppTheme.textSecondary : AppTheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IncidentChip extends StatelessWidget {
  final String label;
  final Color color;

  const _IncidentChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: label.trim().isEmpty
          ? Text(
              AppLanguageService.instance.pick(
                es: 'sin dato',
                ay: 'janiw dato utjkiti',
                qu: 'mana dato kanchu',
              ),
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
            )
          : TranslatedText(
              label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
            ),
    );
  }
}

Color _riskColorFor(String riskLevel) {
  final normalized = riskLevel.toLowerCase();
  if (normalized.contains('crit')) {
    return AppTheme.error;
  }
  if (normalized.contains('alto')) {
    return AppTheme.warning;
  }
  return AppTheme.primaryLight;
}
