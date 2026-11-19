import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/provinces.dart';
import '../../core/constants/vehicle_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_tone.dart';
import '../../core/theme/app_typography.dart';
import '../../data/services/fleet_report_pdf.dart';
import '../../domain/fleet_summary.dart';
import '../../domain/models/vehicle.dart';
import '../providers/location_provider.dart';
import '../providers/vehicle_provider.dart';
import 'app_filter_chip.dart';
import 'app_notice.dart';
import 'app_sheet.dart';
import 'app_text_field.dart';
import 'location_filter_label.dart';
import 'pdf_export_flow.dart';

/// Abre el sheet de exportación del listado y, si el usuario confirma, genera
/// y comparte el PDF desde el [context] de la pantalla (el sheet ya se cerró).
Future<void> showFleetExportSheet(BuildContext context) async {
  final request = await showAppSheet<_FleetExportRequest>(
    context,
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
    final c = context.colors;
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

    return AppSheet(
      title: 'Exportar listado',
      footer: SizedBox(
        width: double.infinity,
        height: Sizes.controlH,
        child: FilledButton.icon(
          onPressed: selectedCount == 0
              ? null
              : () => _confirm(scopeVehicles, locationFilter),
          icon: const Icon(Icons.picture_as_pdf_rounded),
          label: const Text('Generar PDF'),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'PDF con el detalle de cada vehículo, ordenado por provincia.',
            style: AppText.body.copyWith(color: c.textMuted),
          ),
          const Gap(Space.s5),
          const FieldLabel('Estado'),
          const Gap(Space.s2),
          Wrap(
            spacing: Space.s2,
            runSpacing: Space.s2,
            children: [
              AppFilterChip(
                label: 'Todos',
                count: scopeVehicles.length,
                selected: _status == null,
                onTap: () => setState(() => _status = null),
              ),
              for (final status in VehicleStatus.values)
                AppFilterChip(
                  label: status.label,
                  count: counts[status] ?? 0,
                  selected: _status == status,
                  onTap: () => setState(() => _status = status),
                ),
            ],
          ),
          if (locationFilter.hasFilter) ...[
            const Gap(Space.s5),
            const FieldLabel('Alcance'),
            const Gap(Space.s2),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                const ButtonSegment(
                  value: false,
                  label: Text('Toda la flota'),
                ),
                ButtonSegment(
                  value: true,
                  // Hereda el estilo del segmento (seleccionado o no).
                  label: Builder(
                    builder: (context) => LocationFilterLabel(
                      locationFilter: locationFilter,
                      prefix: 'Solo ',
                      textAlign: TextAlign.center,
                      style: DefaultTextStyle.of(context).style,
                    ),
                  ),
                ),
              ],
              selected: {_onlyFilteredLocation},
              onSelectionChanged: (selection) =>
                  setState(() => _onlyFilteredLocation = selection.first),
            ),
          ],
          const Gap(Space.s5),
          AppNotice(
            tone: selectedCount == 0 ? Tone.warning : Tone.info,
            icon: selectedCount == 0
                ? Icons.info_rounded
                : Icons.description_rounded,
            message: _previewMessage(selectedCount),
          ),
        ],
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
