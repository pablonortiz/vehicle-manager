import 'package:flutter/material.dart';
import '../../core/constants/vehicle_constants.dart';

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
      updatedAt: updatedAt ?? DateTime.now(),
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
      type: VehicleType.values[map['type'] as int],
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
      fuelType: FuelType.values[map['fuel_type'] as int],
      status: VehicleStatus.values[map['status'] as int],
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
      'vtv_expiry': vtvExpiry?.toIso8601String(),
      'insurance_company': insuranceCompany,
      'insurance_expiry': insuranceExpiry?.toIso8601String(),
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
      type: VehicleType.values[map['type'] as int],
      brand: map['brand'] as String,
      model: map['model'] as String,
      year: map['year'] as int,
      color: Color(map['color'] as int),
      km: map['km'] as int,
      vtvExpiry: map['vtv_expiry'] != null
          ? DateTime.parse(map['vtv_expiry'] as String)
          : null,
      insuranceCompany: map['insurance_company'] as String?,
      insuranceExpiry: map['insurance_expiry'] != null
          ? DateTime.parse(map['insurance_expiry'] as String)
          : null,
      fuelType: FuelType.values[map['fuel_type'] as int],
      status: VehicleStatus.values[map['status'] as int],
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
      type: VehicleType.values.firstWhere((e) => e.name == json['type']),
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
      fuelType: FuelType.values.firstWhere((e) => e.name == json['fuelType']),
      status: VehicleStatus.values.firstWhere((e) => e.name == json['status']),
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

  // Verificar si el VTV está por vencer (30 días)
  bool get isVtvExpiringSoon {
    if (vtvExpiry == null) return false;
    final daysUntilExpiry = vtvExpiry!.difference(DateTime.now()).inDays;
    return daysUntilExpiry <= 30 && daysUntilExpiry >= 0;
  }

  bool get isVtvExpired {
    if (vtvExpiry == null) return false;
    return vtvExpiry!.isBefore(DateTime.now());
  }

  // Verificar si el seguro está por vencer (30 días)
  bool get isInsuranceExpiringSoon {
    if (insuranceExpiry == null) return false;
    final daysUntilExpiry = insuranceExpiry!.difference(DateTime.now()).inDays;
    return daysUntilExpiry <= 30 && daysUntilExpiry >= 0;
  }

  bool get isInsuranceExpired {
    if (insuranceExpiry == null) return false;
    return insuranceExpiry!.isBefore(DateTime.now());
  }

  String get displayName => '$brand $model';
}
