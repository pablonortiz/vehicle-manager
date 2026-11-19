import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_vehiculos/core/utils/plate_format.dart';

void main() {
  test('Mercosur auto: AB 123 CD', () {
    expect(formatPlate('ae472kp'), 'AE 472 KP');
    expect(formatPlate('AE 472 KP'), 'AE 472 KP');
  });

  test('Mercosur moto: A 123 BCD', () {
    expect(formatPlate('A041TRB'), 'A 041 TRB');
  });

  test('anterior de auto: ABC 123', () {
    expect(formatPlate('oxn318'), 'OXN 318');
    expect(formatPlate('OXN-318'), 'OXN 318');
  });

  test('anterior de moto: 123 ABC', () {
    expect(formatPlate('123abc'), '123 ABC');
  });

  test('formato desconocido queda igual, en mayúsculas', () {
    expect(formatPlate(' e117829 '), 'E117829');
  });
}
