import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_tone.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/chart_scale.dart';
import '../../core/utils/formatters.dart';
import '../../domain/expense_summary.dart';
import '../providers/expense_provider.dart';
import '../widgets/app_card.dart';
import '../widgets/app_notice.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_retry_view.dart';
import '../widgets/root_app_bar.dart';
import '../widgets/section_header.dart';
import '../widgets/vehicle_list_tile.dart';

/// Gastos de la flota (combustible y mantenimiento) en el período elegido:
/// total, evolución por mes y ranking por vehículo.
class ExpenseDashboardScreen extends ConsumerWidget {
  const ExpenseDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final months = ref.watch(expensePeriodProvider);
    final dashboardAsync = ref.watch(expenseDashboardProvider(months));
    return Scaffold(
      appBar: const RootAppBar(title: 'Gastos'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            Space.s5, Space.s2, Space.s5, Space.s10),
        children: [
          _PeriodSelector(
            months: months,
            onChanged: (value) =>
                ref.read(expensePeriodProvider.notifier).state = value,
          ),
          const Gap(Space.s5),
          ...dashboardAsync.when(
            loading: () => const [
              Padding(
                padding: EdgeInsets.all(Space.s10),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (_, _) => [
              ErrorRetryView(
                message: 'No se pudieron cargar los gastos',
                onRetry: () => ref.invalidate(expenseDashboardProvider(months)),
              ),
            ],
            data: (dashboard) => dashboard.grandTotal == 0
                ? [
                    Padding(
                      padding: const EdgeInsets.only(top: Space.s8),
                      child: EmptyState(
                        icon: Icons.payments_rounded,
                        title: 'Sin gastos en los últimos $months meses',
                        message:
                            'Cargá combustible o el costo de un mantenimiento.',
                      ),
                    ),
                  ]
                : _dashboardSections(context, dashboard, months),
          ),
        ],
      ),
    );
  }

  List<Widget> _dashboardSections(
      BuildContext context, ExpenseDashboard dashboard, int months) {
    final c = context.colors;
    final uncosted = dashboard.uncostedMaintenances;
    final withoutExpenses = dashboard.vehiclesWithoutExpenses;
    return [
      _TotalCard(dashboard: dashboard, months: months),
      if (uncosted > 0) ...[
        const Gap(Space.s3),
        AppNotice(
          tone: Tone.warning,
          icon: Icons.info_rounded,
          message: uncosted == 1
              ? '1 mantenimiento del período no tiene costo cargado: el total '
                  'puede ser mayor.'
              : '$uncosted mantenimientos del período no tienen costo cargado: '
                  'el total puede ser mayor.',
        ),
      ],
      const Gap(Space.s6),
      const SectionHeader('Por mes'),
      const Gap(Space.s2),
      _MonthlyChartCard(byMonth: dashboard.byMonth),
      const Gap(Space.s6),
      SectionHeader('Por vehículo', count: dashboard.byVehicle.length),
      const Gap(Space.s2),
      AppCard.list(
        children: [
          for (final expense in dashboard.byVehicle)
            _VehicleExpenseRow(expense: expense),
        ],
      ),
      if (withoutExpenses > 0) ...[
        const Gap(Space.s2),
        Text(
          withoutExpenses == 1
              ? '1 vehículo no tuvo gastos en el período.'
              : '$withoutExpenses vehículos no tuvieron gastos en el período.',
          style: AppText.caption.copyWith(color: c.textMuted),
        ),
      ],
    ];
  }
}

class _PeriodSelector extends StatelessWidget {
  final int months;
  final ValueChanged<int> onChanged;

