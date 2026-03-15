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
  final bool receiptIsPdf;
  final String? receiptFileName;
  final String? displayPhotoUrl;
  final String? displayPhotoPublicId;
  final bool displayIsPdf;
  final String? displayFileName;
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
    this.receiptIsPdf = false,
    this.receiptFileName,
    this.displayPhotoUrl,
    this.displayPhotoPublicId,
    this.displayIsPdf = false,
    this.displayFileName,
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
    bool? receiptIsPdf,
    String? receiptFileName,
    String? displayPhotoUrl,
    String? displayPhotoPublicId,
    bool? displayIsPdf,
    String? displayFileName,
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
      receiptIsPdf: receiptIsPdf ?? this.receiptIsPdf,
      receiptFileName: receiptFileName ?? this.receiptFileName,
      displayPhotoUrl: displayPhotoUrl ?? this.displayPhotoUrl,
      displayPhotoPublicId: displayPhotoPublicId ?? this.displayPhotoPublicId,
      displayIsPdf: displayIsPdf ?? this.displayIsPdf,
      displayFileName: displayFileName ?? this.displayFileName,
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
      'receipt_is_pdf': receiptIsPdf,
      'receipt_file_name': receiptFileName,
      'display_photo_url': displayPhotoUrl,
      'display_photo_public_id': displayPhotoPublicId,
      'display_is_pdf': displayIsPdf,
      'display_file_name': displayFileName,
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
      receiptIsPdf: map['receipt_is_pdf'] as bool? ?? false,
      receiptFileName: map['receipt_file_name'] as String?,
      displayPhotoUrl: map['display_photo_url'] as String?,
      displayPhotoPublicId: map['display_photo_public_id'] as String?,
      displayIsPdf: map['display_is_pdf'] as bool? ?? false,
      displayFileName: map['display_file_name'] as String?,
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
      'receipt_is_pdf': receiptIsPdf ? 1 : 0,
      'receipt_file_name': receiptFileName,
      'display_photo_url': displayPhotoUrl,
      'display_photo_public_id': displayPhotoPublicId,
      'display_is_pdf': displayIsPdf ? 1 : 0,
      'display_file_name': displayFileName,
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
      receiptIsPdf: (map['receipt_is_pdf'] as int?) == 1,
      receiptFileName: map['receipt_file_name'] as String?,
      displayPhotoUrl: map['display_photo_url'] as String?,
      displayPhotoPublicId: map['display_photo_public_id'] as String?,
      displayIsPdf: (map['display_is_pdf'] as int?) == 1,
      displayFileName: map['display_file_name'] as String?,
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
