import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/fleet_insurance.dart';
import '../../domain/models/vehicle.dart';
import '../providers/vehicle_provider.dart';
import 'date_picker_field.dart';
import 'sheet_notice.dart';

/// Abre el sheet para asignar un mismo seguro (compañía + vencimiento) a los
/// vehículos que queden tildados y, si el usuario confirma, aplica los cambios
/// uno por uno mostrando el progreso. Los destildados conservan su seguro.
Future<void> showFleetInsuranceSheet(
    BuildContext context, WidgetRef ref) async {
  final vehicles = ref.read(vehicleNotifierProvider).valueOrNull;
  if (vehicles == null || vehicles.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No hay vehículos cargados')),
    );
    return;
  }

  final request = await showModalBottomSheet<_InsuranceRequest>(
    context: context,
    isScrollControlled: true,
    // Sobre el navigator raíz para tapar el FAB y la bottom bar del shell.
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Los vehículos seleccionados ya tienen ese seguro')),
    );
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
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(_resultMessage(
        updated: updates.length - failed,
        skipped: skipped,
        failed: failed,
      )),
      backgroundColor: failed == 0 ? AppTheme.success : AppTheme.warning,
    ),
  );
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
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      backgroundColor: AppTheme.surface,
      content: ValueListenableBuilder<int>(
        valueListenable: progress,
        builder: (_, done, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: done / total,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 20),
            const Text('Actualizando seguro...',
                style: TextStyle(color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(
              '$done de $total vehículos',
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    ),
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

  @override
  Widget build(BuildContext context) {
    final assignment = _assignment;
    final canSave = assignment != null && _selected.isNotEmpty;

    // El padding inferior acompaña al teclado para que el campo de compañía
    // no quede tapado mientras se escribe.
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seguro de la flota',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'La compañía y el vencimiento se asignan a los vehículos '
                        'tildados. Los destildados conservan su seguro.',
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _companyController,
                        textCapitalization: TextCapitalization.words,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Compañía de seguro',
                          hintText: 'Dejá vacío para no cambiarla',
                          prefixIcon: Icon(Icons.security),
                        ),
                      ),
                      if (_knownCompanies.length > 1) ...[
                        const SizedBox(height: 8),
                        _CompanySuggestions(
                          companies: _knownCompanies
                              .take(_maxSuggestedCompanies)
                              .toList(),
                          current: _companyController.text.trim(),
                          onSelected: (company) => setState(
                              () => _companyController.text = company),
                        ),
                      ],
                      const SizedBox(height: 12),
                      DatePickerField(
                        label: 'Vencimiento del seguro',
                        value: _expiry,
                        onChanged: (date) => setState(() => _expiry = date),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text(
                            'Vehículos',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_selected.length} de ${widget.vehicles.length}',
                            style: const TextStyle(
                                fontSize: 13, color: AppTheme.textSecondary),
                          ),
                          TextButton(
                            onPressed: _toggleAll,
                            child: Text(_allSelected ? 'Ninguno' : 'Todos'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: widget.vehicles.length,
                    itemBuilder: (context, index) {
                      final vehicle = widget.vehicles[index];
                      return _VehicleCheckTile(
                        vehicle: vehicle,
                        selected: _selected.contains(vehicle),
                        onToggle: () => _toggle(vehicle),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                    children: [
                      _assignmentNotice(assignment),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: canSave ? _confirm : null,
                          icon: const Icon(Icons.check),
                          label: const Text('Guardar seguro'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _assignmentNotice(InsuranceAssignment? assignment) {
    if (assignment == null) {
      return const SheetNotice(
        icon: Icons.event_outlined,
        message: 'Elegí la fecha de vencimiento para continuar',
      );
    }
    final count = _selected.length;
    if (count == 0) {
      return const SheetNotice(
        icon: Icons.info_outline,
        message: 'No hay vehículos seleccionados',
        isWarning: true,
      );
    }
    final target = count == 1 ? '1 vehículo' : '$count vehículos';
    return SheetNotice(
      icon: Icons.security,
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
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final company in companies)
          ActionChip(
            label: Text(company, style: const TextStyle(fontSize: 12)),
            visualDensity: VisualDensity.compact,
            side: BorderSide(
              color: company == current
                  ? AppTheme.accentPrimary
                  : AppTheme.border,
            ),
            onPressed: () => onSelected(company),
          ),
      ],
    );
  }
}

class _VehicleCheckTile extends StatelessWidget {
  final Vehicle vehicle;
  final bool selected;
  final VoidCallback onToggle;

  const _VehicleCheckTile({
    required this.vehicle,
    required this.selected,
    required this.onToggle,
  });

  static final _dateFormat = DateFormat('dd/MM/yyyy');

  /// "Nación Seguros · vence 28/09/2026" / "Sin seguro cargado".
  String get _currentInsurance {
    final company = vehicle.insuranceCompany?.trim() ?? '';
    final expiry = vehicle.insuranceExpiry;
    if (company.isEmpty && expiry == null) return 'Sin seguro cargado';
    return [
      if (company.isNotEmpty) company,
      if (expiry != null)
        '${vehicle.isInsuranceExpired ? 'venció' : 'vence'} '
            '${_dateFormat.format(expiry)}',
    ].join(' · ');
  }

  Color get _currentInsuranceColor {
    if (vehicle.isInsuranceExpired) return AppTheme.error;
    if (vehicle.isInsuranceExpiringSoon) return AppTheme.warning;
    return AppTheme.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: selected,
      onChanged: (_) => onToggle(),
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: AppTheme.accentPrimary,
      checkColor: AppTheme.background,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      title: Row(
        children: [
          Expanded(
            child: Text(
              vehicle.displayName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: selected ? AppTheme.textPrimary : AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            vehicle.plate,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.accentPrimary,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
      subtitle: Text(
        _currentInsurance,
        style: TextStyle(fontSize: 12, color: _currentInsuranceColor),
      ),
    );
  }
}
