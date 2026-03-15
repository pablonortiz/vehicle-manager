class VehicleNote {
  final String? id;
  final String vehicleId;
  final String detail;
  final List<NotePhoto> photos;
  final DateTime createdAt;
  final DateTime updatedAt;

  VehicleNote({
    this.id,
    required this.vehicleId,
    required this.detail,
    this.photos = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  VehicleNote copyWith({
    String? id,
    String? vehicleId,
    String? detail,
    List<NotePhoto>? photos,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VehicleNote(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      detail: detail ?? this.detail,
      photos: photos ?? this.photos,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      if (id != null) 'id': id,
      'vehicle_id': vehicleId,
      'detail': detail,
    };
  }

  factory VehicleNote.fromSupabase(Map<String, dynamic> map, {List<NotePhoto>? photos}) {
    return VehicleNote(
      id: map['id'] as String,
      vehicleId: map['vehicle_id'] as String,
      detail: map['detail'] as String,
      photos: photos ?? [],
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicle_id': vehicleId,
      'detail': detail,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory VehicleNote.fromMap(Map<String, dynamic> map) {
    return VehicleNote(
      id: map['id'] as String?,
      vehicleId: map['vehicle_id'] as String,
      detail: map['detail'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }
}

class NotePhoto {
  final String? id;
  final String noteId;
  final String cloudinaryUrl;
  final String cloudinaryPublicId;
  final bool isPdf;
  final String? fileName;
  final DateTime createdAt;

  NotePhoto({
    this.id,
    required this.noteId,
    required this.cloudinaryUrl,
    required this.cloudinaryPublicId,
    this.isPdf = false,
    this.fileName,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toSupabase() {
    return {
      if (id != null) 'id': id,
      'note_id': noteId,
      'cloudinary_url': cloudinaryUrl,
      'cloudinary_public_id': cloudinaryPublicId,
      'is_pdf': isPdf,
      'file_name': fileName,
    };
  }

  factory NotePhoto.fromSupabase(Map<String, dynamic> map) {
    return NotePhoto(
      id: map['id'] as String,
      noteId: map['note_id'] as String,
      cloudinaryUrl: map['cloudinary_url'] as String,
      cloudinaryPublicId: map['cloudinary_public_id'] as String,
      isPdf: map['is_pdf'] as bool? ?? false,
      fileName: map['file_name'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'note_id': noteId,
      'cloudinary_url': cloudinaryUrl,
      'cloudinary_public_id': cloudinaryPublicId,
      'is_pdf': isPdf ? 1 : 0,
      'file_name': fileName,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory NotePhoto.fromMap(Map<String, dynamic> map) {
    return NotePhoto(
      id: map['id'] as String?,
      noteId: map['note_id'] as String,
      cloudinaryUrl: map['cloudinary_url'] as String,
      cloudinaryPublicId: map['cloudinary_public_id'] as String,
      isPdf: (map['is_pdf'] as int?) == 1,
      fileName: map['file_name'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
