import '../../core/utils/text_normalizer.dart';

/// Represents a specific place (lugar) within a city.
/// Lugares are part of the hierarchical location system: Province -> City -> Lugar
class Lugar {
  final String? id;
  final String cityId;
  final String name;
  final String nameNormalized;
  final DateTime createdAt;
  final DateTime updatedAt;

  Lugar({
    this.id,
    required this.cityId,
    required this.name,
    String? nameNormalized,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : nameNormalized = nameNormalized ?? TextNormalizer.normalize(name),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Lugar copyWith({
    String? id,
    String? cityId,
    String? name,
    String? nameNormalized,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Lugar(
      id: id ?? this.id,
      cityId: cityId ?? this.cityId,
      name: name ?? this.name,
      nameNormalized: nameNormalized ?? (name != null ? TextNormalizer.normalize(name) : this.nameNormalized),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// For SQLite local cache
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'city_id': cityId,
      'name': name,
      'name_normalized': nameNormalized,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Lugar.fromMap(Map<String, dynamic> map) {
    return Lugar(
      id: map['id'] as String?,
      cityId: map['city_id'] as String,
      name: map['name'] as String,
      nameNormalized: map['name_normalized'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  /// For Supabase
  Map<String, dynamic> toSupabase() {
    return {
      if (id != null) 'id': id,
      'city_id': cityId,
      'name': name,
      'name_normalized': nameNormalized,
    };
  }

  factory Lugar.fromSupabase(Map<String, dynamic> map) {
    return Lugar(
      id: map['id'] as String,
      cityId: map['city_id'] as String,
      name: map['name'] as String,
      nameNormalized: map['name_normalized'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// For JSON export/import
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cityId': cityId,
      'name': name,
      'nameNormalized': nameNormalized,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Lugar.fromJson(Map<String, dynamic> json) {
    return Lugar(
      id: json['id'] as String?,
      cityId: json['cityId'] as String,
      name: json['name'] as String,
      nameNormalized: json['nameNormalized'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Lugar &&
        other.id == id &&
        other.cityId == cityId &&
        other.nameNormalized == nameNormalized;
  }

  @override
  int get hashCode => Object.hash(id, cityId, nameNormalized);

  @override
  String toString() => 'Lugar(id: $id, name: $name, cityId: $cityId)';
}
