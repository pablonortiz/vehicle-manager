import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/supabase_config.dart';
import '../../core/constants/provinces.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/sync_service.dart';
import '../../domain/models/city.dart';
import '../providers/vehicle_provider.dart';
import '../providers/location_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleCountAsync = ref.watch(vehicleCountByProvinceProvider);
    final totalCountAsync = ref.watch(totalVehicleCountProvider);
    final expiringAsync = ref.watch(expiringDocumentsProvider);
    final syncState = ref.watch(syncServiceProvider);

    // Listen for sync completion and refresh data automatically
    ref.listen<SyncState>(syncServiceProvider, (previous, next) {
      if (previous?.status == SyncStatus.syncing &&
          next.status == SyncStatus.success) {
        // Sync completed successfully - refresh all data providers
        ref.invalidate(vehicleCountByProvinceProvider);
        ref.invalidate(totalVehicleCountProvider);
        ref.invalidate(expiringDocumentsProvider);
        ref.invalidate(vehicleNotifierProvider);
      }
    });

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          if (SupabaseConfig.isConfigured) {
            await ref.read(syncServiceProvider.notifier).fullSync();
          }
          ref.invalidate(vehicleCountByProvinceProvider);
          ref.invalidate(totalVehicleCountProvider);
          ref.invalidate(expiringDocumentsProvider);
          await ref.read(vehicleNotifierProvider.notifier).refresh();
        },
        color: AppTheme.accentPrimary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gestor de',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const Text(
                              'Vehículos',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                                letterSpacing: -1,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            // Indicador de sincronización
                            if (syncState.status == SyncStatus.syncing)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                child: const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.accentPrimary,
                                  ),
                                ),
                              ),
                            if (syncState.status == SyncStatus.offline)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.warning.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.cloud_off, size: 16, color: AppTheme.warning),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Offline',
                                      style: TextStyle(fontSize: 12, color: AppTheme.warning),
                                    ),
                                  ],
                                ),
                              ),
                            IconButton(
                              onPressed: () => context.push('/search'),
                              icon: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: const Icon(
                                  Icons.search,
                                  color: AppTheme.accentPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Estadísticas rápidas
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'Total Vehículos',
                            value: totalCountAsync.when(
                              data: (count) => count.toString(),
                              loading: () => '...',
                              error: (_, __) => '0',
                            ),
                            icon: Icons.directions_car,
                            color: AppTheme.accentPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            title: 'Por Vencer',
                            value: expiringAsync.when(
                              data: (list) => list.length.toString(),
                              loading: () => '...',
                              error: (_, __) => '0',
                            ),
                            icon: Icons.warning_amber_rounded,
                            color: AppTheme.warning,
                            onTap: () {
                              _showExpiringVehicles(context, ref);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Título sección provincias
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Por Provincia',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/vehicles'),
                          child: const Text('Ver todos'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Grid de provincias
            vehicleCountAsync.when(
              data: (countMap) => SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.6,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final province = ArgentinaProvinces.all[index];
                      final count = countMap[province.id] ?? 0;
                      
                      return _ProvinceCard(
                        province: province,
                        vehicleCount: count,
                        onTap: () {
                          ref.read(locationFilterProvider.notifier).setProvince(province.id);
                          context.go('/vehicles');
                        },
                        onLongPress: () {
                          _showCitiesInProvince(context, ref, province);
                        },
                      );
                    },
                    childCount: ArgentinaProvinces.all.length,
                  ),
                ),
              ),
              loading: () => const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Text('Error: $e'),
                  ),
                ),
              ),
            ),

            // Espacio inferior
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }

  void _showCitiesInProvince(BuildContext context, WidgetRef ref, Province province) {
    final citiesAsync = ref.read(citiesByProvinceProvider(province.id));
    final countsAsync = ref.read(vehicleCountByCityProvider(province.id));

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Ciudades en ${province.name}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: citiesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(child: Text('Error cargando ciudades')),
                data: (cities) {
                  if (cities.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No hay ciudades registradas en esta provincia',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return countsAsync.when(
                    loading: () => _buildCityList(sheetContext, ref, province, cities, {}),
                    error: (_, __) => _buildCityList(sheetContext, ref, province, cities, {}),
                    data: (counts) => _buildCityList(sheetContext, ref, province, cities, counts),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCityList(
    BuildContext context,
    WidgetRef ref,
    Province province,
    List<City> cities,
    Map<String, int> counts,
  ) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: cities.length,
      itemBuilder: (context, index) {
        final city = cities[index];
        final count = counts[city.id] ?? 0;

        return ListTile(
          leading: const Icon(Icons.location_city),
          title: Text(city.name),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    count.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentPrimary,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () {
            Navigator.pop(context);
            ref.read(locationFilterProvider.notifier).setProvince(province.id);
            ref.read(locationFilterProvider.notifier).setCity(city.id);
            GoRouter.of(context).go('/vehicles');
          },
        );
      },
    );
  }

  void _showExpiringVehicles(BuildContext context, WidgetRef ref) {
    final expiringAsync = ref.read(expiringDocumentsProvider);
    
    expiringAsync.whenData((vehicles) {
      if (vehicles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay documentos próximos a vencer'),
          ),
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        backgroundColor: AppTheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Documentos por Vencer',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: vehicles.length,
                  itemBuilder: (context, index) {
                    final vehicle = vehicles[index];
                    return ListTile(
                      leading: Icon(
                        vehicle.isVtvExpired || vehicle.isInsuranceExpired
                            ? Icons.error
                            : Icons.warning_amber_rounded,
                        color: vehicle.isVtvExpired || vehicle.isInsuranceExpired
                            ? AppTheme.error
                            : AppTheme.warning,
                      ),
                      title: Text('${vehicle.brand} ${vehicle.model}'),
                      subtitle: Text(vehicle.plate),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/vehicle/${vehicle.id}');
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    });
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                if (onTap != null)
                  Icon(
                    Icons.chevron_right,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProvinceCard extends StatelessWidget {
  final Province province;
  final int vehicleCount;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ProvinceCard({
    required this.province,
    required this.vehicleCount,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final hasVehicles = vehicleCount > 0;

    return GestureDetector(
      onTap: onTap,
      onLongPress: hasVehicles ? onLongPress : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hasVehicles ? AppTheme.surface : AppTheme.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasVehicles ? AppTheme.accentPrimary.withValues(alpha: 0.3) : AppTheme.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasVehicles 
                        ? AppTheme.accentPrimary.withValues(alpha: 0.15)
                        : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    province.abbreviation,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: hasVehicles 
                          ? AppTheme.accentPrimary 
                          : AppTheme.textSecondary,
                    ),
                  ),
                ),
                Text(
                  vehicleCount.toString(),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: hasVehicles 
                        ? AppTheme.accentPrimary 
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            Text(
              province.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: hasVehicles 
                    ? AppTheme.textPrimary 
                    : AppTheme.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
