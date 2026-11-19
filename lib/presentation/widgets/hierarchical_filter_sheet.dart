import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/provinces.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../providers/location_provider.dart';
import '../providers/vehicle_provider.dart';
import 'app_card.dart';
import 'app_notice.dart';
import 'app_sheet.dart';
import 'app_tag.dart';
import 'app_text_field.dart';

/// Abre el filtro por ubicación (provincia → ciudad → lugar). El filtro se
/// aplica al tocar cada opción; el pie dice cuántos vehículos quedan.
Future<void> showHierarchicalFilterSheet(BuildContext context) {
  return showAppSheet<void>(
    context,
    builder: (_) => const HierarchicalFilterSheet(),
  );
}

/// Cada nivel elegido queda resumido en una fila con "Cambiar" y abre el
/// siguiente: el sheet no crece con listas que ya se resolvieron.
class HierarchicalFilterSheet extends ConsumerWidget {
  const HierarchicalFilterSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(locationFilterProvider);
    final notifier = ref.read(locationFilterProvider.notifier);
    final provinceId = filter.provinceId;
    final cityId = filter.cityId;
    final resultCount =
        ref.watch(vehiclesByLocationFilterProvider).valueOrNull?.length;

    return AppSheet(
      title: 'Filtrar por ubicación',
      footer: Row(
        children: [
          if (filter.hasFilter) ...[
            TextButton(onPressed: notifier.clearAll, child: const Text('Limpiar')),
            const Gap(Space.s3),
          ],
          Expanded(
            child: SizedBox(
              height: Sizes.controlH,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_resultLabel(resultCount)),
              ),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FieldLabel('Provincia'),
          const Gap(Space.s2),
          provinceId == null
              ? _ProvinceOptions(onSelected: notifier.setProvince)
              : _ChosenRow(
                  label: ArgentinaProvinces.getById(provinceId).name,
                  onChange: () => notifier.setProvince(null),
                ),
          if (provinceId != null) ...[
            const Gap(Space.s5),
            const FieldLabel('Ciudad'),
            const Gap(Space.s2),
            cityId == null
                ? _CityOptions(provinceId: provinceId, onSelected: notifier.setCity)
                : _ChosenCity(cityId: cityId, onChange: notifier.clearCity),
          ],
          if (cityId != null) ...[
            const Gap(Space.s5),
            const FieldLabel('Lugar'),
            const Gap(Space.s2),
            filter.lugarId == null
                ? _LugarOptions(cityId: cityId, onSelected: notifier.setLugar)
                : _ChosenLugar(
                    lugarId: filter.lugarId!, onChange: notifier.clearLugar),
          ],
        ],
      ),
    );
  }

  static String _resultLabel(int? count) => switch (count) {
        null => 'Listo',
        1 => 'Ver 1 vehículo',
        _ => 'Ver $count vehículos',
      };
}

class _ProvinceOptions extends ConsumerWidget {
  final ValueChanged<int> onSelected;

  const _ProvinceOptions({required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(vehicleCountByProvinceProvider).when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => AppNotice.error(
            message: 'No se pudieron cargar las provincias.',
            onRetry: () => ref.invalidate(vehicleCountByProvinceProvider),
          ),
          data: (counts) {
            final provinces = ArgentinaProvinces.all
                .where((province) => counts.containsKey(province.id))
                .toList();
            if (provinces.isEmpty) {
              return const _EmptyOptions('Todavía no hay vehículos cargados.');
            }
            return AppCard.list(
              children: [
                for (final province in provinces)
                  _OptionRow(
                    label: province.name,
                    count: counts[province.id] ?? 0,
                    onTap: () => onSelected(province.id),
                  ),
              ],
            );
          },
        );
  }
}

class _CityOptions extends ConsumerWidget {
  final int provinceId;
  final ValueChanged<String> onSelected;

  const _CityOptions({required this.provinceId, required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts =
        ref.watch(vehicleCountByCityProvider(provinceId)).valueOrNull ?? {};
    return ref.watch(citiesByProvinceProvider(provinceId)).when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => AppNotice.error(
            message: 'No se pudieron cargar las ciudades.',
            onRetry: () => ref.invalidate(citiesByProvinceProvider(provinceId)),
          ),
          data: (cities) => cities.isEmpty
              ? const _EmptyOptions('Esta provincia no tiene ciudades cargadas.')
              : AppCard.list(
                  children: [
                    for (final city in cities)
                      _OptionRow(
                        label: city.name,
                        count: counts[city.id] ?? 0,
                        onTap: () => onSelected(city.id!),
                      ),
                  ],
                ),
        );
  }
}

class _LugarOptions extends ConsumerWidget {
  final String cityId;
  final ValueChanged<String> onSelected;

  const _LugarOptions({required this.cityId, required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(vehicleCountByLugarProvider(cityId)).valueOrNull ?? {};
    return ref.watch(lugaresByCityProvider(cityId)).when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => AppNotice.error(
            message: 'No se pudieron cargar los lugares.',
            onRetry: () => ref.invalidate(lugaresByCityProvider(cityId)),
          ),
          data: (lugares) => lugares.isEmpty
              ? const _EmptyOptions('Esta ciudad no tiene lugares cargados.')
              : AppCard.list(
                  children: [
                    for (final lugar in lugares)
                      _OptionRow(
                        label: lugar.name,
                        count: counts[lugar.id] ?? 0,
                        onTap: () => onSelected(lugar.id!),
                      ),
                  ],
                ),
        );
  }
}

class _ChosenCity extends ConsumerWidget {
  final String cityId;
  final VoidCallback onChange;

  const _ChosenCity({required this.cityId, required this.onChange});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final city = ref.watch(cityByIdProvider(cityId)).valueOrNull;
    return _ChosenRow(label: city?.name ?? '…', onChange: onChange);
  }
}

class _ChosenLugar extends ConsumerWidget {
  final String lugarId;
  final VoidCallback onChange;

  const _ChosenLugar({required this.lugarId, required this.onChange});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lugar = ref.watch(lugarByIdProvider(lugarId)).valueOrNull;
    return _ChosenRow(label: lugar?.name ?? '…', onChange: onChange);
  }
}

/// Opción de un nivel: nombre y cuántos vehículos tiene.
class _OptionRow extends StatelessWidget {
  final String label;
  final int count;
  final VoidCallback onTap;

  const _OptionRow({required this.label, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Sizes.touchMin + Space.s1),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Space.s4, vertical: Space.s3),
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: AppText.body.copyWith(color: c.text)),
              ),
              if (count > 0) CountBadge(count),
              const Gap(Space.s2),
              Icon(Icons.chevron_right_rounded,
                  size: Sizes.iconMd, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nivel ya elegido: queda a la vista con "Cambiar" para volver a la lista.
class _ChosenRow extends StatelessWidget {
  final String label;
  final VoidCallback onChange;

  const _ChosenRow({required this.label, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard.list(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: Space.s4, right: Space.s2),
          child: Row(
            children: [
              Icon(Icons.check_circle_rounded, size: Sizes.iconMd, color: c.accent),
              const Gap(Space.s3),
              Expanded(
                child: Text(label, style: AppText.label.copyWith(color: c.text)),
              ),
              TextButton(onPressed: onChange, child: const Text('Cambiar')),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyOptions extends StatelessWidget {
  final String text;

  const _EmptyOptions(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppText.body.copyWith(color: context.colors.textMuted));
  }
}
