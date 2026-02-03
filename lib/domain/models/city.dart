import '../../core/utils/text_normalizer.dart';

/// Represents a city within a province.
/// Cities are part of the hierarchical location system: Province -> City -> Lugar
class City {
  final String? id;
  final int provinceId;
  final String name;
  final String nameNormalized;
  final DateTime createdAt;
  final DateTime updatedAt;

  City({
    this.id,
    required this.provinceId,
    required this.name,
    String? nameNormalized,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : nameNormalized = nameNormalized ?? TextNormalizer.normalize(name),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  City copyWith({
    String? id,
    int? provinceId,
    String? name,
    String? nameNormalized,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return City(
      id: id ?? this.id,
      provinceId: provinceId ?? this.provinceId,
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
      'province_id': provinceId,
      'name': name,
      'name_normalized': nameNormalized,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory City.fromMap(Map<String, dynamic> map) {
    return City(
      id: map['id'] as String?,
      provinceId: map['province_id'] as int,
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
      'province_id': provinceId,
      'name': name,
      'name_normalized': nameNormalized,
    };
  }

  factory City.fromSupabase(Map<String, dynamic> map) {
    return City(
      id: map['id'] as String,
      provinceId: map['province_id'] as int,
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
      'provinceId': provinceId,
      'name': name,
      'nameNormalized': nameNormalized,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      id: json['id'] as String?,
      provinceId: json['provinceId'] as int,
      name: json['name'] as String,
      nameNormalized: json['nameNormalized'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is City &&
        other.id == id &&
        other.provinceId == provinceId &&
        other.nameNormalized == nameNormalized;
  }

  @override
  int get hashCode => Object.hash(id, provinceId, nameNormalized);

  @override
  String toString() => 'City(id: $id, name: $name, provinceId: $provinceId)';
}
