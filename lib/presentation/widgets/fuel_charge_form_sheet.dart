import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/confirm_dialog.dart';
import '../../core/utils/thousands_formatter.dart';
import '../../domain/models/fuel_charge.dart';
import '../providers/fuel_charge_provider.dart';
import '../providers/vehicle_provider.dart';
import 'ocr_photo_capture.dart';

class FuelChargeFormSheet extends ConsumerStatefulWidget {
  final String vehicleId;
  final FuelCharge? existing;
  final VoidCallback onSaved;

  const FuelChargeFormSheet({
    super.key,
    required this.vehicleId,
    this.existing,
    required this.onSaved,
  });

  @override
  ConsumerState<FuelChargeFormSheet> createState() => _FuelChargeFormSheetState();
}

class _FuelChargeFormSheetState extends ConsumerState<FuelChargeFormSheet> {
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
  bool _receiptIsPdf = false;
  String? _receiptFileName;
  String? _displayPhotoUrl;
  String? _displayPhotoPublicId;
  bool _displayIsPdf = false;
  String? _displayFileName;

  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.existing?.date ?? DateTime.now();
    _litersController = TextEditingController(
      text: widget.existing != null ? formatLitersAr(widget.existing!.liters) : '',
    );
    _priceController = TextEditingController(
      text: widget.existing != null
          ? formatWithDots(widget.existing!.price.toStringAsFixed(0))
          : '',
    );
    _odometerController = TextEditingController(
      text: widget.existing?.odometer?.toString() ?? '',
    );
    _notesController = TextEditingController(
      text: widget.existing?.notes ?? '',
    );
    _receiptPhotoUrl = widget.existing?.receiptPhotoUrl;
    _receiptPhotoPublicId = widget.existing?.receiptPhotoPublicId;
    _receiptIsPdf = widget.existing?.receiptIsPdf ?? false;
    _receiptFileName = widget.existing?.receiptFileName;
    _displayPhotoUrl = widget.existing?.displayPhotoUrl;
    _displayPhotoPublicId = widget.existing?.displayPhotoPublicId;
    _displayIsPdf = widget.existing?.displayIsPdf ?? false;
    _displayFileName = widget.existing?.displayFileName;

    // Los valores iniciales ya están seteados; a partir de acá cualquier edición
    // de texto marca el form como sucio (para confirmar al cerrar sin guardar).
    for (final c in [
      _litersController,
      _priceController,
      _odometerController,
      _notesController,
    ]) {
      c.addListener(_markDirty);
    }
  }

  void _markDirty() {
    if (!_hasChanges) _hasChanges = true;
  }

  /// Vuelca al form lo que detectó el OCR. El valor primario del slot (precio
  /// para el ticket, litros para el surtidor) pisa el campo; el secundario
  /// solo completa si el campo está vacío, para no sobreescribir lo que ya
  /// cargó el usuario o la otra foto.
  void _applyOcrValues(OcrPhotoResult result, {required bool primaryIsPrice}) {
    final price = result.extractedPrice;
    if (price != null && (primaryIsPrice || _priceController.text.isEmpty)) {
      _priceController.text = formatWithDots(price.toStringAsFixed(0));
      _priceFromOcr = true;
    }
    final liters = result.extractedLiters;
    if (liters != null && (!primaryIsPrice || _litersController.text.isEmpty)) {
      _litersController.text = formatLitersAr(liters);
      _litersFromOcr = true;
    }
  }

  Future<void> _attemptClose() async {
    if (_hasChanges) {
      final discard = await confirmDiscard(context);
      if (!discard) return;
    }
    if (mounted) Navigator.pop(context);
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
                      onPressed: _attemptClose,
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
                            _receiptIsPdf = result.isPdf;
                            _receiptFileName = result.fileName;
                            _applyOcrValues(result, primaryIsPrice: true);
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
                            _displayIsPdf = result.isPdf;
                            _displayFileName = result.fileName;
                            _applyOcrValues(result, primaryIsPrice: false);
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
                    hintText: 'Ej: 23,562',
                    suffixText: 'L',
                    suffixIcon: _litersFromOcr
                        ? const Icon(Icons.check_circle, color: AppTheme.success, size: 20)
                        : null,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [DecimalCommaFormatter()],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingrese los litros';
                    }
                    final liters = double.tryParse(value.replaceAll(',', '.'));
                    if (liters == null) {
                      return 'Número inválido';
                    }
                    if (liters <= 0) {
                      return 'Los litros deben ser mayores a 0';
                    }
                    if (liters > FuelCharge.maxPlausibleLiters) {
                      return 'Valor muy alto (máx. ${FuelCharge.maxPlausibleLiters.toInt()} L). ¿Faltó la coma decimal?';
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
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsSeparatorFormatter()],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingrese el precio';
                    }
                    if (int.tryParse(value.replaceAll('.', '')) == null) {
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
      final liters = double.tryParse(_litersController.text.replaceAll(',', '.'));
      final priceText = _priceController.text.replaceAll('.', '').replaceAll(',', '.');
      final price = double.tryParse(priceText);
      final odometer = _odometerController.text.isNotEmpty
          ? int.tryParse(_odometerController.text.replaceAll('.', '').replaceAll(',', ''))
          : null;
      if (liters == null || price == null) {
        // El validator debería prevenirlo; si igual llega un valor no numérico,
        // abortamos limpio en vez de lanzar FormatException.
        if (mounted) setState(() => _isSaving = false);
        return;
      }
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
        receiptIsPdf: _receiptIsPdf,
        receiptFileName: _receiptFileName,
        displayPhotoUrl: _displayPhotoUrl,
        displayPhotoPublicId: _displayPhotoPublicId,
        displayIsPdf: _displayIsPdf,
        displayFileName: _displayFileName,
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
          const SnackBar(content: Text('No se pudo guardar la carga')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
