import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/provinces.dart';
import '../../domain/models/city.dart';
import '../../domain/models/lugar.dart';
import '../providers/location_provider.dart';
import '../providers/vehicle_provider.dart';

/// A bottom sheet widget for hierarchical location filtering.
/// Province -> City -> Lugar
class HierarchicalFilterSheet extends ConsumerStatefulWidget {
  const HierarchicalFilterSheet({super.key});

  @override
  ConsumerState<HierarchicalFilterSheet> createState() => _HierarchicalFilterSheetState();
}

class _HierarchicalFilterSheetState extends ConsumerState<HierarchicalFilterSheet> {
  @override
  Widget build(BuildContext context) {
    final locationFilter = ref.watch(locationFilterProvider);
    final vehicleCountsAsync = ref.watch(vehicleCountByProvinceProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title and clear button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filtrar por ubicacion',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (locationFilter.hasFilter)
                      TextButton(
                        onPressed: () {
                          ref.read(locationFilterProvider.notifier).clearAll();
                        },
                        child: const Text('Limpiar'),
                      ),
                  ],
                ),
              ),

              // Active filter chips
              if (locationFilter.hasFilter)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _ActiveFilterChips(locationFilter: locationFilter),
                ),

              const Divider(),

              // Filter content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // Province section
                    _SectionHeader(
                      title: 'Provincia',
                      isSelected: locationFilter.provinceId != null,
                      onClear: locationFilter.provinceId != null
                          ? () => ref.read(locationFilterProvider.notifier).setProvince(null)
                          : null,
                    ),
                    vehicleCountsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (_, __) => const Text('Error cargando provincias'),
                      data: (counts) => _ProvinceList(
                        selectedProvinceId: locationFilter.provinceId,
                        vehicleCounts: counts,
                        onSelected: (provinceId) {
                          ref.read(locationFilterProvider.notifier).setProvince(provinceId);
                        },
                      ),
                    ),

                    // City section (only shown if province is selected)
                    if (locationFilter.provinceId != null) ...[
                      const SizedBox(height: 16),
                      _SectionHeader(
                        title: 'Ciudad',
                        isSelected: locationFilter.cityId != null,
                        onClear: locationFilter.cityId != null
                            ? () => ref.read(locationFilterProvider.notifier).clearCity()
                            : null,
                      ),
                      _CityList(
                        provinceId: locationFilter.provinceId!,
                        selectedCityId: locationFilter.cityId,
                        onSelected: (cityId) {
                          ref.read(locationFilterProvider.notifier).setCity(cityId);
                        },
                      ),
                    ],

                    // Lugar section (only shown if city is selected)
                    if (locationFilter.cityId != null) ...[
                      const SizedBox(height: 16),
                      _SectionHeader(
                        title: 'Lugar',
                        isSelected: locationFilter.lugarId != null,
                        onClear: locationFilter.lugarId != null
                            ? () => ref.read(locationFilterProvider.notifier).clearLugar()
                            : null,
                      ),
                      _LugarList(
                        cityId: locationFilter.cityId!,
                        selectedLugarId: locationFilter.lugarId,
                        onSelected: (lugarId) {
                          ref.read(locationFilterProvider.notifier).setLugar(lugarId);
                        },
                      ),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback? onClear;

  const _SectionHeader({
    required this.title,
    required this.isSelected,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (onClear != null)
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              onPressed: onClear,
              tooltip: 'Limpiar $title',
            ),
        ],
      ),
    );
  }
}

class _ActiveFilterChips extends ConsumerWidget {
  final LocationFilter locationFilter;

  const _ActiveFilterChips({required this.locationFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        if (locationFilter.provinceId != null)
          Chip(
            label: Text(ArgentinaProvinces.getById(locationFilter.provinceId!).name),
            deleteIcon: const Icon(Icons.close, size: 16),
            onDeleted: () => ref.read(locationFilterProvider.notifier).setProvince(null),
          ),
        if (locationFilter.cityId != null)
          Consumer(
            builder: (context, ref, _) {
              final cityAsync = ref.watch(cityByIdProvider(locationFilter.cityId!));
              return cityAsync.when(
                loading: () => const Chip(label: Text('...')),
                error: (_, __) => const SizedBox.shrink(),
                data: (city) => city != null
                    ? Chip(
                        label: Text(city.name),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => ref.read(locationFilterProvider.notifier).clearCity(),
                      )
                    : const SizedBox.shrink(),
              );
            },
          ),
        if (locationFilter.lugarId != null)
          Consumer(
            builder: (context, ref, _) {
              final lugarAsync = ref.watch(lugarByIdProvider(locationFilter.lugarId!));
              return lugarAsync.when(
                loading: () => const Chip(label: Text('...')),
                error: (_, __) => const SizedBox.shrink(),
                data: (lugar) => lugar != null
                    ? Chip(
                        label: Text(lugar.name),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => ref.read(locationFilterProvider.notifier).clearLugar(),
                      )
                    : const SizedBox.shrink(),
              );
            },
          ),
      ],
    );
  }
}

