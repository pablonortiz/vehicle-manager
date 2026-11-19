import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/expense_summary.dart';
import '../providers/expense_provider.dart';
import '../widgets/error_retry_view.dart';
import '../widgets/root_app_bar.dart';

class ExpenseDashboardScreen extends ConsumerWidget {
  const ExpenseDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(expenseDashboardProvider);

    return Scaffold(
      appBar: const RootAppBar(title: 'Gastos'),
      body: SafeArea(
        child: dashboardAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorRetryView(
            message: 'No se pudieron cargar los gastos',
            onRetry: () => ref.invalidate(expenseDashboardProvider),
          ),
          data: (dashboard) {
            if (dashboard.grandTotal == 0) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Todavía no hay gastos en los últimos 6 meses.\n'
                    'Cargá combustible o agregá el costo de un mantenimiento.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _TotalCard(dashboard: dashboard),
                if (dashboard.uncostedMaintenances > 0) ...[
                  const SizedBox(height: 12),
                  _UncostedNotice(count: dashboard.uncostedMaintenances),
                ],
                const SizedBox(height: 24),
                _MonthlyChart(byMonth: dashboard.byMonth),
                const SizedBox(height: 24),
                _VehicleRanking(byVehicle: dashboard.byVehicle),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Aviso de que hay mantenimientos sin costo cargado (totales incompletos).
class _UncostedNotice extends StatelessWidget {
  final int count;

  const _UncostedNotice({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppTheme.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              count == 1
                  ? '1 mantenimiento del período no tiene costo cargado'
                  : '$count mantenimientos del período no tienen costo cargado',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final ExpenseDashboard dashboard;

  const _TotalCard({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentPrimary.withValues(alpha: 0.15),
            AppTheme.accentDark.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentPrimary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Gasto últimos 6 meses',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Text(
            AppFormats.money(dashboard.grandTotal),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _legend(AppTheme.accentPrimary, 'Combustible', dashboard.fuelTotal),
              const SizedBox(width: 24),
              _legend(AppTheme.warning, 'Mantenimiento', dashboard.maintenanceTotal),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label, double value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            Text(AppFormats.money(value),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          ],
        ),
      ],
    );
  }
}

class _MonthlyChart extends StatelessWidget {
  final List<MonthlyExpense> byMonth;

  const _MonthlyChart({required this.byMonth});

  @override
  Widget build(BuildContext context) {
    final maxTotal = byMonth.map((m) => m.total).fold<double>(0, (a, b) => a > b ? a : b);
    final maxY = (maxTotal * 1.2).ceilToDouble();
    final monthFormat = DateFormat('MMM', 'es');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Gasto por mes',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY > 0 ? maxY : 1,
                minY: 0,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppTheme.surfaceLight,
                    getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                      AppFormats.money(rod.toY),
                      const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i >= 0 && i < byMonth.length) {
                          final m = byMonth[i];
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              monthFormat.format(DateTime(m.year, m.month)),
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: byMonth.asMap().entries.map((entry) {
                  final m = entry.value;
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: m.total,
                        width: 18,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                        rodStackItems: [
                          BarChartRodStackItem(0, m.fuelTotal, AppTheme.accentPrimary),
                          BarChartRodStackItem(m.fuelTotal, m.total, AppTheme.warning),
                        ],
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleRanking extends StatelessWidget {
  final List<VehicleExpense> byVehicle;

  const _VehicleRanking({required this.byVehicle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Por vehículo',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const SizedBox(height: 12),
        ...byVehicle.map((e) => GestureDetector(
              onTap: e.vehicleId.isEmpty
                  ? null
                  : () => context.push('/vehicle/${e.vehicleId}'),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.label,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                          const SizedBox(height: 2),
                          Text(
                            '${AppFormats.money(e.fuelTotal)} comb. · ${AppFormats.money(e.maintenanceTotal)} mant.',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      AppFormats.money(e.total),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.accentPrimary),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right,
                        size: 18, color: AppTheme.textSecondary),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}
