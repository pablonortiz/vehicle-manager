import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/provinces.dart';
import '../../core/constants/vehicle_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_tone.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/vehicle.dart';
import '../providers/vehicle_provider.dart';
import '../widgets/app_card.dart';
import '../widgets/app_notice.dart';
import '../widgets/app_tag.dart';
import '../widgets/section_header.dart';
import '../widgets/stat_tile.dart';
import '../widgets/status_styles.dart';
import '../widgets/vehicle_list_tile.dart';

/// Vehículos con algún papel vencido y los que solo tienen algo por vencer
/// (cada vehículo cuenta una vez, en su situación más urgente).
class ExpiryCounts {
  final List<Vehicle> expired;
  final List<Vehicle> expiringSoon;

  ExpiryCounts(List<Vehicle> vehicles)
    : expired = vehicles
          .where(
            (vehicle) =>
                vehicle.expiringDocuments.any((doc) => doc.status.isExpired),
          )
          .toList(),
      expiringSoon = vehicles
          .where(
            (vehicle) =>
                vehicle.expiringDocuments.every((doc) => !doc.status.isExpired),
          )
          .toList();
}

/// Cifras de la flota: total, disponibles, por vencer y vencidos.
class HomeStats extends ConsumerWidget {
  final void Function({VehicleStatus? status}) onOpenVehicles;
  final VoidCallback onOpenExpiringSoon;
  final VoidCallback onOpenExpired;

  const HomeStats({
    super.key,
    required this.onOpenVehicles,
    required this.onOpenExpiringSoon,
    required this.onOpenExpired,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalAsync = ref.watch(totalVehicleCountProvider);
    final provincesAsync = ref.watch(vehicleCountByProvinceProvider);
    final statusAsync = ref.watch(vehicleStatusCountsProvider);
    final expiringAsync = ref.watch(expiringDocumentsProvider);
    final expiry = expiringAsync.whenOrNull(data: ExpiryCounts.new);
    final provinceCount = provincesAsync.whenOrNull(
      data: (counts) => counts.values.where((count) => count > 0).length,
    );

    return Column(
      children: [
        _TileRow(
          left: StatTile(
            label: 'Vehículos',
            icon: Icons.directions_car_rounded,
            value: totalAsync.whenOrNull(data: (total) => '$total'),
            failed: totalAsync.hasError,
            hint: provinceCount == null
                ? null
                : provinceCount == 1
                ? 'En 1 provincia'
                : 'En $provinceCount provincias',
            onTap: onOpenVehicles,
          ),
          right: StatTile(
            label: 'Disponibles',
            icon: Icons.check_circle_rounded,
            tone: Tone.success,
            value: statusAsync.whenOrNull(
              data: (counts) => '${counts[VehicleStatus.available] ?? 0}',
            ),
            failed: statusAsync.hasError,
            hint: 'Listos para usar',
            onTap: () => onOpenVehicles(status: VehicleStatus.available),
          ),
        ),
        const Gap(Space.s3),
        _TileRow(
          left: StatTile(
            label: 'Por vencer',
            icon: Icons.schedule_rounded,
            tone: Tone.warning,
            value: expiry == null ? null : '${expiry.expiringSoon.length}',
            failed: expiringAsync.hasError,
            hint: 'En los próximos 30 días',
            onTap: onOpenExpiringSoon,
          ),
          right: StatTile(
            label: 'Vencidos',
            icon: Icons.error_rounded,
            tone: Tone.danger,
            value: expiry == null ? null : '${expiry.expired.length}',
            failed: expiringAsync.hasError,
            hint: 'VTV o seguro',
            onTap: onOpenExpired,
          ),
        ),
      ],
    );
  }
}

class _TileRow extends StatelessWidget {
  final Widget left;
  final Widget right;

  const _TileRow({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const Gap(Space.s3),
          Expanded(child: right),
        ],
      ),
    );
  }
}

/// Los vencimientos más urgentes a la vista, con acceso a la lista completa.
class ExpiringPreview extends ConsumerWidget {
  final VoidCallback onSeeAll;

  const ExpiringPreview({super.key, required this.onSeeAll});

