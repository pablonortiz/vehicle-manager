import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_vehiculos/core/utils/chart_scale.dart';

/// Los límites tienen que ser múltiplos exactos del intervalo.
void expectAligned(ChartScale scale) {
  final steps = (scale.max - scale.min) / scale.interval;
  expect((steps - steps.round()).abs(), lessThan(1e-9));
}

void main() {
  test('barras desde cero con un paso redondo', () {
    final scale = ChartScale.of(0, 323, fromZero: true);
    expect(scale.min, 0);
    expect(scale.interval, 100);
    expect(scale.max, 400);
    expectAligned(scale);
  });

  test('rango angosto de precios: etiquetas que no se enciman', () {
    final scale = ChartScale.of(2233, 2240);
    expect(scale.interval, 2);
    expect(scale.min, 2232);
    expect(scale.max, 2240);
    expectAligned(scale);
  });

  test('un solo valor se abre un 10% y queda alineado', () {
    final scale = ChartScale.of(1289, 1289);
    expect(scale.min, lessThan(1289));
    expect(scale.max, greaterThan(1289));
    expectAligned(scale);
  });

  test('valores positivos nunca bajan el eje de cero', () {
    final scale = ChartScale.of(0.4, 12.8);
    expect(scale.min, 0);
    expectAligned(scale);
  });
}
