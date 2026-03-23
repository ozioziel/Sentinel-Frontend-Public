import 'package:flutter/material.dart';

import '../../../../core/localization/app_language_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_card.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/translated_text.dart';
import '../../domain/models/evidence_record.dart';

class EvidenceTypeStyle {
  final String label;
  final IconData icon;
  final Color color;

  const EvidenceTypeStyle({
    required this.label,
    required this.icon,
    required this.color,
  });
}

String _t({
  required String es,
  required String en,
  required String ay,
  required String qu,
}) {
  return AppLanguageService.instance.pick(es: es, en: en, ay: ay, qu: qu);
}

EvidenceTypeStyle evidenceTypeStyleFor(String type) {
  switch (type.trim().toLowerCase()) {
    case 'audio':
      return EvidenceTypeStyle(
        label: _t(es: 'Audio', en: 'Audio', ay: 'Audio', qu: 'Audio'),
        icon: Icons.graphic_eq_rounded,
        color: Color(0xFF39B7A0),
      );
    case 'video':
      return EvidenceTypeStyle(
        label: _t(es: 'Video', en: 'Video', ay: 'Video', qu: 'Video'),
        icon: Icons.videocam_rounded,
        color: Color(0xFFE26C6C),
      );
    case 'imagen':
      return EvidenceTypeStyle(
        label: _t(es: 'Imagen', en: 'Image', ay: 'Imagen', qu: 'Imagen'),
        icon: Icons.image_rounded,
        color: Color(0xFF64A8FF),
      );
    case 'texto':
      return EvidenceTypeStyle(
        label: _t(es: 'Texto', en: 'Text', ay: 'Texto', qu: 'Texto'),
        icon: Icons.notes_rounded,
        color: Color(0xFFB988FF),
      );
    default:
      return EvidenceTypeStyle(
        label: _t(
          es: 'Documento',
          en: 'Document',
          ay: 'Documento',
          qu: 'Documento',
        ),
        icon: Icons.description_rounded,
        color: Color(0xFFF0A15E),
      );
  }
}

String formatEvidenceDate(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) {
    return _t(
      es: 'Fecha no disponible',
      en: 'Date unavailable',
      ay: 'Uru janiw utjkiti',
      qu: 'P\'unchaw mana kanchu',
    );
  }

  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString().padLeft(4, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day/$month/$year - $hour:$minute';
}

String formatEvidenceSize(int? bytes) {
  if (bytes == null || bytes <= 0) {
    return _t(
      es: 'Tamano no disponible',
      en: 'Size unavailable',
      ay: 'Tamano janiw utjkiti',
      qu: 'Tamano mana kanchu',
    );
  }
  if (bytes < 1024) {
    return '$bytes B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class StatusBanner extends StatelessWidget {
  final String message;
  final bool isWarning;

  const StatusBanner({
    super.key,
    required this.message,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isWarning ? AppTheme.warning : AppTheme.primaryLight;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isWarning
                ? Icons.warning_amber_rounded
                : Icons.info_outline_rounded,
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

class DismissibleStatusBanner extends StatelessWidget {
  final String message;
  final bool isWarning;
  final VoidCallback onDismiss;

  const DismissibleStatusBanner({
    super.key,
    required this.message,
    required this.onDismiss,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isWarning ? AppTheme.warning : AppTheme.primaryLight;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isWarning
                ? Icons.warning_amber_rounded
                : Icons.info_outline_rounded,
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
          const SizedBox(width: 8),
          InkWell(
            onTap: onDismiss,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.close_rounded, color: color, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.textSecondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: AppTheme.textSecondary, size: 28),
          ),
          const SizedBox(height: 14),
          Text(title, style: AppTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: AppTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

class EvidenceAssociationBadge extends StatelessWidget {
  final bool isAssociated;

  const EvidenceAssociationBadge({super.key, required this.isAssociated});

  @override
  Widget build(BuildContext context) {
    final color = isAssociated ? AppTheme.success : AppTheme.warning;
    final label = isAssociated
        ? _t(es: 'Asociada', en: 'Linked', ay: 'Mayachata', qu: 'Tinkisqa')
        : _t(
            es: 'Sin incidente',
            en: 'No incident',
            ay: 'Jan incidenteni',
            qu: 'Mana incidenteyuq',
          );
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

class EvidenceCard extends StatelessWidget {
  final EvidenceRecord evidence;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showAssociation;
  final bool compact;

  const EvidenceCard({
    super.key,
    required this.evidence,
    this.onTap,
    this.trailing,
    this.showAssociation = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = evidenceTypeStyleFor(evidence.type);
    final preview = evidence.previewText;

    return CustomCard(
      onTap: onTap,
      padding: EdgeInsets.all(compact ? 14 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 42 : 48,
            height: compact ? 42 : 48,
            decoration: BoxDecoration(
              color: style.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              style.icon,
              color: style.color,
              size: compact ? 20 : 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TranslatedText(
                        evidence.title,
                        style: AppTheme.titleLarge.copyWith(
                          fontSize: compact ? 16 : 18,
                        ),
                      ),
                    ),
                    if (showAssociation)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: EvidenceAssociationBadge(
                          isAssociated: evidence.isAssociated,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _TagChip(label: style.label, color: style.color),
                    _TagChip(
                      label: formatEvidenceDate(evidence.displayDate),
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TranslatedText(
                  preview,
                  style: AppTheme.bodyMedium.copyWith(fontSize: 13),
                  maxLines: compact ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

class SummaryMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const SummaryMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 10),
          Text(value, style: AppTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(label, style: AppTheme.bodyMedium.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}

class ActionPanelCard extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback? onPressed;
  final bool isLoading;

  const ActionPanelCard({
    super.key,
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.actionIcon,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accentColor.withValues(alpha: 0.22), AppTheme.cardBg],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accentColor.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(subtitle, style: AppTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          CustomButton(
            text: actionLabel,
            icon: actionIcon,
            isLoading: isLoading,
            onPressed: onPressed,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.trim().isEmpty
            ? _t(
                es: 'sin dato',
                en: 'no data',
                ay: 'janiw dato utjkiti',
                qu: 'mana dato kanchu',
              )
            : label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
