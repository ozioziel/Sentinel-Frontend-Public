import 'package:flutter/material.dart';

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
  final EvidenceService _evidenceService = EvidenceService();
  final IncidentService _incidentService = IncidentService();

  late EvidenceRecord _evidence;
  bool _isLoadingDetail = true;
  bool _isUpdatingAssociation = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _evidence = widget.initialEvidence;
    _loadDetail();
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
      }
      _statusMessage = result.message;
      _isLoadingDetail = false;
    });
  }

  Future<void> _manageAssociation() async {
    final selection = await showModalBottomSheet<_AssociationSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AssociationSheet(
        currentIncidentId: _evidence.incidentId,
        incidentService: _incidentService,
      ),
    );

    if (!mounted || selection == null || !selection.didConfirm) {
      return;
    }

    if (selection.incidentId == _evidence.incidentId) {
      return;
    }

    setState(() => _isUpdatingAssociation = true);

    final result = await _evidenceService.updateEvidenceIncident(
      evidence: _evidence,
      incidentId: selection.incidentId,
    );
    if (!mounted) return;

    setState(() {
      if (result.evidence != null) {
        _evidence = result.evidence!;
      }
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

  @override
  Widget build(BuildContext context) {
    final typeStyle = evidenceTypeStyleFor(_evidence.type);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('Detalle de evidencia')),
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
                        label: _evidence.isPrivate ? 'Privada' : 'No privada',
                        color: _evidence.isPrivate
                            ? AppTheme.warning
                            : AppTheme.success,
                      ),
                      EvidenceAssociationBadge(
                        isAssociated: _evidence.isAssociated,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  CustomButton(
                    text: _evidence.isAssociated
                        ? 'Mover o quitar asociacion'
                        : 'Asociar a incidente',
                    icon: _evidence.isAssociated
                        ? Icons.swap_horiz_rounded
                        : Icons.link_rounded,
                    isLoading: _isUpdatingAssociation,
                    onPressed: _isUpdatingAssociation
                        ? null
                        : _manageAssociation,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Vista previa', style: AppTheme.titleLarge),
            const SizedBox(height: 12),
            EvidencePreviewPanel(evidence: _evidence),
            const SizedBox(height: 20),
            Text('Contexto completo', style: AppTheme.titleLarge),
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
                    ? 'No se registro una descripcion para esta evidencia.'
                    : _evidence.description,
                style: AppTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 20),
            Text('Metadatos', style: AppTheme.titleLarge),
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
                    label: 'Privacidad',
                    value: _evidence.isPrivate
                        ? 'Privada para el usuario'
                        : 'Sin restriccion especial',
                  ),
                  const Divider(color: AppTheme.divider),
                  _MetadataRow(
                    label: 'Archivo',
                    value: _evidence.fileName.trim().isEmpty
                        ? 'Sin nombre disponible'
                        : _evidence.fileName,
                  ),
                  const Divider(color: AppTheme.divider),
                  _MetadataRow(
                    label: 'Mime type',
                    value: _evidence.mimeType.trim().isEmpty
                        ? 'No disponible'
                        : _evidence.mimeType,
                  ),
                  const Divider(color: AppTheme.divider),
                  _MetadataRow(
                    label: 'Tamano',
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

class _AssociationSelection {
  final bool didConfirm;
  final String? incidentId;

  const _AssociationSelection({
    required this.didConfirm,
    required this.incidentId,
  });
}

class _AssociationSheet extends StatefulWidget {
  final String? currentIncidentId;
  final IncidentService incidentService;

  const _AssociationSheet({
    required this.currentIncidentId,
    required this.incidentService,
  });

  @override
  State<_AssociationSheet> createState() => _AssociationSheetState();
}

class _AssociationSheetState extends State<_AssociationSheet> {
  String? _selectedIncidentId;
  bool _isLoading = true;
  String? _statusMessage;
  List<IncidentRecord> _incidents = [];

  @override
  void initState() {
    super.initState();
    _selectedIncidentId = widget.currentIncidentId;
    _loadIncidents();
  }

  Future<void> _loadIncidents() async {
    final result = await widget.incidentService.loadIncidents();
    if (!mounted) return;

    setState(() {
      _incidents = result.incidents;
      _statusMessage = result.message;
      _isLoading = false;
    });
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gestionar asociacion', style: AppTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Asocia la evidencia a un incidente, muevela o dejala sin asociacion.',
            style: AppTheme.bodyMedium,
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 12),
            StatusBanner(message: _statusMessage!, isWarning: true),
          ],
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  _AssociationOptionTile(
                    title: 'Sin incidente',
                    subtitle:
                        'La evidencia quedara disponible para asociarla despues.',
                    selected: _selectedIncidentId == null,
                    onTap: () {
                      setState(() => _selectedIncidentId = null);
                    },
                  ),
                  ..._incidents.map(
                    (incident) => _AssociationOptionTile(
                      title: incident.title,
                      subtitle: formatEvidenceDate(incident.occurredAt),
                      selected: _selectedIncidentId == incident.id,
                      onTap: () {
                        setState(() => _selectedIncidentId = incident.id);
                      },
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          CustomButton(
            text: 'Guardar asociacion',
            icon: Icons.save_outlined,
            onPressed: _isLoading
                ? null
                : () {
                    Navigator.pop(
                      context,
                      _AssociationSelection(
                        didConfirm: true,
                        incidentId: _selectedIncidentId,
                      ),
                    );
                  },
          ),
        ],
      ),
    );
  }
}

class _AssociationOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _AssociationOptionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.14)
              : AppTheme.surface.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.divider,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTheme.bodyMedium.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? AppTheme.primary : AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
