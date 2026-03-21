import 'package:flutter/material.dart';

import '../../../../core/localization/app_language_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../incidents/domain/models/incident_record.dart';
import '../../../incidents/presentation/services/incident_service.dart';
import '../../domain/models/evidence_record.dart';
import '../services/evidence_service.dart';
import '../widgets/evidence_components.dart';
import '../widgets/evidence_preview_panel.dart';

class EvidenceDetailScreen extends StatefulWidget {
  final EvidenceRecord initialEvidence;

  const EvidenceDetailScreen({super.key, required this.initialEvidence});

  @override
  State<EvidenceDetailScreen> createState() => _EvidenceDetailScreenState();
}

class _EvidenceDetailScreenState extends State<EvidenceDetailScreen> {
  static const String _noIncidentValue = '__no_incident__';

  final EvidenceService _evidenceService = EvidenceService();
  final IncidentService _incidentService = IncidentService();

  late EvidenceRecord _evidence;
  List<IncidentRecord> _incidents = [];
  bool _isLoadingDetail = true;
  bool _isLoadingIncidents = true;
  bool _isUpdatingAssociation = false;
  String? _statusMessage;
  String? _associationMessage;
  String _selectedIncidentValue = _noIncidentValue;
  bool _showIndependentAlert = true;

  String _t({
    required String es,
    required String en,
    required String ay,
    required String qu,
  }) {
    return AppLanguageService.instance.pick(es: es, en: en, ay: ay, qu: qu);
  }

  String? get _selectedIncidentId => _selectedIncidentValue == _noIncidentValue
      ? null
      : _selectedIncidentValue;

  bool get _hasAssociationChanges =>
      _selectedIncidentId != _evidence.incidentId;

  bool _isPendingSyncId(String? value) {
    final normalized = (value ?? '').trim();
    return normalized.isNotEmpty && normalized.startsWith('local-');
  }

  String? get _associationBlockedMessage {
    if (_selectedIncidentId == null) {
      return null;
    }

    if (_evidence.id.trim().isEmpty || _isPendingSyncId(_evidence.id)) {
      return _t(
        es: 'Esta evidencia todavia no esta sincronizada con el servidor. Cuando termine de registrarse podras asociarla a un incidente.',
        en: 'This evidence is not yet synced with the server. Once it finishes registering, you will be able to link it to an incident.',
        ay: 'Aka evidenciax janirakiw servidorampi sincronizatakiti. Qillqantasiñ tukuyatatxa incidenteru mayachasmawa.',
        qu: 'Kay evidenciaqa manaraqmi servidorwan sincronizakunchu. Qillqakuyta tukuruptinmi incidenteman tinkichiyta atinki.',
      );
    }

    if (_isPendingSyncId(_selectedIncidentId)) {
      return _t(
        es: 'El incidente seleccionado todavia no esta sincronizado con el servidor, asi que no puede recibir evidencias aun.',
        en: 'The selected incident is not yet synced with the server, so it cannot receive evidence yet.',
        ay: 'Ajllita incidentex janirakiw servidorampi sincronizatakiti, ukhamax janiw evidencianak katuqkaspati.',
        qu: 'Akllasqa incidenteqa manaraqmi servidorwan sincronizakunchu, chayrayku manaraqmi evidenciakunata chaskiyta atinchu.',
      );
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    _evidence = widget.initialEvidence;
    _syncSelectedIncident();
    _loadDetail();
    _loadIncidents();
  }

  void _syncSelectedIncident() {
    final incidentId = _evidence.incidentId;
    _selectedIncidentValue = incidentId == null || incidentId.trim().isEmpty
        ? _noIncidentValue
        : incidentId;
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoadingDetail = true);

    final result = await _evidenceService.getEvidenceDetail(
      _evidence.id,
      fallback: _evidence,
    );
    if (!mounted) return;

    setState(() {
      if (result.evidence != null) {
        _evidence = result.evidence!;
        _syncSelectedIncident();
      }
      _statusMessage = result.message;
      _isLoadingDetail = false;
    });
  }

  Future<void> _loadIncidents() async {
    final result = await _incidentService.loadIncidents();
    if (!mounted) return;

    setState(() {
      _incidents = result.incidents;
      _associationMessage = result.message;
      _isLoadingIncidents = false;
    });
  }

