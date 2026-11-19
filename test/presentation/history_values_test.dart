import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_vehiculos/core/theme/app_colors.dart';
import 'package:gestor_vehiculos/presentation/screens/vehicle_history/history_values.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es_AR'));

  test('color guardado como ARGB se muestra por nombre', () {
    expect(historyDisplayValue('color', '${PaintColors.rojo.toARGB32()}'), 'Rojo');
  });

  test('provincia por id, km con separador y patente con su formato', () {
    expect(historyDisplayValue('provinceId', '1'), 'Buenos Aires');
    expect(historyDisplayValue('km', '84300'), '84.300 km');
    expect(historyDisplayValue('plate', 'ae472kp'), 'AE 472 KP');
  });

  test('fechas ISO como fecha de lectura', () {
    expect(historyDisplayValue('vtvExpiry', '2026-12-12T00:00:00.000'),
        '12 dic 2026');
  });

  test('vacío y texto libre', () {
    expect(historyDisplayValue('brand', '  '), 'Sin cargar');
    expect(historyDisplayValue('insuranceCompany', 'Sin compañía'), 'Sin compañía');
  });
}
