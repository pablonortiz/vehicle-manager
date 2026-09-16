import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/provinces.dart';
import '../../core/theme/app_theme.dart';
import '../providers/location_provider.dart';

/// "Buenos Aires > La Plata > Depósito" según el filtro de ubicación activo.
class LocationFilterLabel extends ConsumerWidget {
  final LocationFilter locationFilter;
  final String prefix;
  final TextStyle style;
  final TextAlign? textAlign;

  const LocationFilterLabel({
    super.key,
    required this.locationFilter,
    this.prefix = '',
    this.style = const TextStyle(fontSize: 14, color: AppTheme.accentPrimary),
    this.textAlign,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parts = <String>[];

    if (locationFilter.provinceId != null) {
      parts.add(ArgentinaProvinces.getById(locationFilter.provinceId!).name);
    }

    if (locationFilter.cityId != null) {
      final cityAsync = ref.watch(cityByIdProvider(locationFilter.cityId!));
      cityAsync.whenData((city) {
        if (city != null && !parts.contains(city.name)) {
          parts.add(city.name);
        }
      });
    }

    if (locationFilter.lugarId != null) {
      final lugarAsync = ref.watch(lugarByIdProvider(locationFilter.lugarId!));
      lugarAsync.whenData((lugar) {
        if (lugar != null && !parts.contains(lugar.name)) {
          parts.add(lugar.name);
        }
      });
    }

    return Text(
      '$prefix${parts.join(' > ')}',
      style: style,
      textAlign: textAlign,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
