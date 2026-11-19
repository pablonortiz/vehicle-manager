import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/provinces.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/expiry_status.dart';
import '../../domain/models/city.dart';
import '../../domain/models/vehicle.dart';
import '../providers/location_provider.dart';
import '../providers/vehicle_provider.dart';
import '../widgets/app_notice.dart';
import '../widgets/app_sheet.dart';
import '../widgets/app_tag.dart';
import '../widgets/empty_state.dart';
import '../widgets/fleet_insurance_sheet.dart';
import '../widgets/vehicle_list_tile.dart';

/// Ciudades de una provincia con su cantidad de vehículos; cada una abre el
/// listado filtrado.
void showCitiesInProvinceSheet(
  BuildContext context,
  WidgetRef ref,
  Province province,
) {
  showAppSheet<void>(
    context,
    builder: (sheetContext) => AppSheet(
      title: 'Ciudades de ${province.name}',
      child: Consumer(
        builder: (context, ref, _) {
          final citiesAsync = ref.watch(citiesByProvinceProvider(province.id));
          final counts =
              ref.watch(vehicleCountByCityProvider(province.id)).valueOrNull ??
              const <String, int>{};
          return citiesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(Space.s6),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => AppNotice.error(
              message: 'No se pudieron cargar las ciudades.',
              onRetry: () =>
                  ref.invalidate(citiesByProvinceProvider(province.id)),
            ),
            data: (cities) => cities.isEmpty
                ? const EmptyState(
                    icon: Icons.location_city_rounded,
                    title: 'No hay ciudades cargadas en esta provincia',
                  )
                : Column(
                    children: [
                      for (final city in cities)
                        _CityRow(
                          city: city,
                          count: counts[city.id] ?? 0,
                          onTap: () {
                            Navigator.pop(sheetContext);
                            ref.read(statusFilterProvider.notifier).state =
                                null;
                            final filter = ref.read(
                              locationFilterProvider.notifier,
                            );
                            filter.setProvince(province.id);
                            filter.setCity(city.id);
                            context.go('/vehicles');
                          },
                        ),
                    ],
                  ),
          );
        },
      ),
    ),
  );
}

class _CityRow extends StatelessWidget {
  final City city;
  final int count;
  final VoidCallback onTap;

  const _CityRow({
    required this.city,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      borderRadius: Radii.mdAll,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            Expanded(
              child: Text(
                city.name,
                style: AppText.bodyLg.copyWith(color: c.text),
              ),
            ),
            if (count > 0) CountBadge(count),
            const Gap(Space.s2),
            Icon(
              Icons.chevron_right_rounded,
              size: Sizes.iconMd,
              color: c.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// Vehículos con VTV o seguro vencido o por vencer, el más urgente primero.
/// [only] acota a los vencidos o a los que solo están por vencer.
Future<void> showExpiringVehiclesSheet(
  BuildContext context,
  WidgetRef ref, {
  ExpiryState? only,
}) async {
  final vehicles = await ref.read(expiringDocumentsProvider.future);
  if (!context.mounted) return;

  final shown =
      vehicles.where((vehicle) {
        final expired = vehicle.expiringDocuments.any(
          (doc) => doc.status.isExpired,
        );
        return switch (only) {
          ExpiryState.expired => expired,
          ExpiryState.expiringSoon => !expired,
          _ => true,
        };
      }).toList()..sort(
        (vehicle, other) => vehicle.expiringDocuments.first.expiry.compareTo(
          other.expiringDocuments.first.expiry,
        ),
      );
  final insuranceNeedsRenewal = shown.any(
    (vehicle) => vehicle.insuranceStatus.needsAttention,
  );

  await showAppSheet<void>(
    context,
    builder: (sheetContext) => AppSheet(
      title: switch (only) {
        ExpiryState.expired => 'Vencidos',
        ExpiryState.expiringSoon => 'Por vencer',
        _ => 'Vencimientos',
      },
      footer: insuranceNeedsRenewal
          ? SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  showFleetInsuranceSheet(context, ref);
                },
                icon: const Icon(Icons.shield_rounded),
                label: const Text('Renovar seguro de la flota'),
              ),
            )
          : null,
      child: shown.isEmpty
          ? EmptyState(
              icon: Icons.verified_rounded,
              title: only == ExpiryState.expired
                  ? 'No hay vencidos'
                  : 'Nada por vencer en los próximos 30 días',
            )
          : _ExpiringList(
              vehicles: shown,
              onOpen: (vehicle) {
                Navigator.pop(sheetContext);
                context.push('/vehicle/${vehicle.id}?highlight=docs');
              },
            ),
    ),
  );
}

class _ExpiringList extends StatelessWidget {
  final List<Vehicle> vehicles;
  final ValueChanged<Vehicle> onOpen;

  const _ExpiringList({required this.vehicles, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < vehicles.length; i++) ...[
          if (i > 0) const Divider(),
          VehicleListTile(
            vehicle: vehicles[i],
            onTap: () => onOpen(vehicles[i]),
            contentPadding: VehicleListTile.inSheetPadding,
          ),
        ],
      ],
    );
  }
}
