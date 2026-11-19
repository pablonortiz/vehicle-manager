import 'package:flutter/material.dart';
import '../widgets/error_retry_view.dart';
import '../widgets/empty_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/supabase_config.dart';
import '../../core/constants/provinces.dart';
import '../../core/constants/vehicle_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/sync_service.dart';
import '../providers/vehicle_provider.dart';
import '../providers/location_provider.dart';
import 'home_sheets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleCountAsync = ref.watch(vehicleCountByProvinceProvider);
    final totalCountAsync = ref.watch(totalVehicleCountProvider);
    final expiringAsync = ref.watch(expiringDocumentsProvider);
    final statusCountsAsync = ref.watch(vehicleStatusCountsProvider);
    final syncState = ref.watch(syncServiceProvider);
    final hasNoVehicles = totalCountAsync.valueOrNull == 0;

    // El refresco post-sync ya ocurre solo vía DbChangeService.notifyChange →
    // los counts/total/expiring watchean vehiclesChangeProvider. Sin invalidación manual.

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
                            IconButton(
                              onPressed: () => context.push('/expenses'),
                              icon: const Icon(Icons.payments_outlined,
                                  color: AppTheme.accentPrimary),
                              tooltip: 'Gastos',
                            ),
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
                              tooltip: 'Buscar',
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

                    // Sin vehículos: bienvenida guiada en vez de stats en 0
                    if (!hasNoVehicles) ...[
                      // Estadísticas rápidas
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              title: 'Total Vehículos',
                              value: totalCountAsync.when(
                                data: (count) => count.toString(),
                                loading: () => '...',
                                error: (_, _) => '0',
                              ),
                              icon: Icons.directions_car,
                              color: AppTheme.accentPrimary,
                              onTap: () => _openVehicles(context, ref),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              title: 'Por Vencer',
                              value: expiringAsync.when(
                                data: (list) => list.length.toString(),
                                loading: () => '...',
                                error: (_, _) => '0',
                              ),
                              icon: Icons.warning_amber_rounded,
                              color: AppTheme.warning,
                              onTap: () {
                                showExpiringVehiclesSheet(context, ref);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _statusStatCard(context, ref,
                                statusCountsAsync, VehicleStatus.available),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _statusStatCard(context, ref,
                                statusCountsAsync, VehicleStatus.outOfService),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Título sección provincias
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Por Provincia',
                            style:
                                Theme.of(context).textTheme.headlineMedium,
                          ),
                          TextButton(
                            onPressed: () => _openVehicles(context, ref),
                            child: const Text('Ver todos'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            if (hasNoVehicles)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                  child: EmptyState(
                    icon: Icons.directions_car_rounded,
                    title: 'Todavía no cargaste ningún vehículo',
                    message: 'Empezá agregando el primero.',
                    actionLabel: 'Agregar vehículo',
                    onAction: () => context.push('/vehicle/new'),
                  ),
                ),
              ),

            // Grid de provincias (solo las que tienen vehículos)
            if (!hasNoVehicles)
              vehicleCountAsync.when(
              data: (countMap) {
                final provinces = ArgentinaProvinces.all
                    .where((p) => (countMap[p.id] ?? 0) > 0)
                    .toList();

                if (provinces.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Text(
                          'Sin vehículos cargados todavía',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                    ),
                  );
                }

                return SliverPadding(
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
                        final province = provinces[index];

                        return _ProvinceCard(
                          province: province,
                          vehicleCount: countMap[province.id] ?? 0,
                          onTap: () {
                            ref.read(statusFilterProvider.notifier).state = null;
                            ref.read(locationFilterProvider.notifier).setProvince(province.id);
                            context.go('/vehicles');
                          },
                          onLongPress: () {
                            showCitiesInProvinceSheet(context, ref, province);
                          },
                        );
                      },
                      childCount: provinces.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: ErrorRetryView(
                  message: 'No se pudieron cargar las provincias',
                  onRetry: () => ref.invalidate(vehicleCountByProvinceProvider),
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

  /// Abre el listado completo (sin filtro de ubicación), opcionalmente
  /// acotado a un [status].
  void _openVehicles(BuildContext context, WidgetRef ref,
      {VehicleStatus? status}) {
    ref.read(locationFilterProvider.notifier).clearAll();
    ref.read(statusFilterProvider.notifier).state = status;
    context.go('/vehicles');
  }

  Widget _statusStatCard(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<Map<VehicleStatus, int>> countsAsync,
    VehicleStatus status,
  ) {
    return _StatCard(
      title: status.pluralLabel,
      value: countsAsync.when(
        data: (counts) => '${counts[status] ?? 0}',
        loading: () => '...',
        error: (_, _) => '0',
      ),
      icon: status.icon,
      color: status.color,
      onTap: () => _openVehicles(context, ref, status: status),
    );
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
