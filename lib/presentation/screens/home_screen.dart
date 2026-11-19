import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/supabase_config.dart';
import '../../core/constants/provinces.dart';
import '../../core/constants/vehicle_constants.dart';
import '../../core/theme/app_tokens.dart';
import '../../domain/expiry_status.dart';
import '../../data/services/sync_service.dart';
import '../providers/location_provider.dart';
import '../providers/vehicle_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/root_app_bar.dart';
import 'home_sections.dart';
import 'home_sheets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasNoVehicles = ref.watch(totalVehicleCountProvider).valueOrNull == 0;

    return Scaffold(
      appBar: RootAppBar(
        title: 'Inicio',
        actions: [
          IconButton(
            tooltip: 'Buscar',
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: hasNoVehicles
            ? ListView(
                children: [
                  EmptyState(
                    icon: Icons.directions_car_rounded,
                    title: 'Todavía no cargaste ningún vehículo',
                    message: 'Empezá agregando el primero.',
                    actionLabel: 'Agregar vehículo',
                    onAction: () => context.push('/vehicle/new'),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  Space.s5,
                  Space.s2,
                  Space.s5,
                  Space.s10 + Space.s10,
                ),
                children: [
                  HomeStats(
                    onOpenVehicles: ({status}) =>
                        _openVehicles(context, ref, status: status),
                    onOpenExpiringSoon: () => showExpiringVehiclesSheet(
                      context,
                      ref,
                      only: ExpiryState.expiringSoon,
                    ),
                    onOpenExpired: () => showExpiringVehiclesSheet(
                      context,
                      ref,
                      only: ExpiryState.expired,
                    ),
                  ),
                  const Gap(Space.s6),
                  ExpiringPreview(
                    onSeeAll: () => showExpiringVehiclesSheet(context, ref),
                  ),
                  const Gap(Space.s6),
                  FleetStatusSection(
                    onOpenVehicles: ({status}) =>
                        _openVehicles(context, ref, status: status),
                  ),
                  const Gap(Space.s6),
                  ProvincesSection(
                    onOpenProvince: (province) =>
                        _openProvince(context, ref, province),
                    onShowCities: (province) =>
                        showCitiesInProvinceSheet(context, ref, province),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    if (SupabaseConfig.isConfigured) {
      await ref.read(syncServiceProvider.notifier).fullSync();
    }
    ref.invalidate(vehicleCountByProvinceProvider);
    ref.invalidate(totalVehicleCountProvider);
    ref.invalidate(expiringDocumentsProvider);
    await ref.read(vehicleNotifierProvider.notifier).refresh();
  }

  /// Abre el listado completo (sin filtro de ubicación), opcionalmente
  /// acotado a un [status].
  void _openVehicles(
    BuildContext context,
    WidgetRef ref, {
    VehicleStatus? status,
  }) {
    ref.read(locationFilterProvider.notifier).clearAll();
    ref.read(statusFilterProvider.notifier).state = status;
    context.go('/vehicles');
  }

  void _openProvince(BuildContext context, WidgetRef ref, Province province) {
    ref.read(statusFilterProvider.notifier).state = null;
    ref.read(locationFilterProvider.notifier).setProvince(province.id);
    context.go('/vehicles');
  }
}
