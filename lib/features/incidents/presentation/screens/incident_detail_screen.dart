import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../evidence/domain/models/evidence_record.dart';
import '../../../evidence/presentation/screens/evidence_detail_screen.dart';
import '../../../evidence/presentation/services/evidence_service.dart';
import '../../../evidence/presentation/widgets/evidence_components.dart';
import '../../domain/models/incident_record.dart';
import '../services/incident_service.dart';

class IncidentDetailScreen extends StatefulWidget {
  final IncidentRecord initialIncident;

  const IncidentDetailScreen({super.key, required this.initialIncident});

  @override
  State<IncidentDetailScreen> createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends State<IncidentDetailScreen> {
  final IncidentService _incidentService = IncidentService();
  final EvidenceService _evidenceService = EvidenceService();

  late IncidentRecord _incident;
  List<EvidenceRecord> _allEvidences = [];
  List<EvidenceRecord> _incidentEvidences = [];
  bool _isLoadingEvidences = true;
  bool _isRefreshing = false;
  bool _isSavingIncident = false;
  bool _isUpdatingAssociation = false;
  String? _statusMessage;

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
      await _loadIncidentData(refreshing: true);
    }

    _showSnackBar(result.message);
  }

  Future<void> _showFutureReportFlow(String institution) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Flujo futuro de denuncia', style: AppTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Se dejara listo para enviar este incidente a $institution con seleccion de evidencias, confirmacion final y envio automatico.',
              style: AppTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            const _PlaceholderStep(index: 1, title: 'Seleccionar evidencias'),
            const _PlaceholderStep(index: 2, title: 'Confirmar informacion'),
            const _PlaceholderStep(index: 3, title: 'Enviar a la institucion'),
            const SizedBox(height: 18),
            const StatusBanner(
              message:
                  'TODO: conectar este flujo con backend legal/RAG e integracion final de denuncias automaticas.',
            ),
          ],
        ),
      ),
    );
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
      appBar: AppBar(title: const Text('Detalle de incidente')),
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
              Text('1. Contexto del incidente', style: AppTheme.titleLarge),
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
                              Text(
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
                            child: Text(
                              _incident.location,
                              style: AppTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    Text(
                      _incident.description.trim().isEmpty
                          ? 'Todavia no hay contexto adicional registrado para este incidente.'
                          : _incident.description,
                      style: AppTheme.bodyLarge,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: 'Editar contexto',
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
                      'Acciones preparadas para denuncia futura',
                      style: AppTheme.labelLarge,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showFutureReportFlow('Fiscalia'),
                            icon: const Icon(Icons.account_balance_outlined),
                            label: const Text('Fiscalia'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showFutureReportFlow('Policia'),
                            icon: const Icon(Icons.local_police_outlined),
                            label: const Text('Policia'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('2. Evidencias asociadas', style: AppTheme.titleLarge),
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
                            '${_incidentEvidences.length} vinculadas',
                            style: AppTheme.titleLarge,
                          ),
                        ),
                        CustomButton(
                          text: 'Agregar existentes',
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
                      'Puedes agregar evidencias sin incidente o moverlas desde otro caso usando PUT /evidences/:id/incident.',
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
                      const EmptyStateCard(
                        icon: Icons.link_off_rounded,
                        title: 'Sin evidencias asociadas',
                        subtitle:
                            'Agrega evidencias existentes desde tu bandeja o mueve archivos desde otros incidentes.',
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
                              tooltip: 'Quitar del incidente',
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('3. Informacion legal', style: AppTheme.titleLarge),
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
                    const Row(
                      children: [
                        Icon(Icons.gavel_rounded, color: AppTheme.primaryLight),
                        SizedBox(width: 10),
                        Text('Panel reservado', style: AppTheme.titleLarge),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Aqui se integrara la capa legal futura: resumen del caso, instituciones sugeridas segun contexto, checklist de envio y soporte RAG/backend.',
                      style: AppTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    const StatusBanner(
                      message:
                          'TODO: conectar informacion legal contextual y estado de denuncias automaticas.',
                    ),
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

class _EvidencePickerSheet extends StatelessWidget {
  final String currentIncidentId;
  final List<EvidenceRecord> evidences;

  const _EvidencePickerSheet({
    required this.currentIncidentId,
    required this.evidences,
  });

  @override
  Widget build(BuildContext context) {
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
          Text('Agregar evidencias existentes', style: AppTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Selecciona archivos de tu bandeja. Si ya pertenecen a otro incidente, se moveran a este caso.',
            style: AppTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (evidences.isEmpty)
            const EmptyStateCard(
              icon: Icons.perm_media_outlined,
              title: 'No hay evidencias disponibles',
              subtitle:
                  'Primero crea evidencias en su modulo para poder asociarlas aqui.',
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: evidences.map((evidence) {
                  final isCurrent = evidence.incidentId == currentIncidentId;
                  final actionLabel = isCurrent
                      ? 'Ya asociada'
                      : evidence.isAssociated
                      ? 'Mover'
                      : 'Agregar';

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
            Text('Editar contexto', style: AppTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Ajusta el titulo y el contexto principal del incidente.',
              style: AppTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _titleController,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Titulo del incidente',
                prefixIcon: Icon(Icons.title_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              minLines: 5,
              maxLines: 7,
              decoration: const InputDecoration(
                labelText: 'Contexto completo',
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 76),
                  child: Icon(Icons.notes_rounded),
                ),
              ),
            ),
            const SizedBox(height: 18),
            CustomButton(
              text: 'Guardar cambios',
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

class _PlaceholderStep extends StatelessWidget {
  final int index;
  final String title;

  const _PlaceholderStep({required this.index, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Center(
              child: Text(
                '$index',
                style: AppTheme.labelLarge.copyWith(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: AppTheme.bodyMedium)),
        ],
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
      child: Text(
        label.trim().isEmpty ? 'sin dato' : label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
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
