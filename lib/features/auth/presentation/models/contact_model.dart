import '../services/auth_identity_mapper.dart';

class ContactModel {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String relation;
  final String? alternativePhone;
  final int priority;
  final bool canReceiveAlerts;

  const ContactModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.relation,
    this.alternativePhone,
    this.priority = 1,
    this.canReceiveAlerts = true,
  });

  ContactModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? relation,
    String? alternativePhone,
    int? priority,
    bool? canReceiveAlerts,
  }) {
    return ContactModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      relation: relation ?? this.relation,
      alternativePhone: alternativePhone ?? this.alternativePhone,
      priority: priority ?? this.priority,
      canReceiveAlerts: canReceiveAlerts ?? this.canReceiveAlerts,
    );
  }

  Map<String, dynamic> toBackendPayload() => {
    'nombre_completo': name.trim(),
    'parentesco': relation.trim().isEmpty ? null : relation.trim(),
    'telefono': AuthIdentityMapper.normalizePhone(phone),
    'telefono_alternativo': _normalizeNullablePhone(alternativePhone),
    'prioridad': priority,
    'puede_recibir_alertas': canReceiveAlerts,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'email': email,
    'relation': relation,
    'telefono_alternativo': alternativePhone,
    'prioridad': priority,
    'puede_recibir_alertas': canReceiveAlerts,
  };

  factory ContactModel.fromJson(Map<String, dynamic> json) => ContactModel(
    id: _readString(json['id']),
    name: _readString(
      json['nombre_completo'],
      fallback: _readString(json['name']),
    ),
    phone: _readString(json['telefono'], fallback: _readString(json['phone'])),
    email: _readNullableEmail(
      json['correo_electronico'],
      fallback: _readNullableEmail(json['email']),
    ),
    relation: _readString(
      json['parentesco'],
      fallback: _readString(
        json['relation'],
        fallback: 'Contacto de emergencia',
      ),
    ),
    alternativePhone: _readNullableString(json['telefono_alternativo']),
    priority: _readInt(json['prioridad'], fallback: 1),
    canReceiveAlerts: _readBool(json['puede_recibir_alertas'], fallback: true),
  );

  static String? _normalizeNullablePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final normalized = AuthIdentityMapper.normalizePhone(value);
    return normalized.isEmpty ? null : normalized;
  }
}

String readContactString(dynamic value, {String fallback = ''}) {
  if (value is String) {
    return value;
  }
  if (value == null) {
    return fallback;
  }
  return value.toString();
}

String _readString(dynamic value, {String fallback = ''}) {
  return readContactString(value, fallback: fallback);
}

String? _readNullableString(dynamic value) {
  final stringValue = _readString(value);
  return stringValue.trim().isEmpty ? null : stringValue;
}

String? _readNullableEmail(dynamic value, {String? fallback}) {
  final normalized = normalizeNullableEmail(readContactString(value));
  if (normalized != null) {
    return normalized;
  }

  return normalizeNullableEmail(fallback);
}

int _readInt(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(_readString(value)) ?? fallback;
}

bool _readBool(dynamic value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  final normalized = _readString(value).toLowerCase();
  if (normalized == 'true') {
    return true;
  }
  if (normalized == 'false') {
    return false;
  }
  return fallback;
}

String? normalizeNullableEmail(String? value) {
  final trimmed = (value ?? '').trim().toLowerCase();
  if (trimmed.isEmpty) {
    return null;
  }

  final isValid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(trimmed);
  return isValid ? trimmed : null;
}
