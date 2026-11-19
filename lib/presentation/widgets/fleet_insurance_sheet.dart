import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_tone.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../domain/fleet_insurance.dart';
import '../../domain/models/vehicle.dart';
import '../providers/vehicle_provider.dart';
import 'app_date_field.dart';
import 'app_notice.dart';
import 'app_sheet.dart';
import 'app_snack.dart';
import 'app_text_field.dart';
import 'status_styles.dart';
import 'vehicle_list_tile.dart';

/// Abre el sheet para asignar un mismo seguro (compañía + vencimiento) a los
/// vehículos que queden tildados y, si el usuario confirma, aplica los cambios
/// uno por uno mostrando el progreso. Los destildados conservan su seguro.
Future<void> showFleetInsuranceSheet(
    BuildContext context, WidgetRef ref) async {
  // Se espera la carga: leer el valor sin esperarlo daba null en el primer
  // uso y el sheet recién abría al segundo intento.
  final vehicles = await ref.read(vehiclesProvider.future);
  if (!context.mounted) return;
  if (vehicles.isEmpty) {
    AppSnack.info(context, 'Todavía no hay vehículos cargados');
    return;
  }

  final request = await showAppSheet<_InsuranceRequest>(
    context,
    enableDrag: false,
    builder: (_) => _FleetInsuranceSheet(vehicles: _sortedByName(vehicles)),
  );
  if (request == null || !context.mounted) return;

  await _applyInsurance(context, ref, request);
}

List<Vehicle> _sortedByName(List<Vehicle> vehicles) => [...vehicles]
  ..sort((vehicle, other) {
    final byName = vehicle.displayName
        .toLowerCase()
        .compareTo(other.displayName.toLowerCase());
    return byName != 0 ? byName : vehicle.plate.compareTo(other.plate);
  });

Future<void> _applyInsurance(
    BuildContext context, WidgetRef ref, _InsuranceRequest request) async {
  final updates = request.assignment.applyTo(request.vehicles);
  final skipped = request.vehicles.length - updates.length;
  if (updates.isEmpty) {
    AppSnack.info(context, 'Los vehículos elegidos ya tienen ese seguro');
    return;
  }

  final progress = ValueNotifier<int>(0);
  _showProgressDialog(context, total: updates.length, progress: progress);
  final failed = await ref
      .read(vehicleNotifierProvider.notifier)
      .updateVehicles(updates, onProgress: (done) => progress.value = done);
  progress.dispose();
  if (!context.mounted) return;

  Navigator.of(context, rootNavigator: true).pop();
  final message = _resultMessage(
    updated: updates.length - failed,
    skipped: skipped,
    failed: failed,
  );
  if (failed == 0) {
    AppSnack.success(context, message);
  } else {
    AppSnack.error(context, message);
  }
}

String _resultMessage(
    {required int updated, required int skipped, required int failed}) {
  final parts = <String>[
    updated == 1
        ? 'Seguro actualizado en 1 vehículo'
        : 'Seguro actualizado en $updated vehículos',
    if (skipped > 0) skipped == 1 ? '1 ya lo tenía' : '$skipped ya lo tenían',
    if (failed > 0)
      failed == 1
          ? '1 no se pudo actualizar'
          : '$failed no se pudieron actualizar',
  ];
  return parts.join(' · ');
}

