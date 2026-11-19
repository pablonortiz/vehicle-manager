import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/chart_scale.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/fuel_charge.dart';
import 'app_card.dart';

/// Rendimiento (km/L) por tramo entre cargas consecutivas con odómetro. Los
/// tramos se calculan en orden de odómetro y se devuelven en orden de fecha;
/// descarta cargas sin odómetro y tramos con distancia o litros no positivos
/// (datos erróneos).
List<({DateTime date, double kmPerLiter})> consumptionPoints(
    List<FuelCharge> charges) {
  final withOdometer = charges.where((charge) => charge.odometer != null).toList()
    ..sort((charge, other) => charge.odometer!.compareTo(other.odometer!));
  final points = <({DateTime date, double kmPerLiter})>[];
  for (var i = 1; i < withOdometer.length; i++) {
    final previous = withOdometer[i - 1];
    final current = withOdometer[i];
    final km = current.odometer! - previous.odometer!;
    if (km > 0 && current.liters > 0) {
      points.add((date: current.date, kmPerLiter: km / current.liters));
    }
  }
  return points..sort((point, other) => point.date.compareTo(other.date));
}

/// Litros, precio por litro y consumo de los últimos meses, cada uno en su
/// card con título y unidad.
class FuelCharts extends StatelessWidget {
  final List<MonthlyFuelData> data;
  final List<FuelCharge> charges;

  const FuelCharts({super.key, required this.data, this.charges = const []});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty || data.every((month) => month.totalLiters == 0)) {
      return const SizedBox.shrink();
    }
    final consumption = consumptionPoints(charges);
    final hasPrices = data.any((month) => month.averagePricePerLiter > 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChartCard(
          title: 'Litros por mes',
          chart: _LitersBarChart(data: data),
        ),
        if (hasPrices) ...[
          const Gap(Space.s3),
          _ChartCard(
            title: 'Precio por litro',
            subtitle: 'Promedio de cada mes',
            chart: _PriceLineChart(data: data),
          ),
        ],
        if (consumption.isNotEmpty) ...[
          const Gap(Space.s3),
          _ChartCard(
            title: 'Consumo',
            subtitle: 'Kilómetros por litro entre cargas con odómetro',
            chart: _ConsumptionLineChart(points: consumption),
          ),
        ],
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget chart;

  const _ChartCard({required this.title, required this.chart, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.titleSm.copyWith(color: c.text)),
          if (subtitle != null)
            Text(subtitle!, style: AppText.caption.copyWith(color: c.textMuted)),
          const Gap(Space.s4),
          SizedBox(height: 160, child: chart),
        ],
      ),
    );
  }
}

/// Ejes comunes: a la izquierda solo las etiquetas que caen en el paso de la
/// escala (fl_chart pide también el mínimo y el máximo), abajo solo los
/// índices enteros (sin esto se repetían los meses).
FlTitlesData _axisTitles(
  BuildContext context, {
  required ChartScale scale,
  required String Function(double value) leftLabel,
  required String? Function(int index) bottomLabel,
  double leftReserved = 44,
}) {
  final style = AppText.caption.tabular.copyWith(color: context.colors.textMuted);
  final grow = _labelGrowth(context);
  const hidden = AxisTitles(sideTitles: SideTitles(showTitles: false));
  return FlTitlesData(
    topTitles: hidden,
    rightTitles: hidden,
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        interval: scale.interval,
        reservedSize: leftReserved * grow,
        getTitlesWidget: (value, meta) => _isOnStep(value, scale)
            ? Text(leftLabel(value), style: style, maxLines: 1, softWrap: false)
            : const SizedBox.shrink(),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        interval: 1,
        reservedSize: 28 * grow,
        getTitlesWidget: (value, meta) {
          final label =
              value == value.roundToDouble() ? bottomLabel(value.toInt()) : null;
          if (label == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: Space.s2),
            child: Text(label, style: style, maxLines: 1, softWrap: false),
          );
        },
      ),
    ),
  );
}

/// Aire a los costados de las líneas: sin esto, la primera y la última
/// etiqueta del eje quedan cortadas contra el borde.
const _edgePad = 0.3;

/// Cuánto crecen las etiquetas de eje con la letra del sistema, para que su
/// lugar crezca igual (si no, con letra grande "$ 2.300" se corta). Se mide
/// sobre el tamaño real de la etiqueta: el escalado de Android 14 no es
/// lineal y `scale(44)` trataría 44 como un tamaño de letra.
double _labelGrowth(BuildContext context) {
  final size = AppText.caption.fontSize!;
  return MediaQuery.textScalerOf(context).scale(size) / size;
}

bool _isOnStep(double value, ChartScale scale) {
  final steps = (value - scale.min) / scale.interval;
  return (steps - steps.round()).abs() < 1e-6;
}

FlGridData _grid(AppColors c, ChartScale scale) => FlGridData(
      drawVerticalLine: false,
      horizontalInterval: scale.interval,
      getDrawingHorizontalLine: (_) => FlLine(color: c.border, strokeWidth: 1),
    );