  Future<void> _saveAssociation() async {
    if (!_hasAssociationChanges) {
      return;
    }

    final blockedMessage = _associationBlockedMessage;
    if (blockedMessage != null) {
      setState(() => _statusMessage = blockedMessage);
      _showSnackBar(blockedMessage);
      return;
    }

    setState(() => _isUpdatingAssociation = true);

    final result = await _evidenceService.updateEvidenceIncident(
      evidence: _evidence,
      incidentId: _selectedIncidentId,
    );
    if (!mounted) return;

    setState(() {
      if (result.evidence != null) {
        _evidence = result.evidence!;
      } else {
        _evidence = _evidence.copyWith(
          incidentId: _selectedIncidentId,
          clearIncidentId: _selectedIncidentId == null,
        );
      }
      _syncSelectedIncident();
      _statusMessage = result.message;
      _isUpdatingAssociation = false;
    });

    _showSnackBar(result.message);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _incidentLabel(String? incidentId) {
    if (incidentId == null || incidentId.trim().isEmpty) {
      return _t(
        es: 'Sin incidente',
        en: 'No incident',
        ay: 'Jan incidenteni',
        qu: 'Mana incidenteyuq',
      );
    }

    for (final incident in _incidents) {
      if (incident.id == incidentId) {
        return incident.title;
      }
    }

    final shortId = incidentId.length <= 8
        ? incidentId
        : incidentId.substring(0, 8);
    return _t(
      es: 'Incidente actual ($shortId)',
      en: 'Current incident ($shortId)',
      ay: 'Jichha incidente ($shortId)',
      qu: 'Kunan incidente ($shortId)',
    );
  }

  List<DropdownMenuItem<String>> _buildAssociationItems() {
    final items = <DropdownMenuItem<String>>[
      DropdownMenuItem(
        value: _noIncidentValue,
        child: Text(
          _t(
            es: 'Sin incidente',
            en: 'No incident',
            ay: 'Jan incidenteni',
            qu: 'Mana incidenteyuq',
          ),
        ),
      ),
    ];

    final currentIncidentId = _evidence.incidentId;
    final containsCurrent =
        currentIncidentId != null &&
        currentIncidentId.trim().isNotEmpty &&
        _incidents.any((incident) => incident.id == currentIncidentId);

    if (currentIncidentId != null &&
        currentIncidentId.trim().isNotEmpty &&
        !containsCurrent) {
      items.add(
        DropdownMenuItem(
          value: currentIncidentId,
          child: Text(_incidentLabel(currentIncidentId)),
        ),
      );
    }

    items.addAll(
      _incidents.map(
        (incident) => DropdownMenuItem(
          value: incident.id,
          child: Text(
            _isPendingSyncId(incident.id)
                ? '${incident.title} (${_t(es: 'pendiente de sincronizacion', en: 'pending sync', ay: 'sincronizacion suyt\'ata', qu: 'sincronizacion suyasqa')})'
                : incident.title,
          ),
        ),
      ),
    );

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final typeStyle = evidenceTypeStyleFor(_evidence.type);
    final associationItems = _buildAssociationItems();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(
          _t(
            es: 'Detalle de evidencia',
            en: 'Evidence detail',
            ay: 'Evidencia detalle',
            qu: 'Evidencia detalle',
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            if (_isLoadingDetail)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: LinearProgressIndicator(color: AppTheme.primary),
              ),
            if (_statusMessage != null) ...[
              StatusBanner(message: _statusMessage!),
              const SizedBox(height: 16),
            ],
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
                          color: typeStyle.color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(typeStyle.icon, color: typeStyle.color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _evidence.title,
                              style: AppTheme.headlineMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              formatEvidenceDate(_evidence.displayDate),
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
                      _DetailChip(
                        label: typeStyle.label,
                        color: typeStyle.color,
                      ),
                      _DetailChip(
                        label: _evidence.isPrivate
                            ? _t(
                                es: 'Privada',
                                en: 'Private',
                                ay: 'Privada',
                                qu: 'Privada',
                              )
                            : _t(
                                es: 'No privada',
                                en: 'Not private',
                                ay: 'Jan privada',
                                qu: 'Mana privada',
                              ),
                        color: _evidence.isPrivate
                            ? AppTheme.warning
                            : AppTheme.success,
                      ),
                      EvidenceAssociationBadge(
                        isAssociated: _evidence.isAssociated,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!_evidence.isAssociated && _showIndependentAlert) ...[
              const SizedBox(height: 16),
              DismissibleStatusBanner(
                message: _t(
                  es: 'La evidencia se guardo como archivo independiente. Si quieres relacionarla con un caso, hazlo desde el selector y guarda el cambio.',
                  en: 'The evidence was saved as an independent file. If you want to relate it to a case, use the selector and save the change.',
                  ay: 'Evidenciax sapak archivjamaw imasi. Casomp mayachañ munasma ukhax selector apnaqam ukat mayjt\'awi imam.',
                  qu: 'Evidenciaqa sapallan archivo hinam waqaychasqa karqan. Kasoawan tinkichiyta munaspaykiqa, selector nisqata apaykachay hinaspa tikrayta waqaychay.',
                ),
                onDismiss: () {
                  setState(() => _showIndependentAlert = false);
                },
              ),
            ],
            const SizedBox(height: 20),
            Text(
              _t(
                es: 'Asociacion con incidente',
                en: 'Incident association',
                ay: 'Incidente mayachawi',
                qu: 'Incidente asociacion',
              ),
              style: AppTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t(
                      es: 'Selecciona un incidente existente solo si deseas vincular esta evidencia. El cambio se aplica unicamente cuando pulses guardar.',
                      en: 'Select an existing incident only if you want to link this evidence. The change is applied only when you press save.',
                      ay: 'Maya utjir incidente ajllim aka evidencia mayachañ munasakixa. Mayjt\'awix imañ limt\'asaw phuqhasi.',
                      qu: 'Kay evidenciata tinkichiyta munaspallayki chayqa huk incidente kachkaqta akllay. Tikrayqa waqaychayta ñit\'ispa chayllaraq ruwakun.',
                    ),
                    style: AppTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  if (_associationMessage != null) ...[
                    StatusBanner(
                      message: _associationMessage!,
                      isWarning: _incidents.isEmpty,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_isLoadingIncidents)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(color: AppTheme.primary),
                    )
                  else ...[
                    DropdownButtonFormField<String>(
                      key: ValueKey(
                        '${_selectedIncidentValue}_${_incidents.length}_${_evidence.incidentId ?? 'none'}',
                      ),
                      initialValue: _selectedIncidentValue,
                      items: associationItems,
                      onChanged: _isUpdatingAssociation
                          ? null
                          : (value) {
                              setState(() {
                                _selectedIncidentValue =
                                    value ?? _noIncidentValue;
                              });
                            },
                      decoration: InputDecoration(
                        labelText: _t(
                          es: 'Incidente vinculado',
                          en: 'Linked incident',
                          ay: 'Mayachata incidente',
                          qu: 'Tinkisqa incidente',
                        ),
                        prefixIcon: const Icon(Icons.link_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_associationBlockedMessage != null) ...[
                      StatusBanner(
                        message: _associationBlockedMessage!,
                        isWarning: true,
                      ),
                      const SizedBox(height: 12),
                    ],
                    StatusBanner(
                      message: _selectedIncidentId == null
                          ? _t(
                              es: 'La evidencia quedara sin incidente asociado hasta que decidas vincularla.',
                              en: 'The evidence will remain without an associated incident until you decide to link it.',
                              ay: 'Evidenciax janiw incidenter mayachatakiti qhipat amtañkama.',
                              qu: 'Evidenciaqa mana incidentewan tinkisqachu kipakunqa qhipaman akllanaykikama.',
                            )
                          : _t(
                              es: 'Se vinculara con: ${_incidentLabel(_selectedIncidentId)}',
                              en: 'It will be linked with: ${_incidentLabel(_selectedIncidentId)}',
                              ay: 'Akamp mayachasiniwa: ${_incidentLabel(_selectedIncidentId)}',
                              qu: 'Kaywan tinkisqa kanqa: ${_incidentLabel(_selectedIncidentId)}',
                            ),
                      isWarning: _selectedIncidentId == null,
                    ),
                    const SizedBox(height: 16),
                    CustomButton(
                      text: _selectedIncidentId == null
                          ? _t(
                              es: 'Guardar sin incidente',
                              en: 'Save without incident',
                              ay: 'Jan incidenteni imam',
                              qu: 'Mana incidentewan waqaychay',
                            )
                          : _t(
                              es: 'Guardar asociacion',
                              en: 'Save association',
                              ay: 'Asociacion imam',
                              qu: 'Asociacion waqaychay',
                            ),
                      icon: _selectedIncidentId == null
                          ? Icons.link_off_rounded
                          : Icons.save_outlined,
                      isLoading: _isUpdatingAssociation,
                      onPressed:
                          (!_hasAssociationChanges ||
                              _isLoadingIncidents ||
                              _associationBlockedMessage != null)
                          ? null
                          : _saveAssociation,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _t(
                es: 'Vista previa',
                en: 'Preview',
                ay: 'Nayra uñjaña',
                qu: 'Ñawpaq rikuy',
              ),
              style: AppTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            EvidencePreviewPanel(evidence: _evidence),
            const SizedBox(height: 20),
            Text(
              _t(
                es: 'Contexto completo',
                en: 'Full context',
                ay: 'Phuqhata contexto',
                qu: 'Hunt\'asqa contexto',
              ),
              style: AppTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Text(
                _evidence.description.trim().isEmpty
                    ? _t(
                        es: 'No se registro una descripcion para esta evidencia.',
                        en: 'No description was registered for this evidence.',
                        ay: 'Aka evidenciatakix janiw descripcion qillqt\'atakti.',
                        qu: 'Kay evidenciapaq descripcionqa mana qillqasqachu.',
                      )
                    : _evidence.description,
                style: AppTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _t(
                es: 'Metadatos',
                en: 'Metadata',
                ay: 'Metadatos',
                qu: 'Metadatos',
              ),
              style: AppTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                children: [
                  _MetadataRow(
                    label: 'incident_id',
                    value: _evidence.incidentId ?? 'null',
                  ),
                  const Divider(color: AppTheme.divider),
                  _MetadataRow(
                    label: _t(
                      es: 'Incidente visible',
                      en: 'Visible incident',
                      ay: 'Uñt\'ata incidente',
                      qu: 'Rikusqa incidente',
                    ),
                    value: _incidentLabel(_evidence.incidentId),
                  ),
                  const Divider(color: AppTheme.divider),
                  _MetadataRow(
                    label: _t(
                      es: 'Privacidad',
                      en: 'Privacy',
                      ay: 'Privacidad',
                      qu: 'Privacidad',
                    ),
                    value: _evidence.isPrivate
                        ? _t(
                            es: 'Privada para el usuario',
                            en: 'Private for the user',
                            ay: 'Usuario ukatak privada',
                            qu: 'Usuariopaq privada',
                          )
                        : _t(
                            es: 'Sin restriccion especial',
                            en: 'No special restriction',
                            ay: 'Janiw especial restriccion utjkiti',
                            qu: 'Mana especial restriccion kanchu',
                          ),
                  ),
                  const Divider(color: AppTheme.divider),
                  _MetadataRow(
                    label: _t(
                      es: 'Archivo',
                      en: 'File',
                      ay: 'Archivo',
                      qu: 'Archivo',
                    ),
                    value: _evidence.fileName.trim().isEmpty
                        ? _t(
                            es: 'Sin nombre disponible',
                            en: 'No available name',
                            ay: 'Janiw sutix utjkiti',
                            qu: 'Mana sutin kanchu',
                          )
                        : _evidence.fileName,
                  ),
                  const Divider(color: AppTheme.divider),
                  _MetadataRow(
                    label: 'Mime type',
                    value: _evidence.mimeType.trim().isEmpty
                        ? _t(
                            es: 'No disponible',
                            en: 'Unavailable',
                            ay: 'Janiw utjkiti',
                            qu: 'Mana kanchu',
                          )
                        : _evidence.mimeType,
                  ),
                  const Divider(color: AppTheme.divider),
                  _MetadataRow(
                    label: _t(
                      es: 'Tamano',
                      en: 'Size',
                      ay: 'Tamano',
                      qu: 'Tamano',
                    ),
                    value: formatEvidenceSize(_evidence.sizeBytes),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final String label;
  final Color color;

  const _DetailChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetadataRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: Text(label, style: AppTheme.bodyMedium)),
        const SizedBox(width: 12),
        Expanded(
          flex: 5,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppTheme.labelLarge.copyWith(fontSize: 13),
          ),
        ),
      ],
    );
  }
}
