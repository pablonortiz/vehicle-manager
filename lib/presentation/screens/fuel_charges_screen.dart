import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/fuel_charge.dart';
import '../providers/fuel_charge_provider.dart';
import '../widgets/app_card.dart';
import '../widgets/app_notice.dart';
import '../widgets/app_snack.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_retry_view.dart';
import '../widgets/fuel_charge_form_sheet.dart';
import '../widgets/fuel_charge_row.dart';
import '../widgets/fuel_charts.dart';
import '../widgets/fuel_month_summary.dart';
import '../widgets/month_navigator.dart';
import '../widgets/section_header.dart';

/// Cargas de combustible de un vehículo, mes por mes: el resumen del mes, sus
/// cargas y, a pedido, los gráficos de los últimos seis meses.
class FuelChargesScreen extends ConsumerStatefulWidget {
  final String vehicleId;

  const FuelChargesScreen({super.key, required this.vehicleId});

  @override
  ConsumerState<FuelChargesScreen> createState() => _FuelChargesScreenState();
}

class _FuelChargesScreenState extends ConsumerState<FuelChargesScreen> {
  static const _chartMonths = 6;

  bool _showCharts = false;
  // Borrado diferido: ocultas mientras corre el snackbar de "Deshacer".
  final Set<String> _pendingDeleteIds = {};

  ChartDataParams get _chartParams =>
      ChartDataParams(vehicleId: widget.vehicleId, months: _chartMonths);

