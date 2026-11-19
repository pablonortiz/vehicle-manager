import 'dart:math' as math;

/// Escala del eje Y de un gráfico con límites múltiplos de un intervalo
/// "redondo" (1, 2, 2,5 o 5 × 10ⁿ). Con límites alineados, las etiquetas del
/// eje caen siempre en el mismo paso y no se enciman ("323" sobre "300").
class ChartScale {
  final double min;
  final double max;
  final double interval;

  const ChartScale._(this.min, this.max, this.interval);

  /// [fromZero] arranca el eje en 0 (barras); si no, ajusta al rango de los
  /// datos (líneas de precio o consumo). Un rango vacío se abre un 10%.
  factory ChartScale.of(
    double lowest,
    double highest, {
    int ticks = 4,
    bool fromZero = false,
  }) {
    var low = fromZero ? 0.0 : lowest;
    var high = highest;
    if (high - low < 1e-9) {
      final pad = low.abs() * 0.1;
      low -= pad;
      high += pad == 0 ? 1 : pad;
    }
    final interval = _niceStep((high - low) / ticks);
    final min = math.max(
      (low / interval).floorToDouble() * interval,
      lowest >= 0 ? 0.0 : double.negativeInfinity,
    );
    final top = (high / interval).ceilToDouble() * interval;
    return ChartScale._(min, top, interval);
  }

  static double _niceStep(double rough) {
    final magnitude =
        math.pow(10, (math.log(rough) / math.ln10).floorToDouble()).toDouble();
    final fraction = rough / magnitude;
    final nice = fraction <= 1
        ? 1.0
        : fraction <= 2
            ? 2.0
            : fraction <= 2.5
                ? 2.5
                : fraction <= 5
                    ? 5.0
                    : 10.0;
    return nice * magnitude;
  }
}
