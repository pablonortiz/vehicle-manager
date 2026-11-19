import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/provinces.dart';
import '../../core/constants/vehicle_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_tone.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/confirm_dialog.dart';
import '../../core/utils/thousands_formatter.dart';
import '../../domain/models/vehicle.dart';
import '../providers/location_provider.dart';
import '../providers/vehicle_provider.dart';
import '../widgets/app_date_field.dart';
import '../widgets/app_dropdown_field.dart';
import '../widgets/app_form.dart';
import '../widgets/app_snack.dart';
import '../widgets/app_text_field.dart';
import '../widgets/city_autocomplete.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_retry_view.dart';
import '../widgets/lugar_autocomplete.dart';
import '../widgets/section_header.dart';
import '../widgets/status_styles.dart';
import '../widgets/vehicle_selectors.dart';
import 'vehicle_form/vehicle_form_data.dart';

part 'vehicle_form/identification_section.dart';
part 'vehicle_form/location_section.dart';
part 'vehicle_form/responsible_section.dart';
part 'vehicle_form/expiry_section.dart';

enum _LoadState { loading, ready, notFound, failed }

/// Alta y edición de un vehículo, en cuatro grupos: Identificación,
/// Ubicación, Responsable y Vencimientos.
class VehicleFormScreen extends ConsumerStatefulWidget {
  final String? vehicleId;

  const VehicleFormScreen({super.key, this.vehicleId});

  @override
  ConsumerState<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends ConsumerState<VehicleFormScreen> {
  final _formKey = GlobalKey<AppFormState>();
  final _cityKey = GlobalKey<CityAutocompleteState>();
  final _lugarKey = GlobalKey<LugarAutocompleteState>();
  final _data = VehicleFormData();
  late _LoadState _loadState =
      _isEditing ? _LoadState.loading : _LoadState.ready;
  bool _isSaving = false;

  bool get _isEditing => widget.vehicleId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _load();
  }

  @override
  void dispose() {
    _data.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final vehicle =
          await ref.read(vehicleByIdProvider(widget.vehicleId!).future);
      if (!mounted) return;
      if (vehicle == null) {
        setState(() => _loadState = _LoadState.notFound);
        return;
      }
      _data.load(vehicle);
      setState(() => _loadState = _LoadState.ready);
    } catch (_) {
      if (mounted) setState(() => _loadState = _LoadState.failed);
    }
  }

  void _retryLoad() {
    setState(() => _loadState = _LoadState.loading);
    ref.invalidate(vehicleByIdProvider(widget.vehicleId!));
    _load();
  }

  void _refresh() => setState(() {});

  Future<void> _attemptClose() async {
    if (_data.isDirty && !await confirmDiscard(context)) return;
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _loadState == _LoadState.ready;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _attemptClose();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Editar vehículo' : 'Nuevo vehículo'),
        ),
        body: switch (_loadState) {
          _LoadState.loading =>
            const Center(child: CircularProgressIndicator()),
          _LoadState.failed => ErrorRetryView(
              message: 'No se pudo cargar el vehículo',
              onRetry: _retryLoad,
            ),
          _LoadState.notFound => const Center(
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: 'No encontramos este vehículo',
              ),
            ),
          _LoadState.ready => _buildForm(),
        },
        bottomNavigationBar: ready ? _buildSaveBar() : null,
      ),
    );
  }

  /// Todos los campos quedan montados (SingleChildScrollView, no ListView):
  /// `validate` solo revisa los campos que existen.
  Widget _buildForm() {
    return AppForm(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            Space.s5, Space.s2, Space.s5, Space.s8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _IdentificationSection(data: _data, onChanged: _refresh),
            const Gap(Space.s8),
            _LocationSection(
              data: _data,
              cityKey: _cityKey,
              lugarKey: _lugarKey,
              onChanged: _refresh,
            ),
            const Gap(Space.s8),
            _ResponsibleSection(data: _data),
            const Gap(Space.s8),
            _ExpirySection(data: _data, onChanged: _refresh),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveBar() {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              Space.s5, Space.s3, Space.s5, Space.s3),
          child: SizedBox(
            height: Sizes.controlH,
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
              child: Text(
                _isSaving
                    ? 'Guardando…'
                    : _isEditing
                        ? 'Guardar cambios'
                        : 'Agregar vehículo',
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validateAndReveal()) return;

    setState(() => _isSaving = true);
    try {
      final location = await _resolveLocation();
      final vehicle = _data.toVehicle(
        id: widget.vehicleId,
        cityId: location.cityId,
        lugarId: location.lugarId,
      );
      final saved = await _persist(vehicle);
      if (!mounted) return;
      if (!saved) {
        AppSnack.error(
            context, 'No se pudo guardar. ¿Ya hay otro vehículo con esa patente?');
        return;
      }
      _data.markSaved();
      AppSnack.success(
          context, _isEditing ? 'Vehículo guardado' : 'Vehículo agregado');
      context.pop();
    } catch (_) {
      if (mounted) {
        AppSnack.error(
            context, 'No se pudo guardar el vehículo. Revisá la conexión.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Ciudad y lugar escritos a mano que no existen se crean al guardar.
  Future<({String? cityId, String? lugarId})> _resolveLocation() async {
    final locationRepo = ref.read(locationRepositoryProvider);
    var cityId = _data.cityId;
    final cityName = _data.city.text.trim();
    if (cityName.isNotEmpty && cityId == null) {
      cityId =
          (await locationRepo.getOrCreateCity(_data.provinceId, cityName)).id;
      ref.invalidate(citiesByProvinceProvider(_data.provinceId));
      ref.invalidate(vehicleCountByCityProvider(_data.provinceId));
    }

    var lugarId = _data.lugarId;
    final lugarName = _data.lugar.text.trim();
    if (lugarName.isNotEmpty && lugarId == null && cityId != null) {
      lugarId = (await locationRepo.getOrCreateLugar(cityId, lugarName)).id;
      ref.invalidate(lugaresByCityProvider(cityId));
      ref.invalidate(vehicleCountByLugarProvider(cityId));
    }
    ref.invalidate(vehicleCountByProvinceProvider);
    return (cityId: cityId, lugarId: lugarId);
  }

  Future<bool> _persist(Vehicle vehicle) async {
    final notifier = ref.read(vehicleNotifierProvider.notifier);
    if (_isEditing) return notifier.updateVehicle(vehicle);
    return await notifier.addVehicle(vehicle) != null;
  }
}
