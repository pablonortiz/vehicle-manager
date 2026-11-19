import 'package:flutter/painting.dart';

import '../../../core/constants/provinces.dart';
import '../../../core/constants/vehicle_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/plate_format.dart';

final _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}');

/// Un valor de Cambios tal como se lee. El registro guarda valores crudos: el
/// color como entero ARGB, la provincia por id, los km sin separador y las
/// fechas en ISO.
String historyDisplayValue(String field, String raw) {
  final value = raw.trim();
  if (value.isEmpty) return 'Sin cargar';
  switch (field) {
    case 'color':
      final argb = int.tryParse(value);
      return argb == null ? value : VehicleColors.getByColor(Color(argb)).name;
    case 'provinceId':
      final id = int.tryParse(value);
      return id == null ? value : ArgentinaProvinces.getById(id).name;
    case 'km':
      final km = int.tryParse(value);
      return km == null ? value : AppFormats.km(km);
    case 'plate':
      return formatPlate(value);
  }
  if (_isoDate.hasMatch(value)) {
    final date = DateTime.tryParse(value);
    if (date != null) return AppFormats.date(date);
  }
  return value;
}