  static const _previewCount = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expiringAsync = ref.watch(expiringDocumentsProvider);
    return expiringAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => Column(
        children: [
          const SectionHeader('Vencimientos'),
          AppNotice.error(
            message: 'No se pudieron cargar los vencimientos.',
            onRetry: () => ref.invalidate(expiringDocumentsProvider),
          ),
        ],
      ),
      data: (vehicles) {
        final urgent = [...vehicles]..sort(_byMostUrgent);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              'Vencimientos',
              count: vehicles.isEmpty ? null : vehicles.length,
              actionLabel: vehicles.length > _previewCount ? 'Ver todos' : null,
              onAction: onSeeAll,
            ),
            const Gap(Space.s2),
            if (vehicles.isEmpty)
              const AppNotice(
                tone: Tone.success,
                message: 'No hay VTV ni seguros vencidos o por vencer.',
              )
            else
              AppCard.list(
                children: [
                  for (final vehicle in urgent.take(_previewCount))
                    VehicleListTile(
                      vehicle: vehicle,
                      onTap: () =>
                          context.push('/vehicle/${vehicle.id}?highlight=docs'),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }

  static int _byMostUrgent(Vehicle vehicle, Vehicle other) {
    final first = vehicle.expiringDocuments.first.expiry;
    final second = other.expiringDocuments.first.expiry;
    return first.compareTo(second);
  }
}

/// Cantidad de vehículos por estado; cada fila abre el listado filtrado.
class FleetStatusSection extends ConsumerWidget {
  final void Function({VehicleStatus? status}) onOpenVehicles;

  const FleetStatusSection({super.key, required this.onOpenVehicles});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countsAsync = ref.watch(vehicleStatusCountsProvider);
    final counts = countsAsync.valueOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Estado de la flota'),
        const Gap(Space.s2),
        if (countsAsync.hasError)
          AppNotice.error(
            message: 'No se pudo cargar el estado de la flota.',
            onRetry: () => ref.invalidate(vehicleStatusCountsProvider),
          )
        else
          AppCard.list(
            children: [
              for (final status in VehicleStatus.values)
                _CountRow(
                  icon: status.statusIcon,
                  tone: status.tone,
                  label: status.pluralLabel,
                  count: counts?[status],
                  onTap: () => onOpenVehicles(status: status),
                ),
            ],
          ),
      ],
    );
  }
}

/// Provincias con vehículos. "Ver ciudades" está a la vista (antes solo con
/// un long-press).
class ProvincesSection extends ConsumerWidget {
  final ValueChanged<Province> onOpenProvince;
  final ValueChanged<Province> onShowCities;

  const ProvincesSection({
    super.key,
    required this.onOpenProvince,
    required this.onShowCities,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countsAsync = ref.watch(vehicleCountByProvinceProvider);
    return countsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => AppNotice.error(
        message: 'No se pudieron cargar las provincias.',
        onRetry: () => ref.invalidate(vehicleCountByProvinceProvider),
      ),
      data: (counts) {
        final provinces = ArgentinaProvinces.all
            .where((province) => (counts[province.id] ?? 0) > 0)
            .toList();
        if (provinces.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader('Por provincia', count: provinces.length),
            const Gap(Space.s2),
            AppCard.list(
              children: [
                for (final province in provinces)
                  _ProvinceRow(
                    province: province,
                    count: counts[province.id] ?? 0,
                    onTap: () => onOpenProvince(province),
                    onShowCities: () => onShowCities(province),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _CountRow extends StatelessWidget {
  final IconData icon;
  final Tone tone;
  final String label;
  final int? count;
  final VoidCallback onTap;

  const _CountRow({
    required this.icon,
    required this.tone,
    required this.label,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.s4),
          child: Row(
            children: [
              Icon(icon, size: Sizes.iconMd, color: tone.foreground(c)),
              const Gap(Space.s3),
              Expanded(
                child: Text(label, style: AppText.body.copyWith(color: c.text)),
              ),
              Text(
                count == null ? '–' : '$count',
                style: AppText.label.tabular.copyWith(color: c.text),
              ),
              const Gap(Space.s2),
              Icon(
                Icons.chevron_right_rounded,
                size: Sizes.iconMd,
                color: c.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProvinceRow extends StatelessWidget {
  final Province province;
  final int count;
  final VoidCallback onTap;
  final VoidCallback onShowCities;

  const _ProvinceRow({
    required this.province,
    required this.count,
    required this.onTap,
    required this.onShowCities,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.only(left: Space.s4, right: Space.s1),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AppTag(province.abbreviation),
                ),
              ),
              const Gap(Space.s2),
              Expanded(
                child: Text(
                  province.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.copyWith(color: c.text),
                ),
              ),
              Text(
                count == 1 ? '1 vehículo' : '$count vehículos',
                style: AppText.caption.tabular.copyWith(color: c.textMuted),
              ),
              IconButton(
                tooltip: 'Ver ciudades',
                onPressed: onShowCities,
                icon: const Icon(Icons.location_city_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
