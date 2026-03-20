import 'package:flutter/material.dart';

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

  int get _associatedCount =>
      _evidences.where((evidence) => evidence.isAssociated).length;

  int get _unassociatedCount => _evidences.length - _associatedCount;

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
      _statusMessage = 'La nueva evidencia ya aparece en tu bandeja.';
      _isShowingCache = false;
    });
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
          ? AppBar(title: const Text('Evidencias'))
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
                      Text('Evidencias', style: AppTheme.headlineLarge),
                      const SizedBox(height: 6),
                      Text(
                        'Revisa, crea y organiza tus archivos sin depender de un incidente. Luego podras asociarlos cuando lo necesites.',
                        style: AppTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: SummaryMetricCard(
                            label: 'Total',
                            value: _evidences.length.toString(),
                            color: AppTheme.primaryLight,
                            icon: Icons.folder_copy_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SummaryMetricCard(
                            label: 'Asociadas',
                            value: _associatedCount.toString(),
                            color: AppTheme.success,
                            icon: Icons.link_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SummaryMetricCard(
                            label: 'Sin incidente',
                            value: _unassociatedCount.toString(),
                            color: AppTheme.warning,
                            icon: Icons.layers_clear_rounded,
                          ),
                        ),
                      ],
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
                              Text('Tu bandeja', style: AppTheme.titleLarge),
                              const SizedBox(height: 4),
                              Text(
                                'GET /evidences trae evidencias asociadas y no asociadas en el orden del backend.',
                                style: AppTheme.bodyMedium.copyWith(
                                  fontSize: 12,
                                ),
                              ),
                            ],
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
                        CustomButton(
                          text: 'Nueva evidencia',
                          icon: Icons.add_rounded,
                          fullWidth: false,
                          height: 44,
                          onPressed: _openCreateScreen,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_evidences.isEmpty)
                      EmptyStateCard(
                        icon: Icons.perm_media_outlined,
                        title: 'Aun no hay evidencias',
                        subtitle:
                            'Ahora puedes subir archivos sin asociarlos a un incidente. Empieza creando tu primera evidencia.',
                        action: CustomButton(
                          text: 'Crear evidencia',
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
