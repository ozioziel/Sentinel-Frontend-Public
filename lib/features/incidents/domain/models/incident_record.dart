class IncidentRecord {
  final String id;
  final String title;
  final String description;
  final String type;
  final String status;
  final String riskLevel;
  final String location;
  final String occurredAt;

  const IncidentRecord({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.status,
    required this.riskLevel,
    required this.location,
    required this.occurredAt,
  });

  IncidentRecord copyWith({
    String? id,
    String? title,
    String? description,
    String? type,
    String? status,
    String? riskLevel,
    String? location,
    String? occurredAt,
  }) {
    return IncidentRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      riskLevel: riskLevel ?? this.riskLevel,
      location: location ?? this.location,
      occurredAt: occurredAt ?? this.occurredAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'type': type,
    'status': status,
    'riskLevel': riskLevel,
    'location': location,
    'occurredAt': occurredAt,
  };

  factory IncidentRecord.fromJson(Map<String, dynamic> json) {
    return IncidentRecord(
      id: _readString(json['id']),
      title: _readString(json['title'], fallback: 'Incidente'),
      description: _readString(json['description']),
      type: _readString(json['type'], fallback: 'general'),
      status: _readString(json['status'], fallback: 'registrado'),
      riskLevel: _readString(json['riskLevel'], fallback: 'sin definir'),
      location: _readString(json['location']),
      occurredAt: _readString(json['occurredAt'] ?? json['createdAt']),
    );
  }

  factory IncidentRecord.fromBackendJson(Map<String, dynamic> json) {
    return IncidentRecord(
      id: _readString(json['id']),
      title: _readString(
        json['titulo'] ?? json['title'],
        fallback: 'Incidente',
      ),
      description: _readString(json['descripcion'] ?? json['description']),
      type: _readString(
        json['tipo_incidente'] ?? json['type'],
        fallback: 'general',
      ),
      status: _readString(
        json['estado'] ?? json['status'],
        fallback: 'registrado',
      ),
      riskLevel: _readString(
        json['nivel_riesgo'] ?? json['risk_level'],
        fallback: 'sin definir',
      ),
      location: _readString(json['lugar'] ?? json['location']),
      occurredAt: _readString(
        json['fecha_incidente'] ?? json['recorded_at'] ?? json['created_at'],
      ),
    );
  }
}

String _readString(dynamic value, {String fallback = ''}) {
  if (value is String) {
    return value;
  }
  if (value == null) {
    return fallback;
  }
  return value.toString();
}