  const _PeriodSelector({required this.months, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      showSelectedIcon: false,
      segments: [
        for (final period in expensePeriods)
          ButtonSegment(value: period, label: Text('$period meses')),
      ],
      selected: {months},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final ExpenseDashboard dashboard;
  final int months;

  const _TotalCard({required this.dashboard, required this.months});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gasto de los últimos $months meses',
            style: AppText.caption.copyWith(color: c.textMuted),
          ),
          const Gap(Space.s1),
          Text(
            AppFormats.money(dashboard.grandTotal),
            style: AppText.display.copyWith(color: c.text),
          ),
          const Gap(Space.s4),
          Row(
            children: [
              Expanded(
                child: _CategoryValue(
                  color: c.catFuel,
                  label: 'Combustible',
                  value: dashboard.fuelTotal,
                ),
              ),
              Expanded(
                child: _CategoryValue(
                  color: c.catMaintenance,
                  label: 'Mantenimiento',
                  value: dashboard.maintenanceTotal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Rótulo de una categoría de gasto con su color: el mismo que en el gráfico.
class _CategoryValue extends StatelessWidget {
  final Color color;
  final String label;
  final double? value;

  const _CategoryValue({required this.color, required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: Space.s1),
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: const SizedBox.square(dimension: 10),
          ),
        ),
        const Gap(Space.s2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppText.caption.copyWith(color: c.textMuted)),
              if (value != null)
                Text(
                  AppFormats.money(value!),
                  style: AppText.label.tabular.copyWith(color: c.text),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MonthlyChartCard extends StatelessWidget {
  final List<MonthlyExpense> byMonth;

  const _MonthlyChartCard({required this.byMonth});

  static final _monthFormat = DateFormat('MMM', 'es_AR');

  String _monthLabel(MonthlyExpense month) {
    final label =
        _monthFormat.format(DateTime(month.year, month.month)).replaceAll('.', '');
    return '${label[0].toUpperCase()}${label.substring(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final scale = ChartScale.of(
      0,
      byMonth.map((month) => month.total).fold<double>(0, math.max),
      fromZero: true,
    );
    // Hasta 6 meses rotulados, contados desde el último.
    final labelStep = (byMonth.length / 6).ceil();
    final labelStyle = AppText.caption.tabular.copyWith(color: c.textMuted);
    const hidden = AxisTitles(sideTitles: SideTitles(showTitles: false));
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _CategoryValue(color: c.catFuel, label: 'Combustible'),
              ),
              Expanded(
                child: _CategoryValue(
                    color: c.catMaintenance, label: 'Mantenimiento'),
              ),
            ],
          ),
          const Gap(Space.s4),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                minY: scale.min,
                maxY: scale.max,
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => c.surfaceRaised,
                    tooltipRoundedRadius: Radii.sm,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final month = byMonth[group.x];
                      return BarTooltipItem(
                        '${_monthLabel(month)}\n'
                        'Combustible ${AppFormats.money(month.fuelTotal)}\n'
                        'Mantenimiento ${AppFormats.money(month.maintenanceTotal)}',
                        AppText.caption.tabular.copyWith(color: c.text),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: hidden,
                  rightTitles: hidden,
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: scale.interval,
                      reservedSize: 64,
                      getTitlesWidget: (value, meta) {
                        final steps = (value - scale.min) / scale.interval;
                        if ((steps - steps.round()).abs() > 1e-6) {
                          return const SizedBox.shrink();
                        }
                        return Text(AppFormats.moneyCompact(value),
                            style: labelStyle);
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        final labeled = value == value.roundToDouble() &&
                            index >= 0 &&
                            index < byMonth.length &&
                            (byMonth.length - 1 - index) % labelStep == 0;
                        if (!labeled) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: Space.s2),
                          child: Text(_monthLabel(byMonth[index]),
                              style: labelStyle),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: scale.interval,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: c.border, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  for (final (index, month) in byMonth.indexed)
                    BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: month.total,
                          width: byMonth.length > 6 ? 12 : 20,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(Radii.sm),
                          ),
                          rodStackItems: [
                            BarChartRodStackItem(0, month.fuelTotal, c.catFuel),
                            BarChartRodStackItem(
                                month.fuelTotal, month.total, c.catMaintenance),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// La misma fila de vehículo que en el resto de la app, con el total a la
/// derecha y el desglose al pie.
class _VehicleExpenseRow extends StatelessWidget {
  final VehicleExpense expense;

  const _VehicleExpenseRow({required this.expense});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final vehicle = expense.vehicle;
    final total = Text(
      AppFormats.money(expense.total),
      style: AppText.label.tabular.copyWith(color: c.text),
    );
    final breakdown = Text(
      [
        if (expense.fuelTotal > 0)
          'Combustible ${AppFormats.money(expense.fuelTotal)}',
        if (expense.maintenanceTotal > 0)
          'Mantenimiento ${AppFormats.money(expense.maintenanceTotal)}',
      ].join(' · '),
      style: AppText.caption.tabular.copyWith(color: c.textMuted),
    );
    if (vehicle == null) {
      return Padding(
        padding: VehicleListTile.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(expense.label,
                      style: AppText.titleSm.copyWith(color: c.text)),
                ),
                total,
              ],
            ),
            breakdown,
          ],
        ),
      );
    }
    return VehicleListTile(
      vehicle: vehicle,
      trailing: total,
      showExpiryAlert: false,
      footer: breakdown,
      onTap: () => context.push('/vehicle/${expense.vehicleId}'),
    );
  }
}