TextStyle _tooltipStyle(AppColors c) => AppText.label.tabular.copyWith(color: c.text);

class _LitersBarChart extends StatelessWidget {
  final List<MonthlyFuelData> data;

  const _LitersBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final scale = ChartScale.of(
      0,
      data.map((month) => month.totalLiters).reduce(math.max),
      fromZero: true,
    );
    return BarChart(
      BarChartData(
        minY: scale.min,
        maxY: scale.max,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => c.surfaceRaised,
            tooltipRoundedRadius: Radii.sm,
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              '${data[group.x].monthLabel}\n${AppFormats.liters(rod.toY)}',
              _tooltipStyle(c),
            ),
          ),
        ),
        titlesData: _axisTitles(
          context,
          scale: scale,
          leftLabel: AppFormats.integer,
          bottomLabel: (index) =>
              index < data.length ? data[index].monthLabel : null,
        ),
        gridData: _grid(c, scale),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (final (index, month) in data.indexed)
            BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: month.totalLiters,
                  color: c.catFuel,
                  width: 20,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(Radii.sm),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PriceLineChart extends StatelessWidget {
  final List<MonthlyFuelData> data;

  const _PriceLineChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final prices = [
      for (final month in data)
        if (month.averagePricePerLiter > 0) month.averagePricePerLiter,
    ];
    final scale = ChartScale.of(prices.reduce(math.min), prices.reduce(math.max));
    return LineChart(
      LineChartData(
        minX: -_edgePad,
        maxX: data.length - 1 + _edgePad,
        minY: scale.min,
        maxY: scale.max,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => c.surfaceRaised,
            tooltipRoundedRadius: Radii.sm,
            getTooltipItems: (spots) => [
              for (final spot in spots)
                LineTooltipItem(
                  '${data[spot.x.toInt()].monthLabel}\n'
                  '${AppFormats.pricePerLiter(spot.y)}',
                  _tooltipStyle(c),
                ),
            ],
          ),
        ),
        titlesData: _axisTitles(
          context,
          scale: scale,
          leftLabel: AppFormats.money,
          leftReserved: 60,
          bottomLabel: (index) =>
              index < data.length ? data[index].monthLabel : null,
        ),
        gridData: _grid(c, scale),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (final (index, month) in data.indexed)
                month.averagePricePerLiter > 0
                    ? FlSpot(index.toDouble(), month.averagePricePerLiter)
                    : FlSpot.nullSpot,
            ],
            color: c.accent,
            barWidth: 2,
            dotData: FlDotData(
              getDotPainter: (spot, percent, bar, index) =>
                  FlDotCirclePainter(radius: 3, color: c.accent, strokeWidth: 0),
            ),
            belowBarData: BarAreaData(show: true, color: c.accentSoft),
          ),
        ],
      ),
    );
  }
}

class _ConsumptionLineChart extends StatelessWidget {
  final List<({DateTime date, double kmPerLiter})> points;

  const _ConsumptionLineChart({required this.points});

  static final _dayMonth = DateFormat('d/M', 'es_AR');
  static final _kmPerLiter = NumberFormat('#,##0.#', 'es_AR');

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Los últimos 12 tramos, para no saturar el eje.
    final shown =
        points.length > 12 ? points.sublist(points.length - 12) : points;
    final values = shown.map((point) => point.kmPerLiter);
    final scale = ChartScale.of(values.reduce(math.min), values.reduce(math.max));
    // Hasta 6 fechas en el eje, contadas desde la última para que siempre se vea.
    final labelStep = (shown.length / 6).ceil();
    return LineChart(
      LineChartData(
        minX: -_edgePad,
        maxX: shown.length - 1 + _edgePad,
        minY: scale.min,
        maxY: scale.max,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => c.surfaceRaised,
            tooltipRoundedRadius: Radii.sm,
            getTooltipItems: (spots) => [
              for (final spot in spots)
                LineTooltipItem(
                  '${AppFormats.date(shown[spot.x.toInt()].date)}\n'
                  '${_kmPerLiter.format(spot.y)} km/L',
                  _tooltipStyle(c),
                ),
            ],
          ),
        ),
        titlesData: _axisTitles(
          context,
          scale: scale,
          leftLabel: _kmPerLiter.format,
          leftReserved: 36,
          bottomLabel: (index) => index < shown.length &&
                  (shown.length - 1 - index) % labelStep == 0
              ? _dayMonth.format(shown[index].date)
              : null,
        ),
        gridData: _grid(c, scale),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (final (index, point) in shown.indexed)
                FlSpot(index.toDouble(), point.kmPerLiter),
            ],
            color: c.success,
            barWidth: 2,
            dotData: FlDotData(
              getDotPainter: (spot, percent, bar, index) =>
                  FlDotCirclePainter(radius: 3, color: c.success, strokeWidth: 0),
            ),
            belowBarData: BarAreaData(show: true, color: c.successSoft),
          ),
        ],
      ),
    );
  }
}
