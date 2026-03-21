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
        es:
            'La evidencia se guardo en la bandeja. Si despues la necesitas para un caso, podras vincularla desde su detalle.',
        en:
            'The evidence was saved in the inbox. If you later need it for a case, you can link it from its detail.',
        ay:
            'Evidenciax bandejaruw imata. Qhipat casoatak munasax detalle tuqit mayachasmawa.',
        qu:
            'Evidenciaqa bandejapim waqaychasqa karqan. Qhipaman kasopaq munaspaykiqa detallenninmanta hukllachiyta atinki.',
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
                  es: 'Bandeja de evidencias',
                  en: 'Evidence inbox',
                  ay: 'Bandeja de evidencias',
                  qu: 'Bandeja de evidencias',
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
                          es: 'Bandeja de evidencias',
                          en: 'Evidence inbox',
                          ay: 'Bandeja de evidencias',
                          qu: 'Bandeja de evidencias',
                        ),
                        style: AppTheme.headlineLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _t(
                          es:
                              'Aqui solo recopilas archivos y los dejas listos para usarlos despues. El incidente sigue siendo el caso principal.',
                          en:
                              'Here you only gather files and leave them ready to use later. The incident remains the main case.',
                          ay:
                              'Akan archivonakaki tantachtasma ukat qhipat apnaqañatak wakichtasma. Incidentex jacha caso satawa.',
                          qu:
                              'Kaypiqa archivokunallatam huñunki hinaspa qhipaman llamkhanaykipaq wakichinki. Incidenteqa hatun kasollam kashan.',
                        ),
                        style: AppTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                    ],
                    StatusBanner(
                      message: _t(
                        es:
                            'Piensa en esta seccion como una bandeja: aqui guardas evidencias sueltas. Cuando quieras construir un caso, las adjuntas a un incidente.',
                        en:
                            'Think of this section as an inbox: here you store loose evidence. When you want to build a case, attach it to an incident.',
                        ay:
                            'Aka seccionxa bandejar uñtasim: akanwa sapak evidencianak imta. Caso lurañ munasax incidente ukar mayacham.',
                        qu:
                            'Kay seccionta bandeja hina yuyay: kaypim sapallan evidenciakunata waqaychanki. Kaso ruwayta munaspaykiqa, incidenteman hukllachiy.',
                      ),
                    ),
                    const SizedBox(height: 20),
                    ActionPanelCard(
                      icon: Icons.upload_file_rounded,
                      accentColor: AppTheme.primaryLight,
                      title: _t(
                        es: 'Guardar una nueva evidencia',
                        en: 'Save new evidence',
                        ay: 'Machaq evidencia ima',
                        qu: 'Musuq evidenciata waqaychay',
                      ),
                      subtitle: _t(
                        es:
                            'Guarda archivos por separado y decide despues si quieres relacionarlos con un incidente. No se vinculan automaticamente.',
                        en:
                            'Save files separately and decide later if you want to relate them to an incident. They are not linked automatically.',
                        ay:
                            'Archivonak sapaki imasim ukat qhipat amtam incidente ukamp mayachañataki. Janiw automatico mayachatakiti.',
                        qu:
                            'Archivokunata sapallan waqaychay hinaspa qhipaman yuyay incidentewan tinkichinaykipaq. Mana automatico tinkisqachu kan.',
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
                              es: 'Archivos recopilados',
                              en: 'Collected files',
                              ay: 'Tantachata archivonaka',
                              qu: 'Huñusqa archivokuna',
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
                          es:
                              'Puedes subir archivos sin asociarlos a un incidente. Cuando los necesites para un caso, podras vincularlos despues desde su detalle o desde el incidente.',
                          en:
                              'You can upload files without linking them to an incident. When you need them for a case, you can link them later from the detail or from the incident.',
                          ay:
                              'Archivonak jan incidenter mayachasaw apkatasma. Caso munasax qhipat detalle jan ukax incidente tuqit mayachasmawa.',
                          qu:
                              'Archivokunata mana incidenteman tinkichispa wichariyta atinki. Kasonaqpaq munaspaykiqa qhipaman detallenninmanta utaq incidentemanta hukllachiyta atinki.',
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
