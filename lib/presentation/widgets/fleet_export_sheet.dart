import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/provinces.dart';
import '../../core/constants/vehicle_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/fleet_report_pdf.dart';
import '../../domain/fleet_summary.dart';
import '../../domain/models/vehicle.dart';
import '../providers/location_provider.dart';
import '../providers/vehicle_provider.dart';
import 'location_filter_label.dart';
import 'pdf_export_flow.dart';
import 'sheet_notice.dart';
import 'status_filter_chip.dart';

/// Abre el sheet de exportación del listado y, si el usuario confirma, genera
/// y comparte el PDF desde el [context] de la pantalla (el sheet ya se cerró).
Future<void> showFleetExportSheet(BuildContext context) async {
  final request = await showModalBottomSheet<_FleetExportRequest>(
    context: context,
    backgroundColor: AppTheme.surface,
    isScrollControlled: true,
    // Sobre el navigator raíz para tapar el FAB del shell.
    useRootNavigator: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _FleetExportSheet(),
  );
  if (request == null || !context.mounted) return;

  final count = request.vehicles.length;
  await runPdfExport(
    context,
    progressTitle: 'Generando el listado…',
    progressSubtitle: count == 1
        ? 'Armando el PDF con 1 vehículo'
        : 'Armando el PDF con $count vehículos',
    fileName: request.scope.fileName(DateTime.now()),
    successMessage: 'Listado exportado',
    errorMessage: 'No se pudo generar el listado. Probá de nuevo.',
    generate: () => FleetReportPdf.generate(
      vehicles: request.vehicles,
      scope: request.scope,
    ),
  );
}

class _FleetExportRequest {
  final List<Vehicle> vehicles;
  final FleetReportScope scope;

  const _FleetExportRequest(this.vehicles, this.scope);
}

class _FleetExportSheet extends ConsumerStatefulWidget {
  const _FleetExportSheet();

  @override
  ConsumerState<_FleetExportSheet> createState() => _FleetExportSheetState();
}

class _FleetExportSheetState extends ConsumerState<_FleetExportSheet> {
  VehicleStatus? _status;
  bool _onlyFilteredLocation = false;

  @override
  Widget build(BuildContext context) {
    final locationFilter = ref.watch(locationFilterProvider);
    final allVehicles =
        ref.watch(vehicleNotifierProvider).valueOrNull ?? const <Vehicle>[];
    final locationVehicles =
        ref.watch(vehiclesByLocationFilterProvider).valueOrNull ??
            const <Vehicle>[];
    final scopeVehicles = _onlyFilteredLocation && locationFilter.hasFilter
        ? locationVehicles
        : allVehicles;
    final counts = FleetSummary.countByStatus(scopeVehicles);
    final selectedCount =
        _status == null ? scopeVehicles.length : (counts[_status] ?? 0);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Exportar listado',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            const Text(
              'PDF con el detalle de cada vehículo, ordenado por provincia.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            const _SectionLabel('Estado'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusFilterChip(
                  label: 'Todos',
                  count: scopeVehicles.length,
                  isSelected: _status == null,
                  onTap: () => setState(() => _status = null),
                ),
                for (final status in VehicleStatus.values)
                  StatusFilterChip(
                    label: status.label,
                    color: status.color,
                    count: counts[status] ?? 0,
                    isSelected: _status == status,
                    onTap: () => setState(() => _status = status),
                  ),
              ],
            ),
            if (locationFilter.hasFilter) ...[
              const SizedBox(height: 20),
              const _SectionLabel('Alcance'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ScopeOption(
                      isSelected: !_onlyFilteredLocation,
                      onTap: () =>
                          setState(() => _onlyFilteredLocation = false),
                      child: Text(
                        'Toda la flota',
                        textAlign: TextAlign.center,
                        style: _optionStyle(!_onlyFilteredLocation),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ScopeOption(
                      isSelected: _onlyFilteredLocation,
                      onTap: () =>
                          setState(() => _onlyFilteredLocation = true),
                      child: LocationFilterLabel(
                        locationFilter: locationFilter,
                        prefix: 'Solo ',
                        textAlign: TextAlign.center,
                        style: _optionStyle(_onlyFilteredLocation),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            SheetNotice(
              icon: selectedCount == 0
                  ? Icons.info_outline
                  : Icons.description_outlined,
              message: _previewMessage(selectedCount),
              isWarning: selectedCount == 0,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: selectedCount == 0
                    ? null
                    : () => _confirm(scopeVehicles, locationFilter),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Generar PDF'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "Se van a exportar 12 vehículos" o aviso de que el filtro quedó vacío.
  static String _previewMessage(int count) {
    if (count == 0) return 'No hay vehículos para exportar con este filtro';
    return count == 1
        ? 'Se va a exportar 1 vehículo'
        : 'Se van a exportar $count vehículos';
  }

  TextStyle _optionStyle(bool isSelected) => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isSelected ? AppTheme.accentPrimary : AppTheme.textSecondary,
      );

  Future<void> _confirm(
      List<Vehicle> scopeVehicles, LocationFilter locationFilter) async {
    final status = _status;
    final vehicles = status == null
        ? scopeVehicles
        : scopeVehicles.where((vehicle) => vehicle.status == status).toList();
    final locationLabel = _onlyFilteredLocation && locationFilter.hasFilter
        ? await _describeLocation(locationFilter)
        : null;
    if (!mounted) return;
    Navigator.pop(
      context,
      _FleetExportRequest(
        vehicles,
        FleetReportScope(status: status, locationLabel: locationLabel),
      ),
    );
  }

  /// "Buenos Aires > La Plata > Depósito Norte" según lo que esté filtrado.
  Future<String> _describeLocation(LocationFilter filter) async {
    final repository = ref.read(locationRepositoryProvider);
    final parts = <String>[];
    final provinceId = filter.provinceId;
    if (provinceId != null) {
      parts.add(ArgentinaProvinces.getById(provinceId).name);
    }
    final cityId = filter.cityId;
    if (cityId != null) {
      final city = await repository.getCityById(cityId);
      if (city != null) parts.add(city.name);
    }
    final lugarId = filter.lugarId;
    if (lugarId != null) {
      final lugar = await repository.getLugarById(lugarId);
      if (lugar != null) parts.add(lugar.name);
    }
    return parts.join(' > ');
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      );
}

class _ScopeOption extends StatelessWidget {
  final Widget child;
  final bool isSelected;
  final VoidCallback onTap;

  const _ScopeOption({
    required this.child,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentPrimary.withValues(alpha: 0.2)
              : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.accentPrimary : AppTheme.border,
          ),
        ),
        child: child,
      ),
    );
  }
}
