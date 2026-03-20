import 'package:flutter/material.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../services/contacts_service.dart';

class ContactsScreen extends StatefulWidget {
  final String userId;
  final bool isInitialSetup;

  const ContactsScreen({
    super.key,
    required this.userId,
    this.isInitialSetup = false,
  });

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final ContactsService _service = ContactsService();
  List<ContactModel> _contacts = [];
  bool _isLoading = true;
  bool _didPromptInitialForm = false;

  bool get _isBlockingSetup => widget.isInitialSetup && _contacts.isEmpty;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    final contacts = await _service.getContacts(widget.userId);
    if (!mounted) return;

    setState(() {
      _contacts = contacts;
      _isLoading = false;
    });

    if (widget.isInitialSetup && contacts.isNotEmpty) {
      _finishInitialSetup();
      return;
    }

    if (widget.isInitialSetup && contacts.isEmpty && !_didPromptInitialForm) {
      _didPromptInitialForm = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openForm();
        }
      });
    }
  }

  Future<void> _openForm({ContactModel? contact}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ContactForm(
        userId: widget.userId,
        contact: contact,
        service: _service,
      ),
    );

    if (saved == true) {
      await _loadContacts();
    }
  }

  void _confirmDelete(ContactModel contact) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar contacto', style: AppTheme.titleLarge),
        content: Text(
          '¿Segura que quieres eliminar a ${contact.name}?',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _service.deleteContact(widget.userId, contact.id);
              await _loadContacts();
            },
            child: const Text(
              'Eliminar',
              style: TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _finishInitialSetup() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.home,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isBlockingSetup,
      child: Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: AppBar(
          automaticallyImplyLeading: !_isBlockingSetup,
          title: Text(
            widget.isInitialSetup
                ? 'Tu primer contacto de emergencia'
                : 'Contactos de emergencia',
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add, color: AppTheme.primary),
              onPressed: _openForm,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              )
            : _contacts.isEmpty
            ? _EmptyState(
                onAdd: _openForm,
                isInitialSetup: widget.isInitialSetup,
              )
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: _contacts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _ContactCard(
                  contact: _contacts[i],
                  onEdit: () => _openForm(contact: _contacts[i]),
                  onDelete: () => _confirmDelete(_contacts[i]),
                ),
              ),
        floatingActionButton: _contacts.isNotEmpty
            ? FloatingActionButton(
                onPressed: _openForm,
                backgroundColor: AppTheme.primary,
                child: const Icon(Icons.add, color: Colors.white),
              )
            : null,
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final ContactModel contact;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ContactCard({
    required this.contact,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person, color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.name, style: AppTheme.labelLarge),
                const SizedBox(height: 2),
                Text(
                  contact.relation,
                  style: AppTheme.bodyMedium.copyWith(
                    fontSize: 11,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  contact.phone,
                  style: AppTheme.bodyMedium.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              color: AppTheme.textSecondary,
              size: 20,
            ),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: AppTheme.error,
              size: 20,
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _ContactForm extends StatefulWidget {
  final String userId;
  final ContactModel? contact;
  final ContactsService service;

  const _ContactForm({
    required this.userId,
    required this.service,
    this.contact,
  });

  @override
  State<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<_ContactForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late String _selectedRelation;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final List<String> _relations = [
    'Mama',
    'Papa',
    'Hermana',
    'Hermano',
    'Amiga',
    'Pareja',
    'Otro',
  ];

  bool get _isEditing => widget.contact != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.contact?.name ?? '');
    _phoneController = TextEditingController(text: widget.contact?.phone ?? '');
    _selectedRelation = widget.contact?.relation ?? 'Mama';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    bool success;

    if (_isEditing) {
      final updated = ContactModel(
        id: widget.contact!.id,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        relation: _selectedRelation,
      );
      success = await widget.service.updateContact(widget.userId, updated);
    } else {
      success = await widget.service.addContact(
        widget.userId,
        _nameController.text.trim(),
        _phoneController.text.trim(),
        _selectedRelation,
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      Navigator.pop(context, true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isEditing
              ? 'Error al actualizar el contacto'
              : 'Ese numero ya esta registrado',
        ),
        backgroundColor: AppTheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _isEditing ? 'Editar contacto' : 'Nuevo contacto',
                  style: AppTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Este contacto recibira la alerta de emergencia',
                  style: AppTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  style: AppTheme.bodyLarge,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    prefixIcon: Icon(
                      Icons.person_outline,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Ingresa un nombre';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: AppTheme.bodyLarge,
                  decoration: const InputDecoration(
                    labelText: 'Numero de WhatsApp',
                    prefixIcon: Icon(
                      Icons.phone_outlined,
                      color: AppTheme.textSecondary,
                    ),
                    hintText: '+591 7XXXXXXX',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Ingresa un numero';
                    }
                    final digits = v.replaceAll(RegExp(r'\D'), '');
                    if (digits.length < 8) {
                      return 'Ingresa un numero valido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _selectedRelation,
                  dropdownColor: AppTheme.cardBg,
                  style: AppTheme.bodyLarge,
                  decoration: const InputDecoration(
                    labelText: 'Relacion',
                    prefixIcon: Icon(
                      Icons.people_outline,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  items: _relations.map((relation) {
                    return DropdownMenuItem(
                      value: relation,
                      child: Text(relation),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedRelation = value ?? 'Mama');
                  },
                ),
                const SizedBox(height: 28),
                CustomButton(
                  text: _isEditing ? 'Guardar cambios' : 'Agregar contacto',
                  onPressed: _save,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 12),
                CustomButton(
                  text: 'Cancelar',
                  variant: ButtonVariant.outline,
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  final bool isInitialSetup;

  const _EmptyState({required this.onAdd, this.isInitialSetup = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline,
                color: AppTheme.primary,
                size: 38,
              ),
            ),
            const SizedBox(height: 20),
            Text('Sin contactos aun', style: AppTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              isInitialSetup
                  ? 'Antes de entrar a la app, agrega al menos un contacto de confianza para tus alertas de emergencia.'
                  : 'Agrega contactos de confianza que recibiran tu alerta de emergencia.',
              style: AppTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            CustomButton(
              text: 'Agregar primer contacto',
              onPressed: onAdd,
              fullWidth: false,
            ),
          ],
        ),
      ),
    );
  }
}
