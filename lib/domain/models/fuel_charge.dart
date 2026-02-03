class FuelCharge {
  final String? id;
  final String vehicleId;
  final DateTime date;
  final double liters;
  final double price;
  final double? pricePerLiter;
  final int? odometer;
  final String? receiptPhotoUrl;
  final String? receiptPhotoPublicId;
  final String? displayPhotoUrl;
  final String? displayPhotoPublicId;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  FuelCharge({
    this.id,
    required this.vehicleId,
    required this.date,
    required this.liters,
    required this.price,
    this.pricePerLiter,
    this.odometer,
    this.receiptPhotoUrl,
    this.receiptPhotoPublicId,
    this.displayPhotoUrl,
    this.displayPhotoPublicId,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  double get calculatedPricePerLiter =>
      liters > 0 ? price / liters : 0;

  FuelCharge copyWith({
    String? id,
    String? vehicleId,
    DateTime? date,
    double? liters,
    double? price,
    double? pricePerLiter,
    int? odometer,
    String? receiptPhotoUrl,
    String? receiptPhotoPublicId,
    String? displayPhotoUrl,
    String? displayPhotoPublicId,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FuelCharge(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      date: date ?? this.date,
      liters: liters ?? this.liters,
      price: price ?? this.price,
      pricePerLiter: pricePerLiter ?? this.pricePerLiter,
      odometer: odometer ?? this.odometer,
      receiptPhotoUrl: receiptPhotoUrl ?? this.receiptPhotoUrl,
      receiptPhotoPublicId: receiptPhotoPublicId ?? this.receiptPhotoPublicId,
      displayPhotoUrl: displayPhotoUrl ?? this.displayPhotoUrl,
      displayPhotoPublicId: displayPhotoPublicId ?? this.displayPhotoPublicId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      if (id != null) 'id': id,
      'vehicle_id': vehicleId,
      'date': date.toIso8601String(),
      'liters': liters,
      'price': price,
      'price_per_liter': pricePerLiter ?? calculatedPricePerLiter,
      'odometer': odometer,
      'receipt_photo_url': receiptPhotoUrl,
      'receipt_photo_public_id': receiptPhotoPublicId,
      'display_photo_url': displayPhotoUrl,
      'display_photo_public_id': displayPhotoPublicId,
      'notes': notes,
    };
  }

  factory FuelCharge.fromSupabase(Map<String, dynamic> map) {
    return FuelCharge(
      id: map['id'] as String,
      vehicleId: map['vehicle_id'] as String,
      date: DateTime.parse(map['date'] as String),
      liters: (map['liters'] as num).toDouble(),
      price: (map['price'] as num).toDouble(),
      pricePerLiter: map['price_per_liter'] != null
          ? (map['price_per_liter'] as num).toDouble()
          : null,
      odometer: map['odometer'] as int?,
      receiptPhotoUrl: map['receipt_photo_url'] as String?,
      receiptPhotoPublicId: map['receipt_photo_public_id'] as String?,
      displayPhotoUrl: map['display_photo_url'] as String?,
      displayPhotoPublicId: map['display_photo_public_id'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicle_id': vehicleId,
      'date': date.millisecondsSinceEpoch,
      'liters': liters,
      'price': price,
      'price_per_liter': pricePerLiter ?? calculatedPricePerLiter,
      'odometer': odometer,
      'receipt_photo_url': receiptPhotoUrl,
      'receipt_photo_public_id': receiptPhotoPublicId,
      'display_photo_url': displayPhotoUrl,
      'display_photo_public_id': displayPhotoPublicId,
      'notes': notes,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory FuelCharge.fromMap(Map<String, dynamic> map) {
    return FuelCharge(
      id: map['id'] as String?,
      vehicleId: map['vehicle_id'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      liters: (map['liters'] as num).toDouble(),
      price: (map['price'] as num).toDouble(),
      pricePerLiter: map['price_per_liter'] != null
          ? (map['price_per_liter'] as num).toDouble()
          : null,
      odometer: map['odometer'] as int?,
      receiptPhotoUrl: map['receipt_photo_url'] as String?,
      receiptPhotoPublicId: map['receipt_photo_public_id'] as String?,
      displayPhotoUrl: map['display_photo_url'] as String?,
      displayPhotoPublicId: map['display_photo_public_id'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }
}

class FuelChargeSummary {
  final double totalLiters;
  final double totalPrice;
  final int chargeCount;
  final int year;
  final int month;

  FuelChargeSummary({
    required this.totalLiters,
    required this.totalPrice,
    required this.chargeCount,
    required this.year,
    required this.month,
  });

  double get averagePricePerLiter =>
      totalLiters > 0 ? totalPrice / totalLiters : 0;

  factory FuelChargeSummary.empty(int year, int month) {
    return FuelChargeSummary(
      totalLiters: 0,
      totalPrice: 0,
      chargeCount: 0,
      year: year,
      month: month,
    );
  }
}

class MonthlyFuelData {
  final int year;
  final int month;
  final double totalLiters;
  final double totalPrice;
  final double averagePricePerLiter;

  MonthlyFuelData({
    required this.year,
    required this.month,
    required this.totalLiters,
    required this.totalPrice,
    required this.averagePricePerLiter,
  });

  String get monthLabel {
    const months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return months[month - 1];
  }
}
