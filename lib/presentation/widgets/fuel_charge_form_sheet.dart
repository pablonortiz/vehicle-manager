import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_button_styles.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_tone.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/thousands_formatter.dart';
import '../../domain/models/fuel_charge.dart';
import '../providers/fuel_charge_provider.dart';
import '../providers/vehicle_provider.dart';
import 'app_date_field.dart';
import 'app_form.dart';
import 'app_sheet.dart';
import 'app_snack.dart';
import 'app_text_field.dart';
import 'ocr_photo_capture.dart';

enum FuelChargeSheetResult { saved, deleteRequested }

/// Abre el sheet de alta o edición de una carga. Devuelve si se guardó o si
/// se pidió eliminarla (el borrado, con "Deshacer", lo hace la pantalla).
Future<FuelChargeSheetResult?> showFuelChargeSheet(
  BuildContext context, {
  required String vehicleId,
  FuelCharge? existing,
}) {
  return showAppSheet<FuelChargeSheetResult>(
    context,
    enableDrag: false,
    builder: (_) => FuelChargeFormSheet(vehicleId: vehicleId, existing: existing),
  );
}

/// Foto adjunta a una carga (ticket o surtidor).
typedef _Photo = ({String url, String? publicId, bool isPdf, String? fileName});

class FuelChargeFormSheet extends ConsumerStatefulWidget {
  final String vehicleId;
  final FuelCharge? existing;

  const FuelChargeFormSheet({super.key, required this.vehicleId, this.existing});

  @override
  ConsumerState<FuelChargeFormSheet> createState() => _FuelChargeFormSheetState();
}

class _FuelChargeFormSheetState extends ConsumerState<FuelChargeFormSheet> {
  final _formKey = GlobalKey<AppFormState>();
  late DateTime _date;
  late final DateTime _savedDate;
  late final TextEditingController _litersController;
  late final TextEditingController _priceController;
  late final TextEditingController _odometerController;
  late final TextEditingController _notesController;
  late final List<String> _savedTexts;
  _Photo? _receipt;
  _Photo? _display;

