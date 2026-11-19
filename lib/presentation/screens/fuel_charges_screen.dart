import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/confirm_dialog.dart';
import '../widgets/error_retry_view.dart';
import '../widgets/empty_state.dart';
import '../../domain/models/fuel_charge.dart';
import '../providers/fuel_charge_provider.dart';
import '../widgets/month_navigator.dart';
import '../widgets/fuel_summary_card.dart';
import '../widgets/fuel_charge_card.dart';
import '../widgets/fuel_charts.dart';
import '../widgets/fuel_charge_form_sheet.dart';

class FuelChargesScreen extends ConsumerStatefulWidget {
  final String vehicleId;

  const FuelChargesScreen({
    super.key,
    required this.vehicleId,
  });

  @override
  ConsumerState<FuelChargesScreen> createState() => _FuelChargesScreenState();
}

class _FuelChargesScreenState extends ConsumerState<FuelChargesScreen> {
  bool _showCharts = false;
  // Borrado diferido: ocultas mientras corre el SnackBar de "Deshacer".
  final Set<String> _pendingDeleteIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _jumpToLatestMonthWithData());
  }

  /// Si el mes seleccionado (el actual, al abrir) no tiene cargas, arranca en
  /// el último mes que sí tenga, en vez de mostrar un mes vacío.
  Future<void> _jumpToLatestMonthWithData() async {
    final charges =
        await ref.read(fuelChargesByVehicleProvider(widget.vehicleId).future);
    if (!mounted || charges.isEmpty) return;

    final selected = ref.read(selectedMonthProvider(widget.vehicleId));
    final now = DateTime.now();
    final userNavigated = selected.year != now.year || selected.month != now.month;
    if (userNavigated) return;

    final hasChargesInSelected = charges.any(
        (c) => c.date.year == selected.year && c.date.month == selected.month);
    if (hasChargesInSelected) return;

    final latest = charges
        .map((c) => c.date)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    ref.read(selectedMonthProvider(widget.vehicleId).notifier).state =
        SelectedMonthState(year: latest.year, month: latest.month);
  }

  @override
  Widget build(BuildContext context) {
    final selectedMonth = ref.watch(selectedMonthProvider(widget.vehicleId));
    final chargesParams = MonthlyFuelParams(
      vehicleId: widget.vehicleId,
      year: selectedMonth.year,
      month: selectedMonth.month,
    );
    final chargesAsync = ref.watch(fuelChargesByMonthProvider(chargesParams));
    final summaryAsync = ref.watch(fuelChargeSummaryProvider(chargesParams));
    final chartDataAsync = ref.watch(fuelChartDataProvider(
      ChartDataParams(vehicleId: widget.vehicleId, months: 6),
    ));
    final allChargesAsync =
        ref.watch(fuelChargesByVehicleProvider(widget.vehicleId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cargas de Combustible'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() => _showCharts = !_showCharts);
            },
            icon: Icon(
              _showCharts ? Icons.bar_chart : Icons.bar_chart_outlined,
              color: _showCharts ? AppTheme.accentPrimary : AppTheme.textSecondary,
            ),
            tooltip: 'Ver estadísticas',
          ),
        ],
      ),
      body: Column(
        children: [
          MonthNavigator(
            selectedMonth: selectedMonth,
            onPreviousMonth: () {
              ref.read(selectedMonthProvider(widget.vehicleId).notifier).state =
                  selectedMonth.previousMonth();
            },
            onNextMonth: () {
              ref.read(selectedMonthProvider(widget.vehicleId).notifier).state =
                  selectedMonth.nextMonth();
            },
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(fuelChargesByMonthProvider(chargesParams));
                ref.invalidate(fuelChargeSummaryProvider(chargesParams));
                ref.invalidate(fuelChartDataProvider(
                  ChartDataParams(vehicleId: widget.vehicleId, months: 6),
                ));
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Summary card (si el mes está vacío, alcanza con el
                    // empty state de la lista — no duplicar el mensaje)
                    summaryAsync.when(
                      data: (summary) => summary.chargeCount == 0
                          ? const SizedBox.shrink()
                          : FuelSummaryCard(summary: summary),
                      loading: () => const Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                      error: (e, _) => ErrorRetryView(
                        message: 'No se pudo cargar el resumen',
                        onRetry: () =>
                            ref.invalidate(fuelChargeSummaryProvider(chargesParams)),
                      ),
                    ),
                    // Charts section (collapsible)
                    if (_showCharts)
                      chartDataAsync.when(
                        data: (data) => FuelCharts(
                          data: data,
                          charges: allChargesAsync.valueOrNull ?? const [],
                        ),
                        loading: () => const Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                        error: (e, _) => const SizedBox.shrink(),
                      ),
                    if (_showCharts) const SizedBox(height: 16),
                    // Charges list
                    chargesAsync.when(
                      data: (charges) {
                        if (charges.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(32),
                            child: EmptyState(
                              icon: Icons.local_gas_station_outlined,
                              title: 'No hay cargas este mes',
                              actionLabel: 'Agregar carga',
                              onAction: () => _showFuelChargeForm(null),
                            ),
                          );
                        }
                        return Column(
                          children: charges
                              .where((c) => !_pendingDeleteIds.contains(c.id))
                              .map((charge) => FuelChargeCard(
                                    fuelCharge: charge,
                                    onTap: () => _showFuelChargeForm(charge),
                                    onDelete: () => _deleteCharge(charge),
                                  ))
                              .toList(),
                        );
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                      error: (e, _) => ErrorRetryView(
                        message: 'No se pudieron cargar las cargas',
                        onRetry: () =>
                            ref.invalidate(fuelChargesByMonthProvider(chargesParams)),
                      ),
                    ),
                    const SizedBox(height: 80), // Space for FAB
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFuelChargeForm(null),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _deleteCharge(FuelCharge charge) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Eliminar carga',
      message: '¿Eliminar esta carga de combustible?',
    );
    if (!confirmed || charge.id == null || !mounted) return;

    // Diferido: se oculta ya, y el delete real corre cuando expira el
    // SnackBar (si el usuario no tocó "Deshacer").
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(fuelChargeRepositoryProvider);
    setState(() => _pendingDeleteIds.add(charge.id!));

    final controller = messenger.showSnackBar(SnackBar(
      content: const Text('Carga eliminada'),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(label: 'Deshacer', onPressed: () {}),
    ));
    final reason = await controller.closed;

    if (reason == SnackBarClosedReason.action) {
      if (mounted) setState(() => _pendingDeleteIds.remove(charge.id));
      return;
    }
    try {
      await repo.deleteFuelCharge(charge.id!);
      if (mounted) {
        final selectedMonth =
            ref.read(selectedMonthProvider(widget.vehicleId));
        final params = MonthlyFuelParams(
          vehicleId: widget.vehicleId,
          year: selectedMonth.year,
          month: selectedMonth.month,
        );
        ref.invalidate(fuelChargesByMonthProvider(params));
        ref.invalidate(fuelChargeSummaryProvider(params));
        ref.invalidate(fuelChartDataProvider(
          ChartDataParams(vehicleId: widget.vehicleId, months: 6),
        ));
        ref.invalidate(recentFuelChargesProvider(widget.vehicleId));
      }
    } finally {
      if (mounted) setState(() => _pendingDeleteIds.remove(charge.id));
    }
  }

  void _showFuelChargeForm(FuelCharge? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FuelChargeFormSheet(
        vehicleId: widget.vehicleId,
        existing: existing,
        onSaved: () {
          final selectedMonth = ref.read(selectedMonthProvider(widget.vehicleId));
          final params = MonthlyFuelParams(
            vehicleId: widget.vehicleId,
            year: selectedMonth.year,
            month: selectedMonth.month,
          );
          ref.invalidate(fuelChargesByMonthProvider(params));
          ref.invalidate(fuelChargeSummaryProvider(params));
          ref.invalidate(fuelChartDataProvider(
            ChartDataParams(vehicleId: widget.vehicleId, months: 6),
          ));
          ref.invalidate(recentFuelChargesProvider(widget.vehicleId));
        },
      ),
    );
  }
}
