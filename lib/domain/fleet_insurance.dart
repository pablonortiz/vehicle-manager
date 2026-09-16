import 'package:intl/intl.dart';
import 'models/vehicle.dart';

/// Seguro a asignar en bloque a varios vehículos. Con [company] vacía cada
/// vehículo conserva su compañía y solo cambia el vencimiento.
class InsuranceAssignment {
  final String? company;
  final DateTime expiry;

  InsuranceAssignment({String? company, required DateTime expiry})
      : company = _blankToNull(company),
        expiry = DateTime(expiry.year, expiry.month, expiry.day);

  static final _dateFormat = DateFormat('dd/MM/yyyy');

  bool get changesCompany => company != null;

  /// "Nación Seguros · vence 28/09/2027" o "vence 28/09/2027".
  String get label => [
        if (company != null) company!,
        'vence ${_dateFormat.format(expiry)}',
      ].join(' · ');

  /// Copias de [vehicles] con el seguro aplicado, sin los que ya lo tienen
  /// (evita historial y sync inútiles).
  List<Vehicle> applyTo(Iterable<Vehicle> vehicles) => [
        for (final vehicle in vehicles)
          if (!alreadyHas(vehicle))
            vehicle.copyWith(insuranceCompany: company, insuranceExpiry: expiry),
      ];

  bool alreadyHas(Vehicle vehicle) {
    final currentExpiry = vehicle.insuranceExpiry;
    final sameExpiry = currentExpiry != null && _sameDay(currentExpiry, expiry);
    final sameCompany = company == null || vehicle.insuranceCompany == company;
    return sameExpiry && sameCompany;
  }

  static bool _sameDay(DateTime date, DateTime other) =>
      date.year == other.year &&
      date.month == other.month &&
      date.day == other.day;

  static String? _blankToNull(String? raw) {
    final trimmed = raw?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

/// Compañías de seguro cargadas en la flota, de la más repetida a la menos.
List<String> insuranceCompaniesByFrequency(Iterable<Vehicle> vehicles) {
  final counts = <String, int>{};
  for (final vehicle in vehicles) {
    final company = vehicle.insuranceCompany?.trim();
    if (company == null || company.isEmpty) continue;
    counts.update(company, (count) => count + 1, ifAbsent: () => 1);
  }
  return counts.keys.toList()
    ..sort((company, other) => counts[other]!.compareTo(counts[company]!));
}
