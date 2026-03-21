import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../../core/localization/app_language_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../domain/models/evidence_record.dart';
import '../services/evidence_service.dart';
import '../widgets/evidence_components.dart';

class CreateEvidenceScreen extends StatefulWidget {
  const CreateEvidenceScreen({super.key});

  @override
  State<CreateEvidenceScreen> createState() => _CreateEvidenceScreenState();
}

class _CreateEvidenceScreenState extends State<CreateEvidenceScreen> {
  final EvidenceService _service = EvidenceService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String? _selectedFilePath;
  String? _selectedFileName;
  int? _selectedFileSize;
  String? _detectedType;
  DateTime? _takenAt;
  bool _isPrivate = true;
  bool _isSubmitting = false;

  String _t({
    required String es,
    required String en,
    required String ay,
    required String qu,
  }) {
    return AppLanguageService.instance.pick(es: es, en: en, ay: ay, qu: qu);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const [
        'png',
        'jpg',
        'jpeg',
        'mp4',
        'mov',
        'm4a',
        'aac',
        'mp3',
        'wav',
        'pdf',
        'txt',
        'doc',
        'docx',
        'rtf',
        'odt',
      ],
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final selected = result.files.first;
    if (selected.path == null || selected.path!.trim().isEmpty) {
      _showSnackBar(
        _t(
          es: 'No se pudo acceder al archivo seleccionado.',
          en: 'The selected file could not be accessed.',
          ay: 'Ajllita archivor janiw mantañjamakiti.',
          qu: 'Akllasqa archivoman mana yaykuyta atikurqanchu.',
        ),
      );
      return;
    }

    final file = File(selected.path!);
    final size = await file.length();

    setState(() {
      _selectedFilePath = selected.path;
      _selectedFileName = selected.name;
      _selectedFileSize = size;
      _detectedType = _service.detectEvidenceTypeForFile(selected.path!);
    });
  }

