import 'package:flutter/material.dart';

import '../../../../core/localization/app_language_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/translated_text.dart';
import '../../../evidence/presentation/widgets/evidence_components.dart';
import '../../domain/models/incident_record.dart';
import '../services/incident_service.dart';
import 'create_incident_screen.dart';
import 'incident_detail_screen.dart';

class IncidentsScreen extends StatefulWidget {
  final bool isEmbedded;

  const IncidentsScreen({super.key, this.isEmbedded = false});

  @override
  State<IncidentsScreen> createState() => _IncidentsScreenState();
}

class _IncidentsScreenState extends State<IncidentsScreen> {
  final IncidentService _service = IncidentService();

  List<IncidentRecord> _incidents = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _statusMessage;
  bool _isShowingCache = false;

  String _t({
    required String es,
    required String en,
    required String ay,
    required String qu,
  }) {
    return AppLanguageService.instance.pick(es: es, en: en, ay: ay, qu: qu);
  }

  @override
  void initState() {
    super.initState();
    _loadIncidents();
  }

  Future<void> _loadIncidents({bool refreshing = false}) async {
    if (refreshing) {
      setState(() => _isRefreshing = true);
    } else {
      setState(() => _isLoading = true);
    }

    final result = await _service.loadIncidents();
    if (!mounted) return;

    setState(() {
      _incidents = result.incidents;
      _statusMessage = result.message;
      _isShowingCache = result.fromCache;
      _isLoading = false;
      _isRefreshing = false;
    });
  }

