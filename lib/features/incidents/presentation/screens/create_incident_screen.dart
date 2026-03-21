import 'package:flutter/material.dart';

import '../../../../core/localization/app_language_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../evidence/presentation/widgets/evidence_components.dart';
import '../../domain/models/incident_record.dart';
import '../services/incident_service.dart';

class CreateIncidentScreen extends StatefulWidget {
  const CreateIncidentScreen({super.key});

  @override
  State<CreateIncidentScreen> createState() => _CreateIncidentScreenState();
}

class _CreateIncidentScreenState extends State<CreateIncidentScreen> {
  final IncidentService _service = IncidentService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  String _selectedType = 'general';
  String _selectedRiskLevel = 'sin definir';
  DateTime _occurredAt = DateTime.now();
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
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickOccurredAt() async {
    final initialDate = _occurredAt;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(initialDate.year - 5),
      lastDate: DateTime(initialDate.year + 1),
    );
    if (!mounted || pickedDate == null) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _occurredAt = pickedTime == null
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
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await _service.createIncident(
      title: _titleController.text,
      description: _descriptionController.text,
      location: _locationController.text,
      type: _selectedType,
      riskLevel: _selectedRiskLevel,
      occurredAt: _occurredAt,
    );

    if (!mounted) {
      return;
    }

    setState(() => _isSubmitting = false);

    if (!result.success || result.incident == null) {
      _showSnackBar(result.message);
      return;
    }

    Navigator.pop<IncidentRecord>(context, result.incident);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  DropdownMenuItem<String> _typeItem(String value) {
    final label = switch (value) {
      'general' => _t(
        es: 'General',
        en: 'General',
        ay: 'General',
        qu: 'General',
      ),
      'acoso' => _t(es: 'Acoso', en: 'Harassment', ay: 'Acoso', qu: 'Acoso'),
      'violencia' => _t(
        es: 'Violencia',
        en: 'Violence',
        ay: 'Violencia',
        qu: 'Violencia',
      ),
      'seguimiento' => _t(
        es: 'Seguimiento',
        en: 'Stalking',
        ay: 'Seguimiento',
        qu: 'Seguimiento',
      ),
      _ => _t(
        es: 'Emergencia',
        en: 'Emergency',
        ay: 'Emergencia',
        qu: 'Emergencia',
      ),
    };

    return DropdownMenuItem(value: value, child: Text(label));
  }

