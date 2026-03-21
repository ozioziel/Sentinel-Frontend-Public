import 'package:flutter/material.dart';

import '../../../../core/localization/app_language_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../domain/models/evidence_record.dart';
import '../services/evidence_service.dart';
import '../widgets/evidence_components.dart';
import 'create_evidence_screen.dart';
import 'evidence_detail_screen.dart';

class EvidenceLibraryScreen extends StatefulWidget {
  final bool isEmbedded;

  const EvidenceLibraryScreen({super.key, this.isEmbedded = false});

  @override
  State<EvidenceLibraryScreen> createState() => _EvidenceLibraryScreenState();
}

class _EvidenceLibraryScreenState extends State<EvidenceLibraryScreen> {
  final EvidenceService _service = EvidenceService();

  List<EvidenceRecord> _evidences = [];
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
    _loadEvidences();
  }

  Future<void> _loadEvidences({bool refreshing = false}) async {
    if (refreshing) {
      setState(() => _isRefreshing = true);
    } else {
      setState(() => _isLoading = true);
    }

    final result = await _service.loadEvidences();
    if (!mounted) return;

    setState(() {
      _evidences = result.evidences;
      _statusMessage = result.message;
      _isShowingCache = result.fromCache;
      _isLoading = false;
      _isRefreshing = false;
    });
  }

  Future<void> _openCreateScreen() async {
    final createdEvidence = await Navigator.push<EvidenceRecord>(
      context,
      MaterialPageRoute(builder: (_) => const CreateEvidenceScreen()),
    );
    if (!mounted || createdEvidence == null) return;

    setState(() {
      _evidences = [
        createdEvidence,
        ..._evidences.where((item) => item.id != createdEvidence.id),
      ];
      _statusMessage = _t(
        es: 'La evidencia se guardo sin incidente asociado. Puedes vincularla despues desde el selector del detalle.',
        en: 'The evidence was saved without an associated incident. You can link it later from the detail selector.',
        ay: 'Evidenciax janiw incidenter mayachatakiti imatawa. Detalleta selector tuqit qhipat mayachasmawa.',
        qu: 'Evidenciaqa mana incidentewan tinkisqachu waqaychasqa karqan. Detallenninpi selector nisqamanta qhipaman tinkichiyta atinki.',
      );
      _isShowingCache = false;
    });

    if (createdEvidence.id.trim().isEmpty) {
      return;
    }

    await _openEvidenceDetail(createdEvidence);
  }

  Future<void> _openEvidenceDetail(EvidenceRecord evidence) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => EvidenceDetailScreen(initialEvidence: evidence),
      ),
    );
    if (!mounted) return;
    await _loadEvidences(refreshing: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: widget.isEmbedded
          ? AppBar(
              title: Text(
                _t(
                  es: 'Evidencias',
                  en: 'Evidence',
                  ay: 'Evidencias',
                  qu: 'Evidencias',
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
                onRefresh: () => _loadEvidences(refreshing: true),
                color: AppTheme.primary,
                backgroundColor: AppTheme.cardBg,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  children: [
                    if (!widget.isEmbedded) ...[
                      Text(
                        _t(
                          es: 'Evidencias',
                          en: 'Evidence',
                          ay: 'Evidencias',
                          qu: 'Evidencias',
                        ),
                        style: AppTheme.headlineLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _t(
                          es: 'Revisa, crea y organiza tus archivos sin depender de un incidente. Luego podras asociarlos cuando lo necesites, siempre mediante una accion explicita.',
                          en: 'Review, create and organize your files without depending on an incident. You can link them later when needed, always through an explicit action.',
                          ay: 'Archivonakama uñakipa, lura ukat wakicht\'am janiw incidenter atiniskasa. Qhipat munasax chiqap mayachasmawa.',
                          qu: 'Archivoykikunata qhawariy, ruway hinaspa allichay mana incidenteman hapisqachu. Qhipaman munaspayki sut\'inchasqa ruwanaswan tinkichiyta atinki.',
                        ),
                        style: AppTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                    ],
                    ActionPanelCard(
                      icon: Icons.upload_file_rounded,
                      accentColor: AppTheme.primaryLight,
                      title: _t(
                        es: 'Registrar una nueva evidencia',
                        en: 'Register new evidence',
                        ay: 'Machaq evidencia qillqanta',
                        qu: 'Musuq evidenciata qillqay',
                      ),
                      subtitle: _t(
                        es: 'Guarda archivos por separado y decide despues si quieres relacionarlos con un incidente. No se vinculan automaticamente.',
                        en: 'Save files separately and decide later if you want to relate them to an incident. They are not linked automatically.',
                        ay: 'Archivonak sapaki imasim ukat qhipat amtañamawa incidente ukamp mayachañataki. Janiw automatico mayachatäkiti.',
                        qu: 'Archivokunata sapallan waqaychay hinaspa qhipaman yuyay incidentewan tinkichinaykipaq. Mana automatico tinkisqachu kan.',
                      ),
                      actionLabel: _t(
                        es: 'Crear evidencia',
                        en: 'Create evidence',
                        ay: 'Evidencia lura',
                        qu: 'Evidencia ruway',
                      ),
                      actionIcon: Icons.add_rounded,
                      onPressed: _openCreateScreen,
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
                          child: Text(
                            _t(
                              es: 'Evidencias registradas',
                              en: 'Registered evidence',
                              ay: 'Qillqt\'ata evidencias',
                              qu: 'Qillqasqa evidenciakuna',
                            ),
                            style: AppTheme.titleLarge,
                          ),
                        ),
                        if (_isRefreshing)
                          const Padding(
                            padding: EdgeInsets.only(right: 10),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_evidences.isEmpty)
                      EmptyStateCard(
                        icon: Icons.perm_media_outlined,
                        title: _t(
                          es: 'Aun no hay evidencias',
                          en: 'There is no evidence yet',
                          ay: 'Janiw evidencianakax utjkiti',
                          qu: 'Manaraq evidenciakuna kanchu',
                        ),
                        subtitle: _t(
                          es: 'Ahora puedes subir archivos sin asociarlos a un incidente. Cuando la guardes, podras decidir despues si quieres vincularla desde su detalle.',
                          en: 'You can now upload files without linking them to an incident. Once saved, you can later decide whether to link it from its detail.',
                          ay: 'Jichhax archivonak incidenter jan mayachasaw apkatasma. Imatax qhipat detalle tuqit mayachañ munasmati janicha uk amtasmawa.',
                          qu: 'Kunanqa archivokunata incidenteman mana tinkichispayki wichariyta atinki. Waqaychasqaman qhipata detallenninmanta tinkichiyta munankichu manachu nispa akllayta atinki.',
                        ),
                        action: CustomButton(
                          text: _t(
                            es: 'Crear evidencia',
                            en: 'Create evidence',
                            ay: 'Evidencia lura',
                            qu: 'Evidencia ruway',
                          ),
                          icon: Icons.upload_file_rounded,
                          onPressed: _openCreateScreen,
                        ),
                      )
                    else
                      ..._evidences.map(
                        (evidence) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: EvidenceCard(
                            evidence: evidence,
                            onTap: () => _openEvidenceDetail(evidence),
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