void _showProgressDialog(BuildContext context,
    {required int total, required ValueNotifier<int> progress}) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (dialogContext) {
      final c = dialogContext.colors;
      return PopScope(
        canPop: false,
        child: AlertDialog(
          content: ValueListenableBuilder<int>(
            valueListenable: progress,
            builder: (_, done, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Actualizando el seguro…',
                    style: AppText.titleSm.copyWith(color: c.text)),
                const Gap(Space.s4),
                LinearProgressIndicator(value: done / total),
                const Gap(Space.s2),
                Text(
                  '$done de $total vehículos',
                  style: AppText.caption.tabular.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _InsuranceRequest {
  final InsuranceAssignment assignment;
  final List<Vehicle> vehicles;

  const _InsuranceRequest(this.assignment, this.vehicles);
}

class _FleetInsuranceSheet extends StatefulWidget {
  final List<Vehicle> vehicles;

  const _FleetInsuranceSheet({required this.vehicles});

  @override
  State<_FleetInsuranceSheet> createState() => _FleetInsuranceSheetState();
}

class _FleetInsuranceSheetState extends State<_FleetInsuranceSheet> {
  static const _maxSuggestedCompanies = 4;

  late final List<String> _knownCompanies;
  late final TextEditingController _companyController;
  late final Set<Vehicle> _selected;
  DateTime? _expiry;

  @override
  void initState() {
    super.initState();
    _knownCompanies = insuranceCompaniesByFrequency(widget.vehicles);
    _companyController =
        TextEditingController(text: _knownCompanies.firstOrNull ?? '');
    _selected = widget.vehicles.toSet();
  }

  @override
  void dispose() {
    _companyController.dispose();
    super.dispose();
  }

  bool get _allSelected => _selected.length == widget.vehicles.length;

  InsuranceAssignment? get _assignment {
    final expiry = _expiry;
    if (expiry == null) return null;
    return InsuranceAssignment(company: _companyController.text, expiry: expiry);
  }

  void _toggle(Vehicle vehicle) => setState(() {
        if (!_selected.remove(vehicle)) _selected.add(vehicle);
      });

  void _toggleAll() => setState(() {
        if (_allSelected) {
          _selected.clear();
        } else {
          _selected.addAll(widget.vehicles);
        }
      });

  void _confirm() {
    final assignment = _assignment;
    if (assignment == null || _selected.isEmpty) return;
    final selectedInOrder =
        widget.vehicles.where(_selected.contains).toList();
    Navigator.pop(context, _InsuranceRequest(assignment, selectedInOrder));
  }

  /// Hay algo cargado que se perdería al cerrar.
  bool get _isDirty =>
      _expiry != null ||
      _companyController.text.trim() != (_knownCompanies.firstOrNull ?? '') ||
      !_allSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final assignment = _assignment;
    final count = _selected.length;
    final canSave = assignment != null && count > 0;
    return AppSheet(
      title: 'Seguro de la flota',
      hasUnsavedChanges: _isDirty,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _assignmentNotice(assignment),
          const Gap(Space.s3),
          SizedBox(
            height: Sizes.controlH,
            child: FilledButton(
              onPressed: canSave ? _confirm : null,
              child: Text(count == 1 || !canSave
                  ? 'Guardar seguro'
                  : 'Guardar seguro en $count vehículos'),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'La compañía y el vencimiento se asignan a los vehículos tildados. '
            'Los destildados conservan su seguro.',
            style: AppText.body.copyWith(color: c.textMuted),
          ),
          const Gap(Space.s4),
          AppTextField(
            label: 'Compañía de seguro',
            controller: _companyController,
            hint: 'Vacío: no se cambia',
            icon: Icons.shield_rounded,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
          ),
          if (_knownCompanies.length > 1) ...[
            const Gap(Space.s2),
            _CompanySuggestions(
              companies: _knownCompanies.take(_maxSuggestedCompanies).toList(),
              current: _companyController.text.trim(),
              onSelected: (company) =>
                  setState(() => _companyController.text = company),
            ),
          ],
          const Gap(Space.s4),
          AppDateField(
            label: 'Vencimiento del seguro',
            required: true,
            value: _expiry,
            onChanged: (date) => setState(() => _expiry = date),
          ),
          const Gap(Space.s5),
          Row(
            children: [
              const Expanded(child: FieldLabel('Vehículos')),
              Text(
                '$count de ${widget.vehicles.length}',
                style: AppText.caption.tabular.copyWith(color: c.textMuted),
              ),
              TextButton(
                onPressed: _toggleAll,
                child: Text(_allSelected ? 'Ninguno' : 'Todos'),
              ),
            ],
          ),
          for (final vehicle in widget.vehicles)
            _VehicleCheckTile(
              vehicle: vehicle,
              selected: _selected.contains(vehicle),
              onToggle: () => _toggle(vehicle),
            ),
        ],
      ),
    );
  }

  Widget _assignmentNotice(InsuranceAssignment? assignment) {
    if (assignment == null) {
      return const AppNotice(
        icon: Icons.event_rounded,
        message: 'Elegí la fecha de vencimiento para continuar',
      );
    }
    final count = _selected.length;
    if (count == 0) {
      return const AppNotice(
        tone: Tone.warning,
        icon: Icons.info_rounded,
        message: 'No hay vehículos tildados',
      );
    }
    final target = count == 1 ? '1 vehículo' : '$count vehículos';
    return AppNotice(
      icon: Icons.shield_rounded,
      message: assignment.changesCompany
          ? 'Se va a asignar "${assignment.label}" a $target'
          : 'Se va a actualizar el ${assignment.label} en $target. '
              'La compañía no cambia.',
    );
  }
}

/// Compañías ya cargadas en la flota, para completar el campo con un toque.
class _CompanySuggestions extends StatelessWidget {
  final List<String> companies;
  final String current;
  final ValueChanged<String> onSelected;

  const _CompanySuggestions({
    required this.companies,
    required this.current,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Space.s2,
      runSpacing: Space.s2,
      children: [
        for (final company in companies)
          ChoiceChip(
            label: Text(company),
            selected: company == current,
            onSelected: (_) => onSelected(company),
          ),
      ],
    );
  }
}

/// La fila de vehículo de siempre con un checkbox a la derecha y, al pie, el
/// seguro que tiene hoy. Toda la fila tilda y destilda.
class _VehicleCheckTile extends StatelessWidget {
  final Vehicle vehicle;
  final bool selected;
  final VoidCallback onToggle;

  const _VehicleCheckTile({
    required this.vehicle,
    required this.selected,
    required this.onToggle,
  });

  /// "Nación Seguros · vence el 28 sept 2026" / "Sin seguro cargado".
  String get _currentInsurance {
    final company = vehicle.insuranceCompany?.trim() ?? '';
    final expiry = vehicle.insuranceExpiry;
    if (company.isEmpty && expiry == null) return 'Sin seguro cargado';
    return [
      if (company.isNotEmpty) company,
      if (expiry != null)
        '${vehicle.isInsuranceExpired ? 'venció el' : 'vence el'} '
            '${AppFormats.date(expiry)}',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final status = vehicle.insuranceStatus;
    final insuranceColor =
        status.needsAttention ? status.tone.foreground(c) : c.textMuted;
    return MergeSemantics(
      child: VehicleListTile(
        vehicle: vehicle,
        contentPadding: VehicleListTile.inSheetPadding,
        showExpiryAlert: false,
        onTap: onToggle,
        trailing: Checkbox(value: selected, onChanged: (_) => onToggle()),
        footer: Text(
          _currentInsurance,
          style: AppText.caption.copyWith(color: insuranceColor),
        ),
      ),
    );
  }
}
