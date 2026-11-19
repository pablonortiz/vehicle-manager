import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_vehiculos/core/utils/formatters.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es_AR'));

  test('fecha de lectura sin punto en el mes', () {
    expect(AppFormats.date(DateTime(2026, 12, 12)), '12 dic 2026');
    expect(AppFormats.date(DateTime(2026, 6, 3)), '3 jun 2026');
  });

  test('fecha con hora: el año solo si no es el actual', () {
    final now = DateTime(2026, 12, 20);
    expect(AppFormats.dateTime(DateTime(2026, 12, 12, 14, 30), now: now),
        '12 dic, 14:30');
    expect(AppFormats.dateTime(DateTime(2025, 3, 2, 9, 5), now: now),
        '2 mar 2025, 09:05');
  });

  test('moneda con espacio no separable y separador de miles', () {
    expect(AppFormats.money(1284500), '\$\u00A01.284.500');
  });

  test('precio por litro con dos decimales', () {
    expect(AppFormats.pricePerLiter(1289.5), '\$\u00A01.289,50');
  });
}
