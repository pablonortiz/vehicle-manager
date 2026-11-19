import 'package:flutter/material.dart';
import '../expiry_status.dart';
import '../../core/constants/vehicle_constants.dart';
import '../../core/utils/civil_date.dart';
import '../../core/utils/enum_parser.dart';

class Vehicle {
  final String? id;
  final String plate;
  final VehicleType type;
  final String brand;
  final String model;
  final int year;
  final Color color;
  final int km;
  final DateTime? vtvExpiry;
  final String? insuranceCompany;
  final DateTime? insuranceExpiry;
  final FuelType fuelType;
  final VehicleStatus status;
  final int provinceId;
  final String city;
  final String? cityId;
  final String? lugarId;
  final String? lugar;
  final String responsibleName;
  final String responsiblePhone;
  final DateTime createdAt;
  final DateTime updatedAt;

  Vehicle({
    this.id,
    required this.plate,
    required this.type,
    required this.brand,
    required this.model,
    required this.year,
    required this.color,
    required this.km,
    this.vtvExpiry,
    this.insuranceCompany,
    this.insuranceExpiry,
    required this.fuelType,
    required this.status,
    required this.provinceId,
    required this.city,
    this.cityId,
    this.lugarId,
    this.lugar,
    required this.responsibleName,
    required this.responsiblePhone,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Vehicle copyWith({
    String? id,
    String? plate,
    VehicleType? type,
    String? brand,
    String? model,
    int? year,
    Color? color,
    int? km,
    DateTime? vtvExpiry,
    String? insuranceCompany,
    DateTime? insuranceExpiry,
    FuelType? fuelType,
    VehicleStatus? status,
    int? provinceId,
    String? city,
    String? cityId,
    String? lugarId,
    String? lugar,
    String? responsibleName,
    String? responsiblePhone,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Vehicle(
      id: id ?? this.id,
      plate: plate ?? this.plate,
      type: type ?? this.type,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      color: color ?? this.color,
      km: km ?? this.km,
      vtvExpiry: vtvExpiry ?? this.vtvExpiry,
      insuranceCompany: insuranceCompany ?? this.insuranceCompany,
      insuranceExpiry: insuranceExpiry ?? this.insuranceExpiry,
      fuelType: fuelType ?? this.fuelType,
      status: status ?? this.status,
      provinceId: provinceId ?? this.provinceId,
      city: city ?? this.city,
      cityId: cityId ?? this.cityId,
      lugarId: lugarId ?? this.lugarId,
      lugar: lugar ?? this.lugar,
      responsibleName: responsibleName ?? this.responsibleName,
      responsiblePhone: responsiblePhone ?? this.responsiblePhone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Para SQLite local (cache)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'plate': plate,
      'type': type.index,
      'brand': brand,
      'model': model,
      'year': year,
      'color': color.toARGB32(),
      'km': km,
      'vtv_expiry': vtvExpiry?.millisecondsSinceEpoch,
      'insurance_company': insuranceCompany,
      'insurance_expiry': insuranceExpiry?.millisecondsSinceEpoch,
      'fuel_type': fuelType.index,
      'status': status.index,
      'province_id': provinceId,
      'city': city,
      'city_id': cityId,
      'lugar_id': lugarId,
      'lugar': lugar,
      'responsible_name': responsibleName,
      'responsible_phone': responsiblePhone,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      id: map['id'] as String?,
      plate: map['plate'] as String,
      type: enumFromIndex(VehicleType.values, map['type'], VehicleType.car),
      brand: map['brand'] as String,
      model: map['model'] as String,
      year: map['year'] as int,
      color: Color(map['color'] as int),
      km: map['km'] as int,
      vtvExpiry: map['vtv_expiry'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['vtv_expiry'] as int)
          : null,
      insuranceCompany: map['insurance_company'] as String?,
      insuranceExpiry: map['insurance_expiry'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['insurance_expiry'] as int)
          : null,
      fuelType: enumFromIndex(FuelType.values, map['fuel_type'], FuelType.nafta),
      status:
          enumFromIndex(VehicleStatus.values, map['status'], VehicleStatus.available),
      provinceId: map['province_id'] as int,
      city: map['city'] as String,
      cityId: map['city_id'] as String?,
      lugarId: map['lugar_id'] as String?,
      lugar: map['lugar'] as String?,
      responsibleName: map['responsible_name'] as String,
      responsiblePhone: map['responsible_phone'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  // Para Supabase
  Map<String, dynamic> toSupabase() {
    return {
      if (id != null) 'id': id,
      'plate': plate,
      'type': type.index,
      'brand': brand,
      'model': model,
      'year': year,
      'color': color.toARGB32(),
      'km': km,
      'vtv_expiry': CivilDate.toSupabaseOrNull(vtvExpiry),
      'insurance_company': insuranceCompany,
      'insurance_expiry': CivilDate.toSupabaseOrNull(insuranceExpiry),
      'fuel_type': fuelType.index,
      'status': status.index,
      'province_id': provinceId,
      'city': city,
      'city_id': cityId,
      'lugar_id': lugarId,
      'lugar': lugar,
      'responsible_name': responsibleName,
      'responsible_phone': responsiblePhone,
    };
  }

  factory Vehicle.fromSupabase(Map<String, dynamic> map) {
    return Vehicle(
      id: map['id'] as String,
      plate: map['plate'] as String,
      type: enumFromIndex(VehicleType.values, map['type'], VehicleType.car),
      brand: map['brand'] as String,
      model: map['model'] as String,
      year: map['year'] as int,
      color: Color(map['color'] as int),
      km: map['km'] as int,
      vtvExpiry: CivilDate.fromSupabaseOrNull(map['vtv_expiry']),
      insuranceCompany: map['insurance_company'] as String?,
      insuranceExpiry: CivilDate.fromSupabaseOrNull(map['insurance_expiry']),
      fuelType: enumFromIndex(FuelType.values, map['fuel_type'], FuelType.nafta),
      status:
          enumFromIndex(VehicleStatus.values, map['status'], VehicleStatus.available),
      provinceId: map['province_id'] as int,
      city: map['city'] as String,
      cityId: map['city_id'] as String?,
      lugarId: map['lugar_id'] as String?,
      lugar: map['lugar'] as String?,
      responsibleName: map['responsible_name'] as String,
      responsiblePhone: map['responsible_phone'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  // Para JSON export/import
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'plate': plate,
      'type': type.name,
      'brand': brand,
      'model': model,
      'year': year,
      'color': color.toARGB32(),
      'km': km,
      'vtvExpiry': vtvExpiry?.toIso8601String(),
      'insuranceCompany': insuranceCompany,
      'insuranceExpiry': insuranceExpiry?.toIso8601String(),
      'fuelType': fuelType.name,
      'status': status.name,
      'provinceId': provinceId,
      'city': city,
      'cityId': cityId,
      'lugarId': lugarId,
      'lugar': lugar,
      'responsibleName': responsibleName,
      'responsiblePhone': responsiblePhone,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as String?,
      plate: json['plate'] as String,
      type: enumFromName(VehicleType.values, json['type'], VehicleType.car),
      brand: json['brand'] as String,
      model: json['model'] as String,
      year: json['year'] as int,
      color: Color(json['color'] as int),
      km: json['km'] as int,
      vtvExpiry: json['vtvExpiry'] != null
          ? DateTime.parse(json['vtvExpiry'] as String)
          : null,
      insuranceCompany: json['insuranceCompany'] as String?,
      insuranceExpiry: json['insuranceExpiry'] != null
          ? DateTime.parse(json['insuranceExpiry'] as String)
          : null,
      fuelType: enumFromName(FuelType.values, json['fuelType'], FuelType.nafta),
      status:
          enumFromName(VehicleStatus.values, json['status'], VehicleStatus.available),
      provinceId: json['provinceId'] as int,
      city: json['city'] as String,
      cityId: json['cityId'] as String?,
      lugarId: json['lugarId'] as String?,
      lugar: json['lugar'] as String?,
      responsibleName: json['responsibleName'] as String,
      responsiblePhone: json['responsiblePhone'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Documentos vencidos o por vencer (ventana 30 días), más urgente primero.
  List<ExpiringDocument> get expiringDocuments {
    final docs = <ExpiringDocument>[
      if (vtvStatus.needsAttention) ExpiringDocument('VTV', vtvExpiry!),
      if (insuranceStatus.needsAttention)
        ExpiringDocument('Seguro', insuranceExpiry!),
    ];
    docs.sort((a, b) => a.expiry.compareTo(b.expiry));
    return docs;
  }

  ExpiryStatus get vtvStatus => ExpiryStatus.of(vtvExpiry);
  ExpiryStatus get insuranceStatus => ExpiryStatus.of(insuranceExpiry);

  bool get isVtvExpiringSoon => vtvStatus.isExpiringSoon;
  bool get isVtvExpired => vtvStatus.isExpired;
  bool get isInsuranceExpiringSoon => insuranceStatus.isExpiringSoon;
  bool get isInsuranceExpired => insuranceStatus.isExpired;

  String get displayName => '$brand $model';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Vehicle &&
        other.id == id &&
        other.plate == plate &&
        other.type == type &&
        other.brand == brand &&
        other.model == model &&
        other.year == year &&
        other.color == color &&
        other.km == km &&
        other.vtvExpiry == vtvExpiry &&
        other.insuranceCompany == insuranceCompany &&
        other.insuranceExpiry == insuranceExpiry &&
        other.fuelType == fuelType &&
        other.status == status &&
        other.provinceId == provinceId &&
        other.city == city &&
        other.cityId == cityId &&
        other.lugarId == lugarId &&
        other.lugar == lugar &&
        other.responsibleName == responsibleName &&
        other.responsiblePhone == responsiblePhone &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        plate,
        type,
        brand,
        model,
        year,
        color,
        km,
        vtvExpiry,
        insuranceCompany,
        insuranceExpiry,
        fuelType,
        status,
        provinceId,
        city,
        cityId,
        lugarId,
        lugar,
        responsibleName,
        responsiblePhone,
        createdAt,
        updatedAt,
      ]);
}

/// Un documento del vehículo vencido o próximo a vencer.
class ExpiringDocument {
  final String label;
  final DateTime expiry;

  const ExpiringDocument(this.label, this.expiry);

  ExpiryStatus get status => ExpiryStatus.of(expiry);

  bool get expired => status.isExpired;

  /// Días hasta el vencimiento (negativo si ya venció).
  int get daysLeft => status.days;
}
