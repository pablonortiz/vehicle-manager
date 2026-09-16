import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../widgets/error_retry_view.dart';
import '../../core/config/supabase_config.dart';
import '../../core/constants/provinces.dart';
import '../../core/constants/vehicle_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/sync_service.dart';
import '../../domain/fleet_summary.dart';
import '../../domain/models/vehicle.dart';
import '../providers/vehicle_provider.dart';
import '../providers/location_provider.dart';
import '../widgets/fleet_export_sheet.dart';
import '../widgets/location_filter_label.dart';
import '../widgets/status_filter_chip.dart';
import '../widgets/vehicle_icon.dart';
import '../widgets/hierarchical_filter_sheet.dart';

class VehiclesScreen extends ConsumerStatefulWidget {
  final int? provinceId;

  const VehiclesScreen({super.key, this.provinceId});

  @override
  ConsumerState<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends ConsumerState<VehiclesScreen> {
  // Una key por chip de estado para poder traer a la vista el seleccionado:
  // al llegar desde la Home ya filtrado, el chip activo puede quedar fuera
  // del scroll horizontal y el filtro parecería invisible.
  final _statusChipKeys = {
    for (final status in VehicleStatus.values) status: GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.provinceId != null) {
        ref.read(locationFilterProvider.notifier).setProvince(widget.provinceId);
      }
      _revealStatusChip(ref.read(statusFilterProvider));
    });
  }

  void _revealStatusChip(VehicleStatus? status) {
    final chipContext = _statusChipKeys[status]?.currentContext;
    if (chipContext == null) return;
    Scrollable.ensureVisible(
      chipContext,
      alignment: 0.5,
      duration: const Duration(milliseconds: 250),
    );
  }

  Future<void> _onRefresh() async {
    if (SupabaseConfig.isConfigured) {
      await ref.read(syncServiceProvider.notifier).fullSync();
    }
    await ref.read(vehicleNotifierProvider.notifier).refresh();
  }

  void _setStatusFilter(VehicleStatus? status) {
    ref.read(statusFilterProvider.notifier).state = status;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(statusFilterProvider, (_, status) => _revealStatusChip(status));
    final locationFilter = ref.watch(locationFilterProvider);
    final statusFilter = ref.watch(statusFilterProvider);
    final vehiclesAsync = ref.watch(vehiclesByLocationFilterProvider);
    // Conteos por estado dentro de la ubicación filtrada, para los chips.
    final statusCounts = FleetSummary.countByStatus(
        vehiclesAsync.valueOrNull ?? const <Vehicle>[]);
    final hasAnyVehicle =
        ref.watch(vehicleNotifierProvider).valueOrNull?.isNotEmpty ?? false;

    // El refresco post-sync ya ocurre solo: replaceAllData emite notifyChange,
    // que dispara la subscription del notifier (y vehiclesByLocationFilterProvider
    // deriva de él). No hace falta invalidar manualmente.

    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vehículos',
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      if (locationFilter.hasFilter)
                        LocationFilterLabel(locationFilter: locationFilter),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: hasAnyVehicle
                          ? () => showFleetExportSheet(context)
                          : null,
                      tooltip: 'Exportar listado',
                      color: AppTheme.accentPrimary,
                      disabledColor: AppTheme.textSecondary.withValues(alpha: 0.4),
                      icon: const Icon(Icons.picture_as_pdf),
                    ),
                    IconButton(
                      onPressed: () => context.push('/search'),
                      icon: const Icon(Icons.search, color: AppTheme.accentPrimary),
                    ),
                    IconButton(
                      onPressed: () => showHierarchicalFilterSheet(context),
                      icon: Badge(
                        isLabelVisible: locationFilter.hasFilter || statusFilter != null,
                        child: const Icon(Icons.filter_list, color: AppTheme.accentPrimary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Status filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                StatusFilterChip(
                  label: 'Todos',
                  count: vehiclesAsync.valueOrNull?.length,
                  isSelected: statusFilter == null,
                  onTap: () => _setStatusFilter(null),
                ),
                const SizedBox(width: 8),
                ...VehicleStatus.values.map((status) => Padding(
                  key: _statusChipKeys[status],
                  padding: const EdgeInsets.only(right: 8),
                  child: StatusFilterChip(
                    label: status.label,
                    count: vehiclesAsync.hasValue ? (statusCounts[status] ?? 0) : null,
                    isSelected: statusFilter == status,
                    color: status.color,
                    onTap: () => _setStatusFilter(status),
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Vehicle list
          Expanded(
            child: vehiclesAsync.when(
              data: (vehicles) {
                // Aplicar filtro de estado
                final filteredVehicles = statusFilter == null
                    ? vehicles
                    : vehicles.where((v) => v.status == statusFilter).toList();

                if (filteredVehicles.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _onRefresh,
                    color: AppTheme.accentPrimary,
                    child: ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: _EmptyState(
                            hasFilter: locationFilter.hasFilter || statusFilter != null,
                            onClearFilters: () {
                              ref.read(locationFilterProvider.notifier).clearAll();
                              _setStatusFilter(null);
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _onRefresh,
                  color: AppTheme.accentPrimary,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: filteredVehicles.length,
                    itemBuilder: (context, index) {
                      final vehicle = filteredVehicles[index];
                      return _VehicleCard(
                        vehicle: vehicle,
                        onTap: () => context.push('/vehicle/${vehicle.id}'),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorRetryView(
                message: 'No se pudieron cargar los vehículos',
                onRetry: () => ref.read(vehicleNotifierProvider.notifier).refresh(),
              ),
            ),
          ),
        ],
      ),
    );
  }

}

class _VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final VoidCallback onTap;

  const _VehicleCard({
    required this.vehicle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final province = ArgentinaProvinces.getById(vehicle.provinceId);
    final hasWarning = vehicle.isVtvExpiringSoon || 
                       vehicle.isInsuranceExpiringSoon ||
                       vehicle.isVtvExpired ||
                       vehicle.isInsuranceExpired;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasWarning 
                ? AppTheme.warning.withValues(alpha: 0.5)
                : AppTheme.border,
          ),
        ),
        child: Row(
          children: [
            VehicleIcon(
              type: vehicle.type,
              vehicleColor: vehicle.color,
              status: vehicle.status,
              size: 56,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          vehicle.displayName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      if (hasWarning)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 18,
                              color: vehicle.isVtvExpired || vehicle.isInsuranceExpired
                                  ? AppTheme.error
                                  : AppTheme.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              vehicle.expiringDocuments
                                  .map((d) => d.label)
                                  .join(' · '),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: vehicle.isVtvExpired || vehicle.isInsuranceExpired
                                    ? AppTheme.error
                                    : AppTheme.warning,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    vehicle.plate,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.accentPrimary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${vehicle.city}, ${province.abbreviation}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.person_outline,
                        size: 14,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          vehicle.responsibleName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasFilter;
  final VoidCallback onClearFilters;

  const _EmptyState({
    required this.hasFilter,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFilter ? Icons.filter_alt_off : Icons.directions_car_outlined,
              size: 64,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              hasFilter 
                  ? 'No hay vehículos con estos filtros'
                  : 'No hay vehículos registrados',
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (hasFilter)
              OutlinedButton(
                onPressed: onClearFilters,
                child: const Text('Limpiar filtros'),
              )
            else
              ElevatedButton.icon(
                onPressed: () => context.push('/vehicle/new'),
                icon: const Icon(Icons.add),
                label: const Text('Agregar vehículo'),
              ),
          ],
        ),
      ),
    );
  }
}
