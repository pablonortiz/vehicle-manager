class VehicleHistory {
  final String? id;
  final String vehicleId;
  final String field;
  final String oldValue;
  final String newValue;
  final DateTime changedAt;

  VehicleHistory({
    this.id,
    required this.vehicleId,
    required this.field,
    required this.oldValue,
    required this.newValue,
    DateTime? changedAt,
  }) : changedAt = changedAt ?? DateTime.now();

  // Para SQLite local
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicle_id': vehicleId,
      'field': field,
      'old_value': oldValue,
      'new_value': newValue,
      'changed_at': changedAt.millisecondsSinceEpoch,
    };
  }

  factory VehicleHistory.fromMap(Map<String, dynamic> map) {
    return VehicleHistory(
      id: map['id'] as String?,
      vehicleId: map['vehicle_id'] as String,
      field: map['field'] as String,
      oldValue: map['old_value'] as String,
      newValue: map['new_value'] as String,
      changedAt: DateTime.fromMillisecondsSinceEpoch(map['changed_at'] as int),
    );
  }

  // Para Supabase
  Map<String, dynamic> toSupabase() {
    return {
      if (id != null) 'id': id,
      'vehicle_id': vehicleId,
      'field': field,
      'old_value': oldValue,
      'new_value': newValue,
    };
  }

  factory VehicleHistory.fromSupabase(Map<String, dynamic> map) {
    return VehicleHistory(
      id: map['id'] as String,
      vehicleId: map['vehicle_id'] as String,
      field: map['field'] as String,
      oldValue: map['old_value'] as String,
      newValue: map['new_value'] as String,
      changedAt: DateTime.parse(map['changed_at'] as String),
    );
  }

  // Para JSON export/import
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicleId': vehicleId,
      'field': field,
      'oldValue': oldValue,
      'newValue': newValue,
      'changedAt': changedAt.toIso8601String(),
    };
  }

  factory VehicleHistory.fromJson(Map<String, dynamic> json) {
    return VehicleHistory(
      id: json['id'] as String?,
      vehicleId: json['vehicleId'] as String,
      field: json['field'] as String,
      oldValue: json['oldValue'] as String,
      newValue: json['newValue'] as String,
      changedAt: DateTime.parse(json['changedAt'] as String),
    );
  }

  // Nombre legible del campo
  String get fieldLabel {
    switch (field) {
      case 'created':
        return 'Alta del vehículo';
      case 'plate':
        return 'Patente';
      case 'type':
        return 'Tipo';
      case 'brand':
        return 'Marca';
      case 'model':
        return 'Modelo';
      case 'year':
        return 'Año';
      case 'color':
        return 'Color';
      case 'km':
        return 'Kilometraje';
      case 'vtvExpiry':
        return 'Vencimiento de la VTV';
      case 'insuranceCompany':
        return 'Compañía de seguro';
      case 'insuranceExpiry':
        return 'Vencimiento del seguro';
      case 'fuelType':
        return 'Combustible';
      case 'status':
        return 'Estado';
      case 'provinceId':
        return 'Provincia';
      case 'city':
        return 'Ciudad';
      case 'lugar':
        return 'Lugar';
      case 'responsibleName':
        return 'Responsable';
      case 'responsiblePhone':
        return 'Teléfono';
      default:
        return field;
    }
  }
}