  DropdownMenuItem<String> _riskItem(String value) {
    final label = switch (value) {
      'bajo' => _t(es: 'Bajo', en: 'Low', ay: 'Bajo', qu: 'Bajo'),
      'medio' => _t(es: 'Medio', en: 'Medium', ay: 'Medio', qu: 'Medio'),
      'alto' => _t(es: 'Alto', en: 'High', ay: 'Alto', qu: 'Alto'),
      'critico' => _t(
        es: 'Critico',
        en: 'Critical',
        ay: 'Critico',
        qu: 'Critico',
      ),
      _ => _t(
        es: 'Sin definir',
        en: 'Undefined',
        ay: 'Sin definir',
        qu: 'Sin definir',
      ),
    };

    return DropdownMenuItem(value: value, child: Text(label));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(
          _t(
            es: 'Nuevo incidente',
            en: 'New incident',
            ay: 'Machaq incidente',
            qu: 'Musuq incidente',
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
                  es: 'Crea el caso por separado',
                  en: 'Create the case separately',
                  ay: 'Caso sapaki luram',
                  qu: 'Kasota sapallan ruway',
                ),
                style: AppTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _t(
                  es: 'Este formulario registra el incidente y su contexto. Las evidencias se agregan despues, solo si decides vincularlas.',
                  en: 'This form registers the incident and its context. Evidence is added later only if you decide to link it.',
                  ay: 'Aka formulariox incidente ukat contextop qillqanti. Evidencianakax qhipat yapxatatawa, mayachañ munasakixa.',
                  qu: 'Kay formularioqa incidenteta hinaspa contextonta qillqan. Evidenciakunaqa qhipaman yapasqa kanqa, tinkichiyta munaspallayki chayqa.',
                ),
                style: AppTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              StatusBanner(
                message: _t(
                  es: 'Primero se crea el incidente. Luego podras entrar a su detalle y agregar evidencias existentes desde la bandeja.',
                  en: 'The incident is created first. Then you can open its detail and add existing evidence from the inbox.',
                  ay: 'Nayraqata incidente lurasi. Ukat detallepar mantañawa ukat bandejat utjir evidencianak yapxatañawa.',
                  qu: 'Ñawpaqta incidenteqa ruwakun. Chaymanta detallenninman yaykuspa bandejaykimanta kachkaq evidenciakunata yapayta atinki.',
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _titleController,
                maxLength: 80,
                decoration: InputDecoration(
                  labelText: _t(
                    es: 'Titulo del incidente',
                    en: 'Incident title',
                    ay: 'Incidente titulo',
                    qu: 'Incidente titulo',
                  ),
                  prefixIcon: const Icon(Icons.title_rounded),
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return _t(
                      es: 'Escribe un titulo para continuar.',
                      en: 'Enter a title to continue.',
                      ay: 'Sarantañatakix maya titulo qillqt\'am.',
                      qu: 'Qatipananpaq huk sutita qillqay.',
                    );
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                minLines: 4,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: _t(
                    es: 'Contexto o descripcion (opcional)',
                    en: 'Context or description (optional)',
                    ay: 'Contexto jan ukax descripcion (opcional)',
                    qu: 'Contexto utaq descripcion (opcional)',
                  ),
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 72),
                    child: Icon(Icons.notes_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(_selectedType),
                initialValue: _selectedType,
                items: [
                  _typeItem('general'),
                  _typeItem('acoso'),
                  _typeItem('violencia'),
                  _typeItem('seguimiento'),
                  _typeItem('emergencia'),
                ],
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        setState(() => _selectedType = value ?? 'general');
                      },
                decoration: InputDecoration(
                  labelText: _t(
                    es: 'Tipo de incidente',
                    en: 'Incident type',
                    ay: 'Incidente kasta',
                    qu: 'Incidente kasta',
                  ),
                  prefixIcon: const Icon(Icons.category_outlined),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(_selectedRiskLevel),
                initialValue: _selectedRiskLevel,
                items: [
                  _riskItem('sin definir'),
                  _riskItem('bajo'),
                  _riskItem('medio'),
                  _riskItem('alto'),
                  _riskItem('critico'),
                ],
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        setState(
                          () => _selectedRiskLevel = value ?? 'sin definir',
                        );
                      },
                decoration: InputDecoration(
                  labelText: _t(
                    es: 'Nivel de riesgo',
                    en: 'Risk level',
                    ay: 'Riesgo nivel',
                    qu: 'Riesgo nivel',
                  ),
                  prefixIcon: const Icon(Icons.flag_outlined),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _isSubmitting ? null : _pickOccurredAt,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: _t(
                      es: 'Fecha del incidente',
                      en: 'Incident date',
                      ay: 'Incidente uru',
                      qu: 'Incidente p\'unchaw',
                    ),
                    prefixIcon: const Icon(Icons.event_outlined),
                  ),
                  child: Text(
                    formatEvidenceDate(_occurredAt.toIso8601String()),
                    style: AppTheme.bodyLarge,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: _t(
                    es: 'Ubicacion o referencia (opcional)',
                    en: 'Location or reference (optional)',
                    ay: 'Ubicacion jan ukax referencia (opcional)',
                    qu: 'Ubicacion utaq referencia (opcional)',
                  ),
                  prefixIcon: const Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: _t(
                  es: 'Guardar incidente',
                  en: 'Save incident',
                  ay: 'Incidente ima',
                  qu: 'Incidente waqaychay',
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
