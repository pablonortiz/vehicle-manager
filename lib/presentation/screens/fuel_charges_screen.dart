import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/fuel_charge.dart';
import '../providers/fuel_charge_provider.dart';
import '../providers/vehicle_provider.dart';
import '../widgets/month_navigator.dart';
import '../widgets/fuel_summary_card.dart';
import '../widgets/fuel_charge_card.dart';
import '../widgets/fuel_charts.dart';
import '../widgets/ocr_photo_capture.dart';

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
  String? _deletingId;

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
                    // Summary card
                    summaryAsync.when(
                      data: (summary) => FuelSummaryCard(summary: summary),
                      loading: () => const Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Error: $e'),
                      ),
                    ),
                    // Charts section (collapsible)
                    if (_showCharts)
                      chartDataAsync.when(
                        data: (data) => FuelCharts(data: data),
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
                            child: Column(
                              children: [
                                Icon(
                                  Icons.local_gas_station_outlined,
                                  size: 64,
                                  color: AppTheme.textSecondary.withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No hay cargas este mes',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return Column(
                          children: charges.map((charge) => FuelChargeCard(
                            fuelCharge: charge,
                            onTap: () => _showFuelChargeForm(charge),
                            onDelete: () => _deleteCharge(charge),
                            isDeleting: _deletingId == charge.id,
                          )).toList(),
                        );
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Error: $e'),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar carga'),
        content: const Text('¿Estás seguro de eliminar esta carga de combustible?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );

    if (confirmed != true || charge.id == null) return;

    setState(() => _deletingId = charge.id);

    try {
      final repo = ref.read(fuelChargeRepositoryProvider);
      await repo.deleteFuelCharge(charge.id!);

      // Refresh data
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Carga eliminada')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _deletingId = null);
      }
    }
  }

  void _showFuelChargeForm(FuelCharge? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FuelChargeFormSheet(
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

class _FuelChargeFormSheet extends ConsumerStatefulWidget {
  final String vehicleId;
  final FuelCharge? existing;
  final VoidCallback onSaved;

  const _FuelChargeFormSheet({
    required this.vehicleId,
    this.existing,
    required this.onSaved,
  });

  @override
  ConsumerState<_FuelChargeFormSheet> createState() => _FuelChargeFormSheetState();
}

class _FuelChargeFormSheetState extends ConsumerState<_FuelChargeFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _selectedDate;
  late TextEditingController _litersController;
  late TextEditingController _priceController;
  late TextEditingController _odometerController;
  late TextEditingController _notesController;

  bool _litersFromOcr = false;
  bool _priceFromOcr = false;

  String? _receiptPhotoUrl;
  String? _receiptPhotoPublicId;
  String? _displayPhotoUrl;
  String? _displayPhotoPublicId;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.existing?.date ?? DateTime.now();
    _litersController = TextEditingController(
      text: widget.existing?.liters.toString() ?? '',
    );
    _priceController = TextEditingController(
      text: widget.existing?.price.toStringAsFixed(0) ?? '',
    );
    _odometerController = TextEditingController(
      text: widget.existing?.odometer?.toString() ?? '',
    );
    _notesController = TextEditingController(
      text: widget.existing?.notes ?? '',
    );
    _receiptPhotoUrl = widget.existing?.receiptPhotoUrl;
    _receiptPhotoPublicId = widget.existing?.receiptPhotoPublicId;
    _displayPhotoUrl = widget.existing?.displayPhotoUrl;
    _displayPhotoPublicId = widget.existing?.displayPhotoPublicId;
  }

  @override
  void dispose() {
    _litersController.dispose();
    _priceController.dispose();
    _odometerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'Editar Carga' : 'Nueva Carga',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Date picker
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 20, color: AppTheme.accentPrimary),
                        const SizedBox(width: 12),
                        Text(
                          dateFormat.format(_selectedDate),
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Photos section
                const Text(
                  'Fotos (opcional, OCR automático)',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OcrPhotoCapture(
                        type: OcrPhotoType.receipt,
                        initialPhotoUrl: _receiptPhotoUrl,
                        showOcrIndicator: _priceFromOcr,
                        onPhotoResult: (result) {
                          setState(() {
                            _receiptPhotoUrl = result.cloudinaryUrl;
                            _receiptPhotoPublicId = result.cloudinaryPublicId;
                            if (result.extractedValue != null) {
                              _priceController.text = result.extractedValue!.toStringAsFixed(0);
                              _priceFromOcr = true;
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OcrPhotoCapture(
                        type: OcrPhotoType.display,
                        initialPhotoUrl: _displayPhotoUrl,
                        showOcrIndicator: _litersFromOcr,
                        onPhotoResult: (result) {
                          setState(() {
                            _displayPhotoUrl = result.cloudinaryUrl;
                            _displayPhotoPublicId = result.cloudinaryPublicId;
                            if (result.extractedValue != null) {
                              _litersController.text = result.extractedValue!.toStringAsFixed(2);
                              _litersFromOcr = true;
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Liters field
                TextFormField(
                  controller: _litersController,
                  decoration: InputDecoration(
                    labelText: 'Litros *',
                    suffixText: 'L',
                    suffixIcon: _litersFromOcr
                        ? const Icon(Icons.check_circle, color: AppTheme.success, size: 20)
                        : null,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingrese los litros';
                    }
                    if (double.tryParse(value.replaceAll(',', '.')) == null) {
                      return 'Número inválido';
                    }
                    return null;
                  },
                  onChanged: (_) {
                    if (_litersFromOcr) setState(() => _litersFromOcr = false);
                  },
                ),
                const SizedBox(height: 16),

                // Price field
                TextFormField(
                  controller: _priceController,
                  decoration: InputDecoration(
                    labelText: 'Precio *',
                    prefixText: '\$ ',
                    suffixIcon: _priceFromOcr
                        ? const Icon(Icons.check_circle, color: AppTheme.success, size: 20)
                        : null,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingrese el precio';
                    }
                    if (double.tryParse(value.replaceAll(',', '.').replaceAll('.', '')) == null) {
                      return 'Número inválido';
                    }
                    return null;
                  },
                  onChanged: (_) {
                    if (_priceFromOcr) setState(() => _priceFromOcr = false);
                  },
                ),
                const SizedBox(height: 16),

                // Odometer field
                TextFormField(
                  controller: _odometerController,
                  decoration: const InputDecoration(
                    labelText: 'Odómetro (opcional)',
                    suffixText: 'km',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      if (int.tryParse(value.replaceAll('.', '').replaceAll(',', '')) == null) {
                        return 'Número inválido';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Notes field
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // Save button
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isEditing ? 'GUARDAR CAMBIOS' : 'GUARDAR'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final liters = double.parse(_litersController.text.replaceAll(',', '.'));
      final priceText = _priceController.text.replaceAll('.', '').replaceAll(',', '.');
      final price = double.parse(priceText);
      final odometer = _odometerController.text.isNotEmpty
          ? int.parse(_odometerController.text.replaceAll('.', '').replaceAll(',', ''))
          : null;
      final notes = _notesController.text.isNotEmpty ? _notesController.text : null;

      final fuelCharge = FuelCharge(
        id: widget.existing?.id,
        vehicleId: widget.vehicleId,
        date: _selectedDate,
        liters: liters,
        price: price,
        odometer: odometer,
        receiptPhotoUrl: _receiptPhotoUrl,
        receiptPhotoPublicId: _receiptPhotoPublicId,
        displayPhotoUrl: _displayPhotoUrl,
        displayPhotoPublicId: _displayPhotoPublicId,
        notes: notes,
        createdAt: widget.existing?.createdAt,
      );

      final repo = ref.read(fuelChargeRepositoryProvider);

      if (widget.existing != null) {
        await repo.updateFuelCharge(fuelCharge);
      } else {
        await repo.insertFuelCharge(fuelCharge);
      }

      // Update vehicle km if odometer was entered
      if (odometer != null) {
        final vehicle = await ref.read(vehicleByIdProvider(widget.vehicleId).future);
        if (vehicle != null && odometer > vehicle.km) {
          final updatedVehicle = vehicle.copyWith(km: odometer);
          await ref.read(vehicleNotifierProvider.notifier).updateVehicle(updatedVehicle);
          // Invalidate the vehicle provider to refresh the UI
          ref.invalidate(vehicleByIdProvider(widget.vehicleId));
        }
      }

      widget.onSaved();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existing != null ? 'Carga actualizada' : 'Carga guardada'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
