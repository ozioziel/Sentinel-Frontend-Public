import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

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
  String _selectedType = 'auto';
  DateTime? _takenAt;
  bool _isPrivate = true;
  bool _isSubmitting = false;

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
      _showSnackBar('No se pudo acceder al archivo seleccionado.');
      return;
    }

    final file = File(selected.path!);
    final size = await file.length();

    setState(() {
      _selectedFilePath = selected.path;
      _selectedFileName = selected.name;
      _selectedFileSize = size;
      _selectedType = 'auto';
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
      _showSnackBar('Selecciona un archivo antes de continuar.');
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await _service.createEvidence(
      filePath: _selectedFilePath!,
      selectedType: _selectedType,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('Nueva evidencia')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Text(
                'Sube una evidencia independiente',
                style: AppTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Este flujo ya no obliga a elegir un incidente. Puedes registrar el archivo ahora y asociarlo despues.',
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
                        _selectedFileName ?? 'Selecciona un archivo',
                        style: AppTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _selectedFileName == null
                            ? 'Imagen, video, audio o documento de hasta 20 MB.'
                            : '${formatEvidenceSize(_selectedFileSize)} - ${p.extension(_selectedFileName!).replaceFirst('.', '').toUpperCase()}',
                        style: AppTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                key: ValueKey(_selectedType),
                initialValue: _selectedType,
                items: const [
                  DropdownMenuItem(
                    value: 'auto',
                    child: Text('Tipo automatico'),
                  ),
                  DropdownMenuItem(value: 'imagen', child: Text('Imagen')),
                  DropdownMenuItem(value: 'video', child: Text('Video')),
                  DropdownMenuItem(value: 'audio', child: Text('Audio')),
                  DropdownMenuItem(
                    value: 'documento',
                    child: Text('Documento'),
                  ),
                  DropdownMenuItem(value: 'texto', child: Text('Texto')),
                ],
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        setState(() => _selectedType = value ?? 'auto');
                      },
                decoration: const InputDecoration(
                  labelText: 'Tipo de evidencia',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Titulo (opcional)',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                minLines: 4,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Descripcion o contexto (opcional)',
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
                  decoration: const InputDecoration(
                    labelText: 'Fecha de captura (opcional)',
                    prefixIcon: Icon(Icons.event_outlined),
                  ),
                  child: Text(
                    _takenAt == null
                        ? 'Elegir fecha y hora'
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
                title: const Text('Marcar como privada'),
                subtitle: const Text(
                  'Mantiene la evidencia identificada como informacion sensible.',
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              const SizedBox(height: 18),
              const StatusBanner(
                message:
                    'La asociacion con incidentes se gestiona despues desde el detalle de la evidencia o desde el modulo de Incidentes.',
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Guardar evidencia',
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