  /// "Leído del ticket" / "Leído del surtidor" mientras el valor siga siendo
  /// el que completó el OCR.
  String? _litersReadFrom;
  String? _priceReadFrom;
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _date = existing?.date ?? DateTime.now();
    _savedDate = _date;
    _litersController = TextEditingController(
        text: existing == null ? '' : formatLitersAr(existing.liters));
    _priceController = TextEditingController(
        text: existing == null
            ? ''
            : formatWithDots(existing.price.toStringAsFixed(0)));
    _odometerController = TextEditingController(
        text: existing?.odometer == null
            ? ''
            : formatWithDots('${existing!.odometer}'));
    _notesController = TextEditingController(text: existing?.notes ?? '');
    _savedTexts = [for (final controller in _controllers) controller.text];
    _receipt = existing?.receiptPhotoUrl == null
        ? null
        : (
            url: existing!.receiptPhotoUrl!,
            publicId: existing.receiptPhotoPublicId,
            isPdf: existing.receiptIsPdf,
            fileName: existing.receiptFileName,
          );
    _display = existing?.displayPhotoUrl == null
        ? null
        : (
            url: existing!.displayPhotoUrl!,
            publicId: existing.displayPhotoPublicId,
            isPdf: existing.displayIsPdf,
            fileName: existing.displayFileName,
          );
  }

  List<TextEditingController> get _controllers => [
        _litersController,
        _priceController,
        _odometerController,
        _notesController,
      ];

  /// Comparado contra lo guardado: tocar un campo sin cambiarlo no cuenta.
  bool get _isDirty {
    final existing = widget.existing;
    final textChanged = [
      for (final (index, controller) in _controllers.indexed)
        controller.text != _savedTexts[index],
    ].any((changed) => changed);
    return textChanged ||
        !DateUtils.isSameDay(_date, _savedDate) ||
        _receipt?.url != existing?.receiptPhotoUrl ||
        _display?.url != existing?.displayPhotoUrl;
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Vuelca lo que leyó el OCR. El valor principal de cada foto (precio en el
  /// ticket, litros en el surtidor) pisa el campo; el otro solo completa si
  /// el campo está vacío, para no pisar lo que ya cargó el usuario.
  void _applyOcr(OcrPhotoResult result, OcrPhotoType type) {
    final fromReceipt = type == OcrPhotoType.receipt;
    final source = fromReceipt ? 'Leído del ticket' : 'Leído del surtidor';
    final price = result.extractedPrice;
    if (price != null && (fromReceipt || _priceController.text.isEmpty)) {
      _priceController.text = formatWithDots(price.toStringAsFixed(0));
      _priceReadFrom = source;
    }
    final liters = result.extractedLiters;
    if (liters != null && (!fromReceipt || _litersController.text.isEmpty)) {
      _litersController.text = formatLitersAr(liters);
      _litersReadFrom = source;
    }
  }

  void _onPhoto(OcrPhotoResult result, OcrPhotoType type) {
    final url = result.cloudinaryUrl;
    final photo = url == null
        ? null
        : (
            url: url,
            publicId: result.cloudinaryPublicId,
            isPdf: result.isPdf,
            fileName: result.fileName,
          );
    setState(() {
      if (type == OcrPhotoType.receipt) {
        _receipt = photo;
      } else {
        _display = photo;
      }
      _applyOcr(result, type);
    });
  }

  static String? _validateLiters(String? value) {
    if (value == null || value.isEmpty) return 'Ingresá los litros cargados';
    final liters = double.tryParse(value.replaceAll(',', '.'));
    if (liters == null) return 'Revisá los litros: tiene que ser un número';
    if (liters <= 0) return 'Los litros tienen que ser más que 0';
    if (liters > FuelCharge.maxPlausibleLiters) {
      return 'Es mucho para una carga (máx. '
          '${FuelCharge.maxPlausibleLiters.toInt()} L). ¿Falta la coma?';
    }
    return null;
  }

  static String? _validatePrice(String? value) {
    if (value == null || value.isEmpty) return 'Ingresá el precio';
    if (int.tryParse(value.replaceAll('.', '')) == null) {
      return 'Revisá el precio: tiene que ser un número';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppSheet(
      title: _isEditing ? 'Editar carga' : 'Nueva carga',
      hasUnsavedChanges: _isDirty && !_isSaving,
      footer: SizedBox(
        width: double.infinity,
        height: Sizes.controlH,
        child: FilledButton(
          onPressed: _isSaving ? null : _save,
          child: Text(_isSaving ? 'Guardando…' : 'Guardar carga'),
        ),
      ),
      child: AppForm(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDateField(
              label: 'Fecha',
              required: true,
              value: _date,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              onChanged: (date) => setState(() => _date = date),
            ),
            const Gap(Space.s4),
            Row(
              children: [
                const Expanded(child: FieldLabel('Fotos')),
                Text('Se leen litros y precio',
                    style: AppText.caption.copyWith(color: c.textMuted)),
              ],
            ),
            const Gap(Space.s2),
            Row(
              children: [
                Expanded(
                  child: OcrPhotoCapture(
                    type: OcrPhotoType.receipt,
                    initialPhotoUrl: _receipt?.url,
                    initialIsPdf: _receipt?.isPdf ?? false,
                    initialFileName: _receipt?.fileName,
                    onPhotoResult: (result) =>
                        _onPhoto(result, OcrPhotoType.receipt),
                  ),
                ),
                const Gap(Space.s3),
                Expanded(
                  child: OcrPhotoCapture(
                    type: OcrPhotoType.display,
                    initialPhotoUrl: _display?.url,
                    initialIsPdf: _display?.isPdf ?? false,
                    initialFileName: _display?.fileName,
                    onPhotoResult: (result) =>
                        _onPhoto(result, OcrPhotoType.display),
                  ),
                ),
              ],
            ),
            const Gap(Space.s4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Litros',
                    required: true,
                    controller: _litersController,
                    hint: '23,562',
                    suffixText: 'L',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [DecimalCommaFormatter()],
                    helper: _litersReadFrom,
                    helperTone: Tone.success,
                    validator: _validateLiters,
                    onChanged: (_) => setState(() => _litersReadFrom = null),
                  ),
                ),
                const Gap(Space.s3),
                Expanded(
                  child: AppTextField(
                    label: 'Precio',
                    required: true,
                    controller: _priceController,
                    hint: '30.000',
                    prefixText: r'$ ',
                    keyboardType: TextInputType.number,
                    inputFormatters: [ThousandsSeparatorFormatter()],
                    helper: _priceReadFrom,
                    helperTone: Tone.success,
                    validator: _validatePrice,
                    onChanged: (_) => setState(() => _priceReadFrom = null),
                  ),
                ),
              ],
            ),
            const Gap(Space.s4),
            AppTextField(
              label: 'Odómetro',
              controller: _odometerController,
              hint: 'Opcional',
              suffixText: 'km',
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorFormatter()],
              onChanged: (_) => setState(() {}),
              helper: 'Si es mayor, actualiza el kilometraje del vehículo',
            ),
            const Gap(Space.s4),
            AppTextField(
              label: 'Notas',
              controller: _notesController,
              hint: 'Estación, tipo de combustible…',
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
            ),
            if (_isEditing) ...[
              const Gap(Space.s4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  style: AppButtonStyles.dangerText(context),
                  onPressed: _isSaving
                      ? null
                      : () => Navigator.pop(
                          context, FuelChargeSheetResult.deleteRequested),
                  icon: const Icon(Icons.delete_rounded),
                  label: const Text('Eliminar carga'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validateAndReveal()) return;
    final liters = double.tryParse(_litersController.text.replaceAll(',', '.'));
    final price = double.tryParse(_priceController.text.replaceAll('.', ''));
    if (liters == null || price == null) return;
    final odometerText = _odometerController.text.replaceAll('.', '');
    final odometer = odometerText.isEmpty ? null : int.tryParse(odometerText);
    final notes = _notesController.text.trim();

    setState(() => _isSaving = true);
    try {
      final charge = FuelCharge(
        id: widget.existing?.id,
        vehicleId: widget.vehicleId,
        date: _date,
        liters: liters,
        price: price,
        odometer: odometer,
        receiptPhotoUrl: _receipt?.url,
        receiptPhotoPublicId: _receipt?.publicId,
        receiptIsPdf: _receipt?.isPdf ?? false,
        receiptFileName: _receipt?.fileName,
        displayPhotoUrl: _display?.url,
        displayPhotoPublicId: _display?.publicId,
        displayIsPdf: _display?.isPdf ?? false,
        displayFileName: _display?.fileName,
        notes: notes.isEmpty ? null : notes,
        createdAt: widget.existing?.createdAt,
      );
      final repo = ref.read(fuelChargeRepositoryProvider);
      if (_isEditing) {
        await repo.updateFuelCharge(charge);
      } else {
        await repo.insertFuelCharge(charge);
      }
      if (odometer != null) await _raiseVehicleKm(odometer);
      if (mounted) Navigator.pop(context, FuelChargeSheetResult.saved);
    } catch (_) {
      if (mounted) {
        AppSnack.error(context, 'No se pudo guardar la carga. Revisá la conexión.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Un odómetro mayor al kilometraje cargado lo actualiza.
  Future<void> _raiseVehicleKm(int odometer) async {
    final vehicle = await ref.read(vehicleByIdProvider(widget.vehicleId).future);
    if (vehicle == null || odometer <= vehicle.km) return;
    await ref
        .read(vehicleNotifierProvider.notifier)
        .updateVehicle(vehicle.copyWith(km: odometer));
    ref.invalidate(vehicleByIdProvider(widget.vehicleId));
  }
}
