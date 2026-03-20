import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_card.dart';
import '../services/evidence_library_service.dart';

class EvidenceLibraryScreen extends StatefulWidget {
  final bool isEmbedded;

  const EvidenceLibraryScreen({super.key, this.isEmbedded = false});

  @override
  State<EvidenceLibraryScreen> createState() => _EvidenceLibraryScreenState();
}

class _EvidenceLibraryScreenState extends State<EvidenceLibraryScreen> {
  final EvidenceLibraryService _service = EvidenceLibraryService();

  List<EvidenceIncidentRecord> _incidents = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _statusMessage;
  bool _isShowingCache = false;

  int get _totalEvidences => _incidents.fold(
    0,
    (count, incident) => count + incident.evidences.length,
  );

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  Future<void> _loadLibrary({bool refreshing = false}) async {
    if (refreshing) {
      setState(() => _isRefreshing = true);
    } else {
      setState(() => _isLoading = true);
    }

    final result = await _service.loadLibrary();
    if (!mounted) return;

    setState(() {
      _incidents = result.incidents;
      _statusMessage = result.message;
      _isShowingCache = result.fromCache;
      _isLoading = false;
      _isRefreshing = false;
    });
  }

  Future<void> _editIncident(EvidenceIncidentRecord incident) async {
    final draft = await showModalBottomSheet<_EditDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditDetailsSheet(
        heading: 'Editar incidente',
        titleLabel: 'Titulo del incidente',
        descriptionLabel: 'Descripcion para la denuncia',
        initialTitle: incident.title,
        initialDescription: incident.description,
        saveLabel: 'Guardar incidente',
      ),
    );

    if (!mounted || draft == null) return;

    final result = await _service.updateIncidentDetails(
      incident: incident,
      title: draft.title,
      description: draft.description,
    );
    if (!mounted) return;

    setState(() {
      _incidents = _incidents.map((item) {
        return item.id == incident.id ? result.incident : item;
      }).toList();
    });

