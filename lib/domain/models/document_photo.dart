/// Tipos de documentos del vehículo
enum DocumentType {
  cedulaVerde(0, 'Cédula Verde'),
  cedulaAzul(1, 'Cédula Azul'),
  titulo(2, 'Título'),
  vtv(3, 'VTV');

  final int value;
  final String label;
  const DocumentType(this.value, this.label);

  static DocumentType fromValue(int value) {
    return DocumentType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => DocumentType.cedulaVerde,
    );
  }
}

class DocumentPhoto {
  final String? id;
  final String vehicleId;
  final DocumentType documentType;
  final String cloudinaryUrl;
  final String cloudinaryPublicId;
  final DateTime createdAt;

  DocumentPhoto({
    this.id,
    required this.vehicleId,
    required this.documentType,
    required this.cloudinaryUrl,
    required this.cloudinaryPublicId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  DocumentPhoto copyWith({
    String? id,
    String? vehicleId,
    DocumentType? documentType,
    String? cloudinaryUrl,
    String? cloudinaryPublicId,
    DateTime? createdAt,
  }) {
    return DocumentPhoto(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      documentType: documentType ?? this.documentType,
      cloudinaryUrl: cloudinaryUrl ?? this.cloudinaryUrl,
      cloudinaryPublicId: cloudinaryPublicId ?? this.cloudinaryPublicId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      if (id != null) 'id': id,
      'vehicle_id': vehicleId,
      'document_type': documentType.value,
      'cloudinary_url': cloudinaryUrl,
      'cloudinary_public_id': cloudinaryPublicId,
    };
  }

  factory DocumentPhoto.fromSupabase(Map<String, dynamic> map) {
    return DocumentPhoto(
      id: map['id'] as String,
      vehicleId: map['vehicle_id'] as String,
      documentType: DocumentType.fromValue(map['document_type'] as int),
      cloudinaryUrl: map['cloudinary_url'] as String,
      cloudinaryPublicId: map['cloudinary_public_id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicle_id': vehicleId,
      'document_type': documentType.value,
      'cloudinary_url': cloudinaryUrl,
      'cloudinary_public_id': cloudinaryPublicId,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory DocumentPhoto.fromMap(Map<String, dynamic> map) {
    return DocumentPhoto(
      id: map['id'] as String?,
      vehicleId: map['vehicle_id'] as String,
      documentType: DocumentType.fromValue(map['document_type'] as int),
      cloudinaryUrl: map['cloudinary_url'] as String,
      cloudinaryPublicId: map['cloudinary_public_id'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
