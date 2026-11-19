import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/supabase_config.dart';
import '../../core/constants/vehicle_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_tone.dart';
import '../../data/services/sync_service.dart';
import '../../domain/fleet_summary.dart';
import '../../domain/models/vehicle.dart';
import '../providers/location_provider.dart';
import '../providers/vehicle_provider.dart';
import '../widgets/app_card.dart';
import '../widgets/app_filter_chip.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_retry_view.dart';
import '../widgets/fleet_export_sheet.dart';
import '../widgets/hierarchical_filter_sheet.dart';
import '../widgets/location_filter_label.dart';
import '../widgets/root_app_bar.dart';
import '../widgets/status_pill.dart';
import '../widgets/vehicle_list_tile.dart';

class VehiclesScreen extends ConsumerStatefulWidget {
  final int? provinceId;

  const VehiclesScreen({super.key, this.provinceId});

  @override
  ConsumerState<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends ConsumerState<VehiclesScreen> {
  // Una key por chip de estado para traer a la vista el seleccionado: al
  // llegar desde Inicio ya filtrado, el chip activo puede quedar fuera del
  // scroll horizontal y el filtro parecería invisible.
  final _statusChipKeys = {
    for (final status in VehicleStatus.values) status: GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.provinceId != null) {
        ref
            .read(locationFilterProvider.notifier)
            .setProvince(widget.provinceId);
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
      duration: Motion.short,
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

  void _clearFilters() {
    ref.read(locationFilterProvider.notifier).clearAll();
    _setStatusFilter(null);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(statusFilterProvider, (_, status) => _revealStatusChip(status));
    final locationFilter = ref.watch(locationFilterProvider);
    final statusFilter = ref.watch(statusFilterProvider);
    final vehiclesAsync = ref.watch(vehiclesByLocationFilterProvider);
    final hasAnyVehicle =
        ref.watch(vehicleNotifierProvider).valueOrNull?.isNotEmpty ?? false;

    return Scaffold(
      appBar: RootAppBar(
        title: 'Vehículos',
        actions: [
          IconButton(
            tooltip: 'Buscar',
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            tooltip: 'Filtrar por ubicación',
            onPressed: () => showHierarchicalFilterSheet(context),
            icon: Badge(
              isLabelVisible: locationFilter.hasFilter,
              child: const Icon(Icons.filter_list_rounded),
            ),
          ),
          PopupMenuButton<VoidCallback>(
            tooltip: 'Más opciones',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (action) => action(),
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: hasAnyVehicle,
                value: () => showFleetExportSheet(context),
                child: const ListTile(
                  leading: Icon(Icons.picture_as_pdf_rounded),
                  title: Text('Exportar listado'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (locationFilter.hasFilter)
            _LocationBar(filter: locationFilter, onClear: _clearLocation),
          _StatusChips(
            vehicles: vehiclesAsync.valueOrNull,
            selected: statusFilter,
            chipKeys: _statusChipKeys,
            onSelect: _setStatusFilter,
          ),
          Expanded(
            child: vehiclesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => ErrorRetryView(
                message: 'No se pudieron cargar los vehículos',
                onRetry: () =>
                    ref.read(vehicleNotifierProvider.notifier).refresh(),
              ),
              data: (vehicles) => RefreshIndicator(
                onRefresh: _onRefresh,
                child: _VehicleList(
                  vehicles: statusFilter == null
                      ? vehicles
                      : vehicles
                            .where((vehicle) => vehicle.status == statusFilter)
                            .toList(),
                  hasFilter: locationFilter.hasFilter || statusFilter != null,
                  onClearFilters: _clearFilters,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _clearLocation() => ref.read(locationFilterProvider.notifier).clearAll();
}

class _LocationBar extends StatelessWidget {
  final LocationFilter filter;
  final VoidCallback onClear;

  const _LocationBar({required this.filter, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(left: Space.s5, right: Space.s2),
      child: Row(
        children: [
          Icon(Icons.place_rounded, size: Sizes.iconSm, color: c.accent),
          const Gap(Space.s1),
          Expanded(child: LocationFilterLabel(locationFilter: filter)),
          TextButton(onPressed: onClear, child: const Text('Quitar')),
        ],
      ),
    );
  }
}

class _StatusChips extends StatelessWidget {
  final List<Vehicle>? vehicles;
  final VehicleStatus? selected;
  final Map<VehicleStatus, GlobalKey> chipKeys;
  final ValueChanged<VehicleStatus?> onSelect;

  const _StatusChips({
    required this.vehicles,
    required this.selected,
    required this.chipKeys,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final loaded = vehicles;
    final counts = FleetSummary.countByStatus(loaded ?? const <Vehicle>[]);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Space.s5),
      child: Row(
        children: [
          AppFilterChip(
            label: 'Todos',
            count: loaded?.length,
            selected: selected == null,
            onTap: () => onSelect(null),
          ),
          for (final status in VehicleStatus.values)
            Padding(
              key: chipKeys[status],
              padding: const EdgeInsets.only(left: Space.s2),
              child: AppFilterChip(
                label: status.label,
                count: loaded == null ? null : counts[status] ?? 0,
                selected: selected == status,
                onTap: () => onSelect(status),
              ),
            ),
        ],
      ),
    );
  }
}

class _VehicleList extends StatelessWidget {
  final List<Vehicle> vehicles;
  final bool hasFilter;
  final VoidCallback onClearFilters;

  const _VehicleList({
    required this.vehicles,
    required this.hasFilter,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    if (vehicles.isEmpty) {
      return ListView(
        children: [
          hasFilter
              ? EmptyState(
                  icon: Icons.filter_alt_off_rounded,
                  title: 'Ningún vehículo coincide',
                  message: 'Probá con otro estado o ubicación.',
                  actionLabel: 'Limpiar filtros',
                  onAction: onClearFilters,
                  primaryAction: false,
                )
              : EmptyState(
                  icon: Icons.directions_car_rounded,
                  title: 'Todavía no hay vehículos',
                  actionLabel: 'Agregar vehículo',
                  onAction: () => context.push('/vehicle/new'),
                  tone: Tone.neutral,
                ),
        ],
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      // Aire al final para que el FAB no tape la última fila.
      padding: const EdgeInsets.fromLTRB(
        Space.s5,
        Space.s2,
        Space.s5,
        Space.s10 + Space.s10,
      ),
      children: [
        AppCard.list(
          children: [
            for (final vehicle in vehicles)
              VehicleListTile(
                vehicle: vehicle,
                trailing: StatusPill.vehicle(vehicle.status),
                onTap: () => context.push('/vehicle/${vehicle.id}'),
              ),
          ],
        ),
      ],
    );
  }
}