  Future<void> _pickTakenAt() async {
    final now = DateTime.now();
    final initialDate = _takenAt ?? now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (!mounted || pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (!mounted) return;

    setState(() {
      _takenAt = pickedTime == null
          ? DateTime(pickedDate.year, pickedDate.month, pickedDate.day)
          : DateTime(
              pickedDate.year,
              pickedDate.month,
              pickedDate.day,
              pickedTime.hour,
              pickedTime.minute,
            );
    });
  }

  Future<void> _submit() async {
    if (_selectedFilePath == null || _selectedFilePath!.trim().isEmpty) {
      _showSnackBar(
        _t(
          es: 'Selecciona un archivo antes de continuar.',
          en: 'Select a file before continuing.',
          ay: 'Sarantañkamax maya archivo ajllim.',
          qu: 'Qatipananpaq huk archivota akllay.',
        ),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await _service.createEvidence(
      filePath: _selectedFilePath!,
      selectedType: _detectedType,
      title: _titleController.text,
      description: _descriptionController.text,
      takenAt: _takenAt,
      isPrivate: _isPrivate,
    );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (!result.success || result.evidence == null) {
      _showSnackBar(result.message);
      return;
    }

    Navigator.pop<EvidenceRecord>(context, result.evidence);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _detectedTypeLabel(String? type) {
    switch ((type ?? '').trim().toLowerCase()) {
      case 'imagen':
        return _t(es: 'Imagen', en: 'Image', ay: 'Imagen', qu: 'Imagen');
      case 'video':
        return _t(es: 'Video', en: 'Video', ay: 'Video', qu: 'Video');
      case 'audio':
        return _t(es: 'Audio', en: 'Audio', ay: 'Audio', qu: 'Audio');
      case 'texto':
        return _t(es: 'Texto', en: 'Text', ay: 'Texto', qu: 'Texto');
      default:
        return _t(
          es: 'Documento',
          en: 'Document',
          ay: 'Documento',
          qu: 'Documento',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(
          _t(
            es: 'Nueva evidencia',
            en: 'New evidence',
            ay: 'Machaq evidencia',
            qu: 'Musuq evidencia',
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Text(
                _t(
                  es: 'Sube una evidencia independiente',
                  en: 'Upload standalone evidence',
                  ay: 'Sapaki evidencia apkata',
                  qu: 'Sapallan evidencia wichariy',
                ),
                style: AppTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _t(
                  es: 'Este flujo ya no obliga a elegir un incidente. Puedes registrar el archivo ahora y asociarlo despues.',
                  en: 'This flow no longer forces you to choose an incident. You can register the file now and link it later.',
                  ay: 'Aka thakhix janiw incident ajlliñ maykiti. Jichhax archivo qillqantasmawa ukat qhipat mayachasmawa.',
                  qu: 'Kay puriynaqa manan incidenteta akllanapaq obliganchu. Kunanqa archivota qillqayta atinki, qhipaman tinkichiyta atinki.',
                ),
                style: AppTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _isSubmitting ? null : _pickFile,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.upload_file_rounded,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _selectedFileName ??
                            _t(
                              es: 'Selecciona un archivo',
                              en: 'Select a file',
                              ay: 'Maya archivo ajllim',
                              qu: 'Huk archivota akllay',
                            ),
                        style: AppTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _selectedFileName == null
                            ? _t(
                                es: 'Imagen, video, audio o documento de hasta 20 MB.',
                                en: 'Image, video, audio or document up to 20 MB.',
                                ay: 'Imagen, video, audio jan ukax documento 20 MB ukjakama.',
                                qu: 'Imagen, video, audio utaq documento 20 MB kama.',
                              )
                            : '${formatEvidenceSize(_selectedFileSize)} - ${p.extension(_selectedFileName!).replaceFirst('.', '').toUpperCase()}',
                        style: AppTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (_selectedFilePath != null) ...[
                StatusBanner(
                  message: _t(
                    es: 'Tipo detectado automaticamente: ${_detectedTypeLabel(_detectedType)}',
                    en: 'Automatically detected type: ${_detectedTypeLabel(_detectedType)}',
                    ay: 'Automaticon uñt\'ata kasta: ${_detectedTypeLabel(_detectedType)}',
                    qu: 'Automatico reqsisqa kasta: ${_detectedTypeLabel(_detectedType)}',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _titleController,
                maxLength: 80,
                decoration: InputDecoration(
                  labelText: _t(
                    es: 'Titulo (opcional)',
                    en: 'Title (optional)',
                    ay: 'Titulo (opcional)',
                    qu: 'Titulo (opcional)',
                  ),
                  prefixIcon: Icon(Icons.title_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                minLines: 4,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: _t(
                    es: 'Descripcion o contexto (opcional)',
                    en: 'Description or context (optional)',
                    ay: 'Descripcion jan ukax contexto (opcional)',
                    qu: 'Descripcion utaq contexto (opcional)',
                  ),
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 72),
                    child: Icon(Icons.notes_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _isSubmitting ? null : _pickTakenAt,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: _t(
                      es: 'Fecha de captura (opcional)',
                      en: 'Capture date (optional)',
                      ay: 'Katuqawi uru (opcional)',
                      qu: 'Hapiy p\'unchaw (opcional)',
                    ),
                    prefixIcon: Icon(Icons.event_outlined),
                  ),
                  child: Text(
                    _takenAt == null
                        ? _t(
                            es: 'Elegir fecha y hora',
                            en: 'Choose date and time',
                            ay: 'Uru ukat hora ajllim',
                            qu: 'P\'unchawta horatawan akllay',
                          )
                        : formatEvidenceDate(_takenAt!.toIso8601String()),
                    style: _takenAt == null
                        ? AppTheme.bodyMedium
                        : AppTheme.bodyLarge,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                value: _isPrivate,
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        setState(() => _isPrivate = value);
                      },
                title: Text(
                  _t(
                    es: 'Marcar como privada',
                    en: 'Mark as private',
                    ay: 'Privada sasaw chimpt\'am',
                    qu: 'Privada nispa akllay',
                  ),
                ),
                subtitle: Text(
                  _t(
                    es: 'Mantiene la evidencia identificada como informacion sensible.',
                    en: 'Keeps the evidence identified as sensitive information.',
                    ay: 'Evidenciax sensible informacionjam uñt\'ayatawa qhipara.',
                    qu: 'Evidenciaqa sensible informacion hina reqsisqa kachkan.',
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              const SizedBox(height: 18),
              StatusBanner(
                message: _t(
                  es: 'La asociacion con incidentes se gestiona despues desde el detalle de la evidencia, usando un selector desplegable y una accion de guardado explicita.',
                  en: 'Association with incidents is managed later from the evidence detail, using a dropdown selector and an explicit save action.',
                  ay: 'Incidentenakamp mayachawix qhipat evidencia detalle tuqit apnaqatawa, mä desplegable selectorampi ukat chiqap imañampiwa.',
                  qu: 'Incidentekunawan asociacionqa qhipaman evidencia detallenninmanta apanakun, huk desplegable selectorwan hinaspa sut\'inchasqa waqaychaywan.',
                ),
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: _t(
                  es: 'Guardar evidencia',
                  en: 'Save evidence',
                  ay: 'Evidencia ima',
                  qu: 'Evidencia waqaychay',
                ),
                icon: Icons.save_outlined,
                isLoading: _isSubmitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
