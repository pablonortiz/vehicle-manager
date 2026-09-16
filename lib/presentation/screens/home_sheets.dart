import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/provinces.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/city.dart';
import '../../domain/models/vehicle.dart';
import '../providers/vehicle_provider.dart';
import '../providers/location_provider.dart';
import '../widgets/fleet_insurance_sheet.dart';

/// Bottom-sheet con las ciudades de una provincia y su conteo de vehículos.
void showCitiesInProvinceSheet(
    BuildContext context, WidgetRef ref, Province province) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    // Sobre el navigator raíz para tapar el FAB del shell.
    useRootNavigator: true,
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
            child: Consumer(
              builder: (context, ref, _) {
                final citiesAsync = ref.watch(citiesByProvinceProvider(province.id));
                final countsAsync = ref.watch(vehicleCountByCityProvider(province.id));

                return citiesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, _) => const Center(child: Text('Error cargando ciudades')),
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
                      error: (_, _) => _buildCityList(sheetContext, ref, province, cities, {}),
                      data: (counts) => _buildCityList(sheetContext, ref, province, cities, counts),
                    );
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
          ref.read(statusFilterProvider.notifier).state = null;
          ref.read(locationFilterProvider.notifier).setProvince(province.id);
          ref.read(locationFilterProvider.notifier).setCity(city.id);
          GoRouter.of(context).go('/vehicles');
        },
      );
    },
  );
}

/// "VTV: venció 24/06/2026 (hace 12 días)" / "Seguro: vence 27/07/2026 (en 21 días)".
String _expiryLine(ExpiringDocument doc) {
  final date = DateFormat('dd/MM/yyyy').format(doc.expiry);
  if (doc.expired) {
    final days = -doc.daysLeft;
    final ago = days == 0 ? 'hoy' : 'hace $days ${days == 1 ? 'día' : 'días'}';
    return '${doc.label}: venció $date ($ago)';
  }
  final left = doc.daysLeft == 0
      ? 'hoy'
      : 'en ${doc.daysLeft} ${doc.daysLeft == 1 ? 'día' : 'días'}';
  return '${doc.label}: vence $date ($left)';
}

/// Bottom-sheet con los vehículos cuya documentación está próxima a vencer.
void showExpiringVehiclesSheet(BuildContext context, WidgetRef ref) {
  final loaded = ref.read(expiringDocumentsProvider).valueOrNull;
  // Más urgente primero (el doc que vence antes manda).
  final vehicles = loaded == null
      ? null
      : (loaded.toList()
        ..sort((a, b) {
          final aExpiry = a.expiringDocuments.firstOrNull?.expiry ?? DateTime(9999);
          final bExpiry = b.expiringDocuments.firstOrNull?.expiry ?? DateTime(9999);
          return aExpiry.compareTo(bExpiry);
        }));

  // Si el provider aún no resolvió (loading) o quedó en error, dar feedback
  // en vez de un tap que no hace nada.
  if (vehicles == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cargando documentos, probá de nuevo en un instante'),
      ),
    );
    return;
  }

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
    // Sobre el navigator raíz para tapar el FAB del shell.
    useRootNavigator: true,
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
              // El push usa el context de la pantalla, no el del ítem del
              // sheet que se acaba de cerrar.
              itemBuilder: (_, index) {
                final vehicle = vehicles[index];
                final hasExpired =
                    vehicle.isVtvExpired || vehicle.isInsuranceExpired;
                return ListTile(
                  leading: Icon(
                    hasExpired ? Icons.error : Icons.warning_amber_rounded,
                    color: hasExpired ? AppTheme.error : AppTheme.warning,
                  ),
                  title: Text('${vehicle.brand} ${vehicle.model}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vehicle.plate),
                      for (final doc in vehicle.expiringDocuments)
                        Text(
                          _expiryLine(doc),
                          style: TextStyle(
                            fontSize: 12,
                            color: doc.expired ? AppTheme.error : AppTheme.warning,
                          ),
                        ),
                    ],
                  ),
                  isThreeLine: vehicle.expiringDocuments.length > 1,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push('/vehicle/${vehicle.id}?highlight=docs');
                  },
                );
              },
            ),
          ),
          // Con seguros venciendo, la renovación suele ser de toda la flota.
          if (vehicles.any((vehicle) =>
              vehicle.isInsuranceExpired || vehicle.isInsuranceExpiringSoon))
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    showFleetInsuranceSheet(context, ref);
                  },
                  icon: const Icon(Icons.security, size: 18),
                  label: const Text('Renovar seguro de la flota'),
                ),
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    ),
  );
}