  MonthlyFuelParams _monthParams(SelectedMonthState month) => MonthlyFuelParams(
        vehicleId: widget.vehicleId,
        year: month.year,
        month: month.month,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _jumpToLatestMonthWithData());
  }

  /// Si el mes actual no tiene cargas, arranca en el último mes que sí tenga,
  /// en vez de mostrar un mes vacío.
  Future<void> _jumpToLatestMonthWithData() async {
    final charges =
        await ref.read(fuelChargesByVehicleProvider(widget.vehicleId).future);
    if (!mounted || charges.isEmpty) return;

    final selected = ref.read(selectedMonthProvider(widget.vehicleId));
    final now = DateTime.now();
    final userNavigated =
        selected.year != now.year || selected.month != now.month;
    if (userNavigated) return;

    final hasChargesInSelected = charges.any((charge) =>
        charge.date.year == selected.year &&
        charge.date.month == selected.month);
    if (hasChargesInSelected) return;

    final latest = charges
        .map((charge) => charge.date)
        .reduce((date, other) => date.isAfter(other) ? date : other);
    ref.read(selectedMonthProvider(widget.vehicleId).notifier).state =
        SelectedMonthState(year: latest.year, month: latest.month);
  }

  void _refreshCharges() {
    final params =
        _monthParams(ref.read(selectedMonthProvider(widget.vehicleId)));
    ref.invalidate(fuelChargesByMonthProvider(params));
    ref.invalidate(fuelChargeSummaryProvider(params));
    ref.invalidate(fuelChartDataProvider(_chartParams));
    ref.invalidate(fuelChargesByVehicleProvider(widget.vehicleId));
    ref.invalidate(recentFuelChargesProvider(widget.vehicleId));
  }

  void _selectMonth(SelectedMonthState month) =>
      ref.read(selectedMonthProvider(widget.vehicleId).notifier).state = month;

  /// "noviembre", o "noviembre de 2025" si no es el año actual.
  static String _monthName(SelectedMonthState month) {
    final date = DateTime(month.year, month.month);
    final pattern = month.year == DateTime.now().year ? 'MMMM' : "MMMM 'de' y";
    return DateFormat(pattern, 'es_AR').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final selectedMonth = ref.watch(selectedMonthProvider(widget.vehicleId));
    final params = _monthParams(selectedMonth);
    final monthName = _monthName(selectedMonth);
    final summaryAsync = ref.watch(fuelChargeSummaryProvider(params));
    final chargesAsync = ref.watch(fuelChargesByMonthProvider(params));
    final hasSummary = (summaryAsync.valueOrNull?.chargeCount ?? 0) > 0 ||
        summaryAsync.hasError;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cargas de combustible'),
        actions: [
          IconButton(
            tooltip: _showCharts ? 'Ocultar gráficos' : 'Ver gráficos',
            isSelected: _showCharts,
            onPressed: () => setState(() => _showCharts = !_showCharts),
            icon: const Icon(Icons.bar_chart_rounded),
            selectedIcon: Icon(Icons.bar_chart_rounded, color: c.accent),
          ),
          const Gap(Space.s1),
        ],
      ),
      body: Column(
        children: [
          MonthNavigator(
            selectedMonth: selectedMonth,
            onPreviousMonth: () => _selectMonth(selectedMonth.previousMonth()),
            onNextMonth: () => _selectMonth(selectedMonth.nextMonth()),
            onSelectMonth: _selectMonth,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _refreshCharges(),
              child: ListView(
                // Abajo, lugar para que el FAB no tape la última carga.
                padding: const EdgeInsets.fromLTRB(
                    Space.s5, Space.s2, Space.s5, Space.s10 * 2 + Space.s4),
                children: [
                  if (hasSummary) ...[
                    _buildSummary(summaryAsync, params, monthName),
                    const Gap(Space.s6),
                  ],
                  if (_showCharts) ...[
                    _buildCharts(),
                    const Gap(Space.s6),
                  ],
                  _buildCharges(chargesAsync, params, monthName),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        tooltip: 'Agregar carga',
        onPressed: () => _openSheet(null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Carga'),
      ),
    );
  }

  Widget _buildSummary(
    AsyncValue<FuelChargeSummary> summaryAsync,
    MonthlyFuelParams params,
    String monthName,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('Resumen de $monthName'),
        const Gap(Space.s2),
        summaryAsync.when(
          data: (summary) => FuelMonthSummary(summary: summary),
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => AppNotice.error(
            message: 'No se pudo cargar el resumen del mes.',
            onRetry: () => ref.invalidate(fuelChargeSummaryProvider(params)),
          ),
        ),
      ],
    );
  }

  Widget _buildCharts() {
    final c = context.colors;
    final chartAsync = ref.watch(fuelChartDataProvider(_chartParams));
    final allCharges =
        ref.watch(fuelChargesByVehicleProvider(widget.vehicleId)).valueOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Últimos $_chartMonths meses'),
        const Gap(Space.s2),
        chartAsync.when(
          data: (data) => data.every((month) => month.totalLiters == 0)
              ? AppCard(
                  child: Text(
                    'Todavía no hay cargas para graficar.',
                    style: AppText.body.copyWith(color: c.textMuted),
                  ),
                )
              : FuelCharts(data: data, charges: allCharges ?? const []),
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => AppNotice.error(
            message: 'No se pudieron cargar los gráficos.',
            onRetry: () => ref.invalidate(fuelChartDataProvider(_chartParams)),
          ),
        ),
      ],
    );
  }

  Widget _buildCharges(
    AsyncValue<List<FuelCharge>> chargesAsync,
    MonthlyFuelParams params,
    String monthName,
  ) {
    return chargesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(Space.s8),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => ErrorRetryView(
        message: 'No se pudieron cargar las cargas',
        onRetry: () => ref.invalidate(fuelChargesByMonthProvider(params)),
      ),
      data: (charges) {
        final visible = charges
            .where((charge) => !_pendingDeleteIds.contains(charge.id))
            .toList();
        // La acción de agregar ya está en el FAB: el vacío no la repite.
        if (visible.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: Space.s8),
            child: EmptyState(
              icon: Icons.local_gas_station_rounded,
              title: 'No hay cargas en $monthName',
              message: 'Agregá una con el botón Carga.',
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader('Cargas', count: visible.length),
            const Gap(Space.s2),
            AppCard.list(
              children: [
                for (final charge in visible)
                  FuelChargeRow(
                    charge: charge,
                    onTap: () => _openSheet(charge),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _openSheet(FuelCharge? charge) async {
    final result = await showFuelChargeSheet(
      context,
      vehicleId: widget.vehicleId,
      existing: charge,
    );
    if (!mounted) return;
    switch (result) {
      case FuelChargeSheetResult.saved:
        _refreshCharges();
        AppSnack.success(context, 'Carga guardada');
      case FuelChargeSheetResult.deleteRequested:
        await _deleteCharge(charge!);
      case null:
        break;
    }
  }

  /// Reversible: sin diálogo, con "Deshacer". Una vez borrada queda oculta
  /// hasta que llega la lista nueva, sin parpadeo.
  Future<void> _deleteCharge(FuelCharge charge) async {
    final id = charge.id;
    if (id == null) return;
    final repo = ref.read(fuelChargeRepositoryProvider);
    setState(() => _pendingDeleteIds.add(id));
    final commit = await AppSnack.undoableDelete(context, 'Carga eliminada');
    if (!commit) {
      if (mounted) setState(() => _pendingDeleteIds.remove(id));
      return;
    }
    try {
      await repo.deleteFuelCharge(id);
      if (mounted) _refreshCharges();
    } catch (_) {
      if (!mounted) return;
      setState(() => _pendingDeleteIds.remove(id));
      AppSnack.error(context, 'No se pudo eliminar la carga');
    }
  }
}