  Future<void> _openIncidentDetail(IncidentRecord incident) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => IncidentDetailScreen(initialIncident: incident),
      ),
    );
    if (!mounted) return;
    await _loadIncidents(refreshing: true);
  }

  Future<void> _openCreateIncident() async {
    final createdIncident = await Navigator.push<IncidentRecord>(
      context,
      MaterialPageRoute(builder: (_) => const CreateIncidentScreen()),
    );
    if (!mounted || createdIncident == null) return;

    setState(() {
      _incidents = [
        createdIncident,
        ..._incidents.where((item) => item.id != createdIncident.id),
      ];
      _statusMessage = _t(
        es: 'El incidente se creo por separado. Ahora puedes abrirlo y agregar evidencias cuando lo necesites.',
        en: 'The incident was created separately. You can now open it and add evidence when needed.',
        ay: 'Incidentex sapaki luratawa. Jichhax jist\'arasaw munasax evidencianak yapxatasma.',
        qu: 'Incidenteqa sapallan ruwasqa karqan. Kunanqa kicharispa munaspayki evidenciakunata yapayta atinki.',
      );
      _isShowingCache = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: widget.isEmbedded
          ? AppBar(
              title: Text(
                _t(
                  es: 'Incidentes',
                  en: 'Incidents',
                  ay: 'Incidentes',
                  qu: 'Incidentes',
                ),
              ),
            )
          : null,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: () => _loadIncidents(refreshing: true),
                color: AppTheme.primary,
                backgroundColor: AppTheme.cardBg,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  children: [
                    if (!widget.isEmbedded) ...[
                      Text(
                        _t(
                          es: 'Incidentes',
                          en: 'Incidents',
                          ay: 'Incidentes',
                          qu: 'Incidentes',
                        ),
                        style: AppTheme.headlineLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _t(
                          es: 'Aqui se registra cada caso y su contexto. Las evidencias se vinculan despues, de forma explicita, desde el detalle del incidente o de la evidencia.',
                          en: 'Each case and its context are recorded here. Evidence is linked later, explicitly, from the incident or evidence detail.',
                          ay: 'Akan sapa cason contexto qillqt\'atawa. Evidencianakax qhipatwa chiqap mayachasi, incidente jan ukax evidencia detalle tuqita.',
                          qu: 'Kaypi sapa kasopa contexton qillqasqa kashan. Evidenciakunaqa qhipaman, sut\'inchasqa llamk\'aywan, incidente utaq evidencia detallenninmanta tinkichisqa kan.',
                        ),
                        style: AppTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                    ],
                    ActionPanelCard(
                      icon: Icons.note_add_rounded,
                      accentColor: AppTheme.warning,
                      title: _t(
                        es: 'Registrar un nuevo incidente',
                        en: 'Register a new incident',
                        ay: 'Machaq incidente qillqanta',
                        qu: 'Musuq incidenteta qillqay',
                      ),
                      subtitle: _t(
                        es: 'Crea el caso primero y organiza su contexto. Las evidencias se agregan despues, solo cuando decidas vincularlas.',
                        en: 'Create the case first and organize its context. Evidence is added later only when you decide to link it.',
                        ay: 'Nayraqata caso luram ukat contextop wakicht\'am. Evidencianakax qhipatwa yapxatata, mayachañ munasakixa.',
                        qu: 'Ñawpaqta kasota ruway hinaspa contextonta allichay. Evidenciakunaqa qhipamanmi yapasqa kanqa, tinkichiyta munaspallayki chayqa.',
                      ),
                      actionLabel: _t(
                        es: 'Crear incidente',
                        en: 'Create incident',
                        ay: 'Incidente lura',
                        qu: 'Incidenteta ruway',
                      ),
                      actionIcon: Icons.add_rounded,
                      onPressed: _openCreateIncident,
                    ),
                    if (_statusMessage != null) ...[
                      const SizedBox(height: 16),
                      StatusBanner(
                        message: _statusMessage!,
                        isWarning: _isShowingCache,
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _t(
                                  es: 'Casos registrados',
                                  en: 'Registered cases',
                                  ay: 'Qillqt\'ata casos',
                                  qu: 'Qillqasqa casos',
                                ),
                                style: AppTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _t(
                                  es: 'Cada incidente vive como una entidad propia y mantiene su espacio para asociar evidencias sin mezclar el alta inicial.',
                                  en: 'Each incident lives as its own entity and keeps its own space to associate evidence without mixing the initial registration.',
                                  ay: 'Sapa incidentex sapakjamaw utji ukat evidencianak mayachañataki pachpa chiqaniwa, qallta qillqantawimpi jan chhaqhtayasa.',
                                  qu: 'Sapa incidenteqa sapallan entidadmi kashan hinaspa evidenciakunata tinkichinapaq kikin rakinta waqaychan, qallariy qillqaywan mana chaqruspa.',
                                ),
                                style: AppTheme.bodyMedium.copyWith(
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_isRefreshing)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_incidents.isEmpty)
                      EmptyStateCard(
                        icon: Icons.assignment_late_outlined,
                        title: _t(
                          es: 'Aun no hay incidentes',
                          en: 'There are no incidents yet',
                          ay: 'Janiw incidentenakax utjkiti',
                          qu: 'Manaraq incidentekuna kanchu',
                        ),
                        subtitle: _t(
                          es: 'Los incidentes se crean desde esta misma seccion. Cuando registres el primero, aqui se mantendra su contexto y luego podras vincularle evidencias.',
                          en: 'Incidents are created from this same section. Once you register the first one, its context will stay here and you can link evidence afterwards.',
                          ay: 'Incidentenakax aka pachpa seccionan lurasi. Nayriri qillqantasax, contextop akankaniwa ukat qhipat evidencianak mayachasmawa.',
                          qu: 'Incidentekunaqa kay kikin seccionllapim ruwakun. Ñawpaqta qillqaspaykiqa, contextonqa kaypi kipakunqa hinaspa qhipaman evidenciakunata tinkichiyta atinki.',
                        ),
                        action: CustomButton(
                          text: _t(
                            es: 'Crear incidente',
                            en: 'Create incident',
                            ay: 'Incidente lura',
                            qu: 'Incidenteta ruway',
                          ),
                          icon: Icons.note_add_rounded,
                          onPressed: _openCreateIncident,
                        ),
                      )
                    else
                      ..._incidents.map(
                        (incident) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _IncidentCard(
                            incident: incident,
                            onTap: () => _openIncidentDetail(incident),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  final IncidentRecord incident;
  final VoidCallback onTap;

  const _IncidentCard({required this.incident, required this.onTap});

  Color get _riskColor {
    final normalized = incident.riskLevel.toLowerCase();
    if (normalized.contains('crit')) {
      return AppTheme.error;
    }
    if (normalized.contains('alto')) {
      return AppTheme.warning;
    }
    return AppTheme.primaryLight;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _riskColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.description_rounded, color: _riskColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TranslatedText(incident.title, style: AppTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        formatEvidenceDate(incident.occurredAt),
                        style: AppTheme.bodyMedium.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _IncidentTag(
                  label: incident.status,
                  color: AppTheme.primaryLight,
                ),
                _IncidentTag(label: incident.riskLevel, color: _riskColor),
                _IncidentTag(
                  label: incident.type,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (incident.description.trim().isEmpty)
              Text(
                AppLanguageService.instance.pick(
                  es: 'Sin contexto adicional registrado.',
                  en: 'No additional context recorded.',
                  ay: 'Janiw yaqha contexto qillqt\'atakti.',
                  qu: 'Mana yapasqa contexto qillqasqachu.',
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.bodyMedium,
              )
            else
              TranslatedText(
                incident.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.bodyMedium,
              ),
          ],
        ),
      ),
    );
  }
}

class _IncidentTag extends StatelessWidget {
  final String label;
  final Color color;

  const _IncidentTag({required this.label, required this.color});

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
                en: 'no data',
                ay: 'janiw dato utjkiti',
                qu: 'mana dato kanchu',
              ),
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            )
          : TranslatedText(
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