class _ProvinceList extends StatelessWidget {
  final int? selectedProvinceId;
  final Map<int, int> vehicleCounts;
  final void Function(int) onSelected;

  const _ProvinceList({
    required this.selectedProvinceId,
    required this.vehicleCounts,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Only show provinces that have vehicles
    final provincesWithVehicles = ArgentinaProvinces.all
        .where((p) => vehicleCounts.containsKey(p.id))
        .toList();

    if (provincesWithVehicles.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No hay vehiculos registrados'),
      );
    }

    return Column(
      children: provincesWithVehicles.map((province) {
        final count = vehicleCounts[province.id] ?? 0;
        final isSelected = selectedProvinceId == province.id;

        return ListTile(
          dense: true,
          selected: isSelected,
          leading: Icon(
            isSelected ? Icons.check_circle : Icons.circle_outlined,
            color: isSelected ? Theme.of(context).colorScheme.primary : null,
          ),
          title: Text(province.name),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          onTap: () => onSelected(province.id),
        );
      }).toList(),
    );
  }
}

class _CityList extends ConsumerWidget {
  final int provinceId;
  final String? selectedCityId;
  final void Function(String) onSelected;

  const _CityList({
    required this.provinceId,
    required this.selectedCityId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final citiesAsync = ref.watch(citiesByProvinceProvider(provinceId));
    final countsAsync = ref.watch(vehicleCountByCityProvider(provinceId));

    return citiesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Text('Error cargando ciudades'),
      data: (cities) {
        if (cities.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No hay ciudades registradas en esta provincia'),
          );
        }

        return countsAsync.when(
          loading: () => _buildCityList(context, cities, {}, selectedCityId, onSelected),
          error: (_, __) => _buildCityList(context, cities, {}, selectedCityId, onSelected),
          data: (counts) => _buildCityList(context, cities, counts, selectedCityId, onSelected),
        );
      },
    );
  }

  Widget _buildCityList(
    BuildContext context,
    List<City> cities,
    Map<String, int> counts,
    String? selectedCityId,
    void Function(String) onSelected,
  ) {
    return Column(
      children: cities.map((city) {
        final count = counts[city.id] ?? 0;
        final isSelected = selectedCityId == city.id;

        return ListTile(
          dense: true,
          selected: isSelected,
          leading: Icon(
            isSelected ? Icons.check_circle : Icons.circle_outlined,
            color: isSelected ? Theme.of(context).colorScheme.primary : null,
          ),
          title: Text(city.name),
          trailing: count > 0
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                )
              : null,
          onTap: () => onSelected(city.id!),
        );
      }).toList(),
    );
  }
}

class _LugarList extends ConsumerWidget {
  final String cityId;
  final String? selectedLugarId;
  final void Function(String) onSelected;

  const _LugarList({
    required this.cityId,
    required this.selectedLugarId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lugaresAsync = ref.watch(lugaresByCityProvider(cityId));
    final countsAsync = ref.watch(vehicleCountByLugarProvider(cityId));

    return lugaresAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Text('Error cargando lugares'),
      data: (lugares) {
        if (lugares.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No hay lugares registrados en esta ciudad'),
          );
        }

        return countsAsync.when(
          loading: () => _buildLugarList(context, lugares, {}, selectedLugarId, onSelected),
          error: (_, __) => _buildLugarList(context, lugares, {}, selectedLugarId, onSelected),
          data: (counts) => _buildLugarList(context, lugares, counts, selectedLugarId, onSelected),
        );
      },
    );
  }

  Widget _buildLugarList(
    BuildContext context,
    List<Lugar> lugares,
    Map<String, int> counts,
    String? selectedLugarId,
    void Function(String) onSelected,
  ) {
    return Column(
      children: lugares.map((lugar) {
        final count = counts[lugar.id] ?? 0;
        final isSelected = selectedLugarId == lugar.id;

        return ListTile(
          dense: true,
          selected: isSelected,
          leading: Icon(
            isSelected ? Icons.check_circle : Icons.circle_outlined,
            color: isSelected ? Theme.of(context).colorScheme.primary : null,
          ),
          title: Text(lugar.name),
          trailing: count > 0
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                  ),
                )
              : null,
          onTap: () => onSelected(lugar.id!),
        );
      }).toList(),
    );
  }
}

/// Helper function to show the hierarchical filter sheet
Future<void> showHierarchicalFilterSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const HierarchicalFilterSheet(),
  );
}
