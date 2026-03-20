import 'package:path/path.dart' as p;

class EvidenceRecord {
  final String id;
  final String title;
  final String description;
  final String type;
  final String createdAt;
  final String takenAt;
  final String? incidentId;
  final String fileUrl;
  final String fileName;
  final String mimeType;
  final bool isPrivate;
  final int? sizeBytes;

  const EvidenceRecord({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.createdAt,
    required this.takenAt,
    required this.incidentId,
    required this.fileUrl,
    required this.fileName,
    required this.mimeType,
    required this.isPrivate,
    required this.sizeBytes,
  });

  bool get isAssociated => (incidentId ?? '').trim().isNotEmpty;

  String get displayDate => takenAt.trim().isNotEmpty ? takenAt : createdAt;

  String get previewText {
    final normalized = description.trim();
    if (normalized.isNotEmpty) {
      return normalized;
    }

    if (fileName.trim().isNotEmpty) {
      return fileName;
    }

    return 'Sin descripcion adicional.';
  }

  EvidenceRecord copyWith({
    String? id,
    String? title,
    String? description,
    String? type,
    String? createdAt,
    String? takenAt,
    String? incidentId,
    bool clearIncidentId = false,
    String? fileUrl,
    String? fileName,
    String? mimeType,
    bool? isPrivate,
    int? sizeBytes,
  }) {
    return EvidenceRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      takenAt: takenAt ?? this.takenAt,
      incidentId: clearIncidentId ? null : (incidentId ?? this.incidentId),
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      isPrivate: isPrivate ?? this.isPrivate,
      sizeBytes: sizeBytes ?? this.sizeBytes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'type': type,
    'createdAt': createdAt,
    'takenAt': takenAt,
    'incidentId': incidentId,
    'fileUrl': fileUrl,
    'fileName': fileName,
    'mimeType': mimeType,
    'isPrivate': isPrivate,
    'sizeBytes': sizeBytes,
  };

  factory EvidenceRecord.fromJson(Map<String, dynamic> json) {
    return EvidenceRecord(
      id: _readString(json['id']),
      title: _pickTitle(json),
      description: _readString(json['description']),
      type: _normalizeEvidenceType(
        json['type'] ?? json['tipo_evidencia'] ?? json['tipo'],
      ),
      createdAt: _readString(json['createdAt'] ?? json['created_at']),
      takenAt: _readString(
        json['takenAt'] ?? json['taken_at'] ?? json['captured_at'],
      ),
      incidentId: _readNullableString(
        json['incidentId'] ?? json['incident_id'] ?? json['incidente_id'],
      ),
      fileUrl: _pickFileUrl(json),
      fileName: _pickFileName(json),
      mimeType: _readString(json['mimeType'] ?? json['mime_type']),
      isPrivate: _readBool(json['isPrivate'] ?? json['is_private']),
      sizeBytes: _readInt(json['sizeBytes'] ?? json['size_bytes']),
    );
  }

  factory EvidenceRecord.fromBackendJson(Map<String, dynamic> json) {
    return EvidenceRecord(
      id: _readString(json['id']),
      title: _pickTitle(json),
      description: _readString(json['descripcion'] ?? json['description']),
      type: _normalizeEvidenceType(
        json['tipo_evidencia'] ?? json['type'] ?? json['tipo'],
      ),
      createdAt: _readString(json['created_at']),
      takenAt: _readString(
        json['taken_at'] ?? json['captured_at'] ?? json['created_at'],
      ),
      incidentId: _readNullableString(
        json['incident_id'] ?? json['incidente_id'],
      ),
      fileUrl: _pickFileUrl(json),
      fileName: _pickFileName(json),
      mimeType: _readString(json['mime_type'] ?? json['content_type']),
      isPrivate: _readBool(json['is_private'] ?? json['private']),
      sizeBytes: _readInt(json['size_bytes'] ?? json['file_size']),
    );
  }
}

String _pickTitle(Map<String, dynamic> json) {
  final directTitle = _readString(
    json['titulo'] ?? json['title'] ?? json['nombre'],
  );
  if (directTitle.trim().isNotEmpty) {
    return directTitle;
  }

  final fileName = _pickFileName(json);
  if (fileName.trim().isNotEmpty) {
    return fileName;
  }

  final type = _normalizeEvidenceType(
    json['tipo_evidencia'] ?? json['type'] ?? json['tipo'],
  );
  return switch (type) {
    'video' => 'Video',
    'audio' => 'Audio',
    'imagen' => 'Imagen',
    'texto' => 'Texto',
    _ => 'Documento',
  };
}

String _pickFileUrl(Map<String, dynamic> json) {
  return _readString(
    json['url'] ??
        json['file_url'] ??
        json['archivo_url'] ??
        json['signed_url'] ??
        json['temporary_url'] ??
        json['download_url'] ??
        json['path'] ??
        json['filePath'],
  );
}

String _pickFileName(Map<String, dynamic> json) {
  final directName = _readString(
    json['file_name'] ?? json['filename'] ?? json['nombre_archivo'],
  );
  if (directName.trim().isNotEmpty) {
    return directName;
  }

  final source = _pickFileUrl(json);
  if (source.trim().isEmpty) {
    return '';
  }

  return p.basename(source.split('?').first);
}

String _normalizeEvidenceType(dynamic value) {
  final normalized = _readString(value).trim().toLowerCase();
  switch (normalized) {
    case 'image':
    case 'imagen':
      return 'imagen';
    case 'video':
      return 'video';
    case 'audio':
      return 'audio';
    case 'text':
    case 'texto':
      return 'texto';
    case 'document':
    case 'doc':
    case 'documento':
      return 'documento';
    default:
      return normalized.isEmpty ? 'documento' : normalized;
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

String? _readNullableString(dynamic value) {
  final normalized = _readString(value);
  return normalized.trim().isEmpty ? null : normalized;
}

bool _readBool(dynamic value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  final normalized = _readString(value).trim().toLowerCase();
  if (normalized == 'true' || normalized == '1') {
    return true;
  }
  if (normalized == 'false' || normalized == '0') {
    return false;
  }
  return fallback;
}

int? _readInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(_readString(value));
}