    if (result.message != null) {
      _showSnackBar(result.message!);
    }
  }

  Future<void> _editEvidence(
    EvidenceIncidentRecord incident,
    EvidenceAttachmentRecord evidence,
  ) async {
    final draft = await showModalBottomSheet<_EditDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditDetailsSheet(
        heading: 'Editar evidencia',
        titleLabel: 'Titulo de la evidencia',
        descriptionLabel: 'Descripcion para la denuncia',
        initialTitle: evidence.title,
        initialDescription: evidence.description,
        saveLabel: 'Guardar evidencia',
      ),
    );

    if (!mounted || draft == null) return;

    final result = await _service.updateEvidenceDetails(
      incidentId: incident.id,
      evidence: evidence,
      title: draft.title,
      description: draft.description,
    );
    if (!mounted) return;

    setState(() {
      _incidents = _incidents.map((item) {
        if (item.id != incident.id) {
          return item;
        }

        final updatedEvidences = item.evidences.map((entry) {
          return entry.id == evidence.id ? result.evidence : entry;
        }).toList();

        return item.copyWith(evidences: updatedEvidences);
      }).toList();
    });

    if (result.message != null) {
      _showSnackBar(result.message!);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) {
      return 'Fecha no disponible';
    }

    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];

    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day ${months[date.month - 1]} ${date.year} - $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: widget.isEmbedded ? AppBar(title: const Text('Evidencias')) : null,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: () => _loadLibrary(refreshing: true),
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
                        'Organiza tus incidentes y archivos para facilitar una denuncia.',
                        style: AppTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                    ],
                    _SummaryCard(
                      incidentCount: _incidents.length,
                      evidenceCount: _totalEvidences,
                    ),
                    if (_statusMessage != null) ...[
                      const SizedBox(height: 14),
                      _StatusBanner(
                        message: _statusMessage!,
                        isWarning: _isShowingCache,
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Text('Incidentes registrados', style: AppTheme.titleLarge),
                        const Spacer(),
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
                    const SizedBox(height: 8),
                    Text(
                      'Edita el titulo y la descripcion de cada registro para dejarlo listo antes de denunciar.',
                      style: AppTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    if (_incidents.isEmpty)
                      const _EmptyEvidenceState()
                    else
                      ..._incidents.map(
                        (incident) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _IncidentSectionCard(
                            incident: incident,
                            formattedDate: _formatDate(incident.recordedAt),
                            formatDate: _formatDate,
                            onEditIncident: () => _editIncident(incident),
                            onEditEvidence: (evidence) =>
                                _editEvidence(incident, evidence),
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

class _SummaryCard extends StatelessWidget {
  final int incidentCount;
  final int evidenceCount;

  const _SummaryCard({
    required this.incidentCount,
    required this.evidenceCount,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      backgroundColor: AppTheme.primary.withValues(alpha: 0.08),
      borderColor: AppTheme.primary.withValues(alpha: 0.24),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.gavel_rounded,
                  color: AppTheme.primaryLight,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Facilita tu denuncia', style: AppTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      'Revisa fechas, ordena evidencia y redacta detalles claros antes de compartir el caso.',
                      style: AppTheme.bodyMedium.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricPill(
                  label: 'Incidentes',
                  value: incidentCount.toString(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricPill(
                  label: 'Evidencias',
                  value: evidenceCount.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;

  const _MetricPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          Text(value, style: AppTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(label, style: AppTheme.bodyMedium.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String message;
  final bool isWarning;

  const _StatusBanner({required this.message, required this.isWarning});

  @override
  Widget build(BuildContext context) {
    final color = isWarning ? AppTheme.warning : AppTheme.primaryLight;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isWarning ? Icons.cloud_off_rounded : Icons.info_outline_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTheme.bodyMedium.copyWith(color: color, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyEvidenceState extends StatelessWidget {
  const _EmptyEvidenceState();

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppTheme.textSecondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.folder_open_rounded,
              color: AppTheme.textSecondary,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text('Aun no hay evidencias', style: AppTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Cuando actives una alerta y se suban archivos, aqui podras organizar incidentes y evidencias para una futura denuncia.',
            textAlign: TextAlign.center,
            style: AppTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _IncidentSectionCard extends StatelessWidget {
  final EvidenceIncidentRecord incident;
  final String formattedDate;
  final String Function(String value) formatDate;
  final VoidCallback onEditIncident;
  final ValueChanged<EvidenceAttachmentRecord> onEditEvidence;

  const _IncidentSectionCard({
    required this.incident,
    required this.formattedDate,
    required this.formatDate,
    required this.onEditIncident,
    required this.onEditEvidence,
  });

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

  IconData get _incidentIcon {
    final normalized = incident.type.toLowerCase();
    if (normalized.contains('viol')) {
      return Icons.shield_rounded;
    }
    return Icons.report_gmailerrorred_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      padding: const EdgeInsets.all(16),
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
                child: Icon(_incidentIcon, color: _riskColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(incident.title, style: AppTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      formattedDate,
                      style: AppTheme.bodyMedium.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onEditIncident,
                icon: const Icon(Icons.edit_outlined),
                color: AppTheme.primaryLight,
                tooltip: 'Editar incidente',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TagChip(
                label: incident.status,
                color: AppTheme.primaryLight,
              ),
              _TagChip(label: incident.riskLevel, color: _riskColor),
              _TagChip(label: incident.type, color: AppTheme.textSecondary),
            ],
          ),
          if (incident.description.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(incident.description, style: AppTheme.bodyMedium),
          ],
          if (incident.location.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: AppTheme.textSecondary,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    incident.location,
                    style: AppTheme.bodyMedium.copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const Divider(color: AppTheme.divider),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Evidencias adjuntas', style: AppTheme.labelLarge),
              const SizedBox(width: 8),
              Text(
                '${incident.evidences.length}',
                style: AppTheme.bodyMedium.copyWith(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (incident.evidences.isEmpty)
            Text(
              'Todavia no hay archivos vinculados a este incidente.',
              style: AppTheme.bodyMedium.copyWith(fontSize: 13),
            )
          else
            Column(
              children: incident.evidences.map((evidence) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _EvidenceItemCard(
                    evidence: evidence,
                    formattedDate: formatDate(evidence.capturedAt),
                    onEdit: () => onEditEvidence(evidence),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _EvidenceItemCard extends StatelessWidget {
  final EvidenceAttachmentRecord evidence;
  final String formattedDate;
  final VoidCallback onEdit;

  const _EvidenceItemCard({
    required this.evidence,
    required this.formattedDate,
    required this.onEdit,
  });

  IconData get _icon {
    switch (evidence.type.toLowerCase()) {
      case 'video':
        return Icons.videocam_rounded;
      case 'audio':
        return Icons.graphic_eq_rounded;
      case 'imagen':
        return Icons.image_rounded;
      default:
        return Icons.attach_file_rounded;
    }
  }

  Color get _color {
    switch (evidence.type.toLowerCase()) {
      case 'video':
        return const Color(0xFFEF5350);
      case 'audio':
        return const Color(0xFF26A69A);
      case 'imagen':
        return const Color(0xFF42A5F5);
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icon, color: _color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(evidence.title, style: AppTheme.labelLarge),
                    ),
                    _TagChip(
                      label: evidence.type,
                      color: _color,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  formattedDate,
                  style: AppTheme.bodyMedium.copyWith(fontSize: 12),
                ),
                if (evidence.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    evidence.description,
                    style: AppTheme.bodyMedium.copyWith(fontSize: 13),
                  ),
                ],
                if (evidence.filePath.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    evidence.filePath,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.bodyMedium.copyWith(fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            color: AppTheme.primaryLight,
            tooltip: 'Editar evidencia',
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final Color color;

  const _TagChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.trim().isEmpty ? 'sin dato' : label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EditDraft {
  final String title;
  final String description;

  const _EditDraft({required this.title, required this.description});
}

class _EditDetailsSheet extends StatefulWidget {
  final String heading;
  final String titleLabel;
  final String descriptionLabel;
  final String initialTitle;
  final String initialDescription;
  final String saveLabel;

  const _EditDetailsSheet({
    required this.heading,
    required this.titleLabel,
    required this.descriptionLabel,
    required this.initialTitle,
    required this.initialDescription,
    required this.saveLabel,
  });

  @override
  State<_EditDetailsSheet> createState() => _EditDetailsSheetState();
}

class _EditDetailsSheetState extends State<_EditDetailsSheet> {
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.heading, style: AppTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Deja el registro mas claro y util para presentar una denuncia o compartirlo con una institucion.',
              style: AppTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _titleController,
              maxLength: 60,
              decoration: InputDecoration(
                labelText: widget.titleLabel,
                prefixIcon: const Icon(Icons.title_rounded),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              minLines: 4,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: widget.descriptionLabel,
                alignLabelWithHint: true,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 76),
                  child: Icon(Icons.notes_rounded),
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(
                    context,
                    _EditDraft(
                      title: _titleController.text,
                      description: _descriptionController.text,
                    ),
                  );
                },
                icon: const Icon(Icons.save_outlined),
                label: Text(widget.saveLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
