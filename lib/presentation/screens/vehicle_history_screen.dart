import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/vehicle.dart';
import '../../domain/models/vehicle_history.dart';
import '../providers/vehicle_provider.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_retry_view.dart';
import '../widgets/plate_text.dart';
import '../widgets/section_header.dart';
import '../widgets/vehicle_icon.dart';
import 'vehicle_history/history_values.dart';

/// Cambios: cada modificación del vehículo, agrupada por día, con el valor de
/// antes y el de después.
class VehicleHistoryScreen extends ConsumerWidget {
  final String vehicleId;

  const VehicleHistoryScreen({super.key, required this.vehicleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(vehicleHistoryProvider(vehicleId));
    final vehicle = ref.watch(vehicleByIdProvider(vehicleId)).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Cambios')),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorRetryView(
          message: 'No se pudieron cargar los cambios',
          onRetry: () => ref.invalidate(vehicleHistoryProvider(vehicleId)),
        ),
        data: (history) => ListView(
          padding: const EdgeInsets.fromLTRB(
              Space.s5, Space.s2, Space.s5, Space.s10),
          children: [
            if (vehicle != null) ...[
              _VehicleHeader(vehicle: vehicle),
              const Gap(Space.s6),
            ],
            if (history.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: Space.s8),
                child: EmptyState(
                  icon: Icons.history_rounded,
                  title: 'Sin cambios registrados',
                  message: 'Acá vas a ver cada modificación del vehículo.',
                ),
              )
            else
              for (final (index, day) in _groupByDay(history).indexed) ...[
                if (index > 0) const Gap(Space.s6),
                SectionHeader(AppFormats.date(day.date)),
                const Gap(Space.s2),
                AppCard.list(
                  children: [
                    for (final change in day.changes) _ChangeRow(change: change),
                  ],
                ),
              ],
          ],
        ),
      ),
    );
  }

  /// Agrupa por día en una pasada, en el orden en que vienen (más nuevo
  /// primero).
  static List<({DateTime date, List<VehicleHistory> changes})> _groupByDay(
      List<VehicleHistory> history) {
    final days = <({DateTime date, List<VehicleHistory> changes})>[];
    for (final change in history) {
      final day = DateUtils.dateOnly(change.changedAt);
      if (days.isEmpty || days.last.date != day) {
        days.add((date: day, changes: [change]));
      } else {
        days.last.changes.add(change);
      }
    }
    return days;
  }
}

class _VehicleHeader extends StatelessWidget {
  final Vehicle vehicle;

  const _VehicleHeader({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        VehicleIcon(type: vehicle.type, paint: vehicle.color),
        const Gap(Space.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vehicle.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.titleSm.copyWith(color: c.text),
              ),
              const Gap(Space.s1),
              PlateText(vehicle.plate),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChangeRow extends StatelessWidget {
  final VehicleHistory change;

  const _ChangeRow({required this.change});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isCreation = change.field == 'created';
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: Space.s4, vertical: Space.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(change.fieldLabel,
                    style: AppText.label.copyWith(color: c.text)),
              ),
              Text(AppFormats.time(change.changedAt),
                  style: AppText.caption.tabular.copyWith(color: c.textMuted)),
            ],
          ),
          const Gap(Space.s1),
          if (isCreation)
            Text('Se dio de alta el vehículo',
                style: AppText.body.copyWith(color: c.textMuted))
          else
            _BeforeAfter(change: change),
        ],
      ),
    );
  }
}

/// "antes → después": lo anterior en `text-muted`, lo nuevo en `text`.
class _BeforeAfter extends StatelessWidget {
  final VehicleHistory change;

  const _BeforeAfter({required this.change});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final before = historyDisplayValue(change.field, change.oldValue);
    final after = historyDisplayValue(change.field, change.newValue);
    return Semantics(
      label: 'Antes $before, ahora $after',
      excludeSemantics: true,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: Space.s2,
        children: [
          Text(before, style: AppText.body.tabular.copyWith(color: c.textMuted)),
          Icon(Icons.arrow_forward_rounded, size: Sizes.iconSm, color: c.textMuted),
          Text(after, style: AppText.body.tabular.copyWith(color: c.text)),
        ],
      ),
    );
  }
}
