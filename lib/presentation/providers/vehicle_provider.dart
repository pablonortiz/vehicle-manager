import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/vehicle_constants.dart';
import '../../data/repositories/vehicle_repository.dart';
import '../../data/repositories/maintenance_repository.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/repositories/photo_repository.dart';
import '../../data/services/db_change_service.dart';
import '../../data/services/sync_service.dart';
import '../../data/services/notification_service.dart';
import '../../domain/fleet_summary.dart';
import '../../domain/models/vehicle.dart';
import '../../domain/models/vehicle_history.dart';
import '../../domain/models/maintenance.dart';
import '../../domain/models/vehicle_note.dart';
import '../../domain/models/vehicle_photo.dart';
import 'db_change_provider.dart';
import 'location_provider.dart';

// Repository providers
final vehicleRepositoryProvider = Provider((ref) {
  final repo = VehicleRepository();
  final syncService = ref.read(syncServiceProvider.notifier);
  repo.setSyncService(syncService);
  return repo;
});

final maintenanceRepositoryProvider = Provider((ref) {
  final repo = MaintenanceRepository();
  final syncService = ref.read(syncServiceProvider.notifier);
  repo.setSyncService(syncService);
  return repo;
});

final noteRepositoryProvider = Provider((ref) {
  final repo = NoteRepository();
  final syncService = ref.read(syncServiceProvider.notifier);
  repo.setSyncService(syncService);
  return repo;
});

final photoRepositoryProvider = Provider((ref) {
  final repo = PhotoRepository();
  final syncService = ref.read(syncServiceProvider.notifier);
  repo.setSyncService(syncService);
  return repo;
});

// Lista de todos los vehículos
final vehiclesProvider = FutureProvider<List<Vehicle>>((ref) async {
  ref.watch(vehiclesChangeProvider);
  final repository = ref.watch(vehicleRepositoryProvider);
  return repository.getAllVehicles();
});

// Conteo de vehículos por provincia
final vehicleCountByProvinceProvider = FutureProvider<Map<int, int>>((ref) async {
  ref.watch(vehiclesChangeProvider);
  final repository = ref.watch(vehicleRepositoryProvider);
  return repository.getVehicleCountByProvince();
});

// Total de vehículos
final totalVehicleCountProvider = FutureProvider<int>((ref) async {
  ref.watch(vehiclesChangeProvider);
  final repository = ref.watch(vehicleRepositoryProvider);
  return repository.getTotalVehicleCount();
});

// Vehículo por ID
final vehicleByIdProvider = FutureProvider.autoDispose.family<Vehicle?, String>((ref, id) async {
  ref.watch(vehiclesChangeProvider);
  final repository = ref.watch(vehicleRepositoryProvider);
  return repository.getVehicleById(id);
});

// Búsqueda de vehículos
final vehicleSearchProvider = FutureProvider.autoDispose.family<List<Vehicle>, String>((ref, query) async {
  ref.watch(vehiclesChangeProvider);
  final repository = ref.watch(vehicleRepositoryProvider);
  if (query.isEmpty) return [];
  return repository.searchVehicles(query);
});

// Historial de un vehículo
final vehicleHistoryProvider = FutureProvider.autoDispose.family<List<VehicleHistory>, String>((ref, vehicleId) async {
  ref.watch(vehiclesChangeProvider);
  final repository = ref.watch(vehicleRepositoryProvider);
  return repository.getVehicleHistory(vehicleId);
});

// Vehículos con documentos por vencer
final expiringDocumentsProvider = FutureProvider<List<Vehicle>>((ref) async {
  ref.watch(vehiclesChangeProvider);
  final repository = ref.watch(vehicleRepositoryProvider);
  return repository.getVehiclesWithExpiringDocuments();
});

// Mantenimientos de un vehículo
final maintenancesByVehicleProvider = FutureProvider.autoDispose.family<List<Maintenance>, String>((ref, vehicleId) async {
  ref.watch(maintenancesChangeProvider);
  final repository = ref.watch(maintenanceRepositoryProvider);
  return repository.getMaintenancesByVehicle(vehicleId);
});

// Notas de un vehículo
final notesByVehicleProvider = FutureProvider.autoDispose.family<List<VehicleNote>, String>((ref, vehicleId) async {
  ref.watch(notesChangeProvider);
  final repository = ref.watch(noteRepositoryProvider);
  return repository.getNotesByVehicle(vehicleId);
});

// Fotos de un vehículo
final photosByVehicleProvider = FutureProvider.autoDispose.family<List<VehiclePhoto>, String>((ref, vehicleId) async {
  ref.watch(photosChangeProvider);
  final repository = ref.watch(photoRepositoryProvider);
  return repository.getPhotosByVehicle(vehicleId);
});

// Notifier para manejar el estado mutable de vehículos
class VehicleNotifier extends StateNotifier<AsyncValue<List<Vehicle>>> {
  final VehicleRepository _repository;
  final Ref _ref;
  StreamSubscription<String>? _subscription;

  VehicleNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    loadVehicles();
    // Listen for external DB changes (e.g., from sync)
    _subscription = DbChangeService.instance.changes
        .where((table) => table == 'vehicles')
        .listen((_) => loadVehicles());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> loadVehicles() async {
    if (!state.hasValue) state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.getAllVehicles());
  }

  Future<void> refresh() async {
    await loadVehicles();
    _invalidateProviders();
  }

  // Nota: las mutaciones no llaman loadVehicles() ni _invalidateProviders()
  // explícitamente. El repositorio emite DbChangeService.notifyChange('vehicles')
  // al terminar, lo que (a) dispara la subscription de este notifier → loadVehicles,
  // y (b) refresca vehiclesProvider y los counts/expiring que watchean
  // vehiclesChangeProvider. Una sola vía de refresco evita el doble reload.

  Future<String?> addVehicle(Vehicle vehicle) async {
    try {
      final id = await _repository.insertVehicle(vehicle);
      await NotificationService.instance
          .scheduleForVehicle(vehicle.copyWith(id: id));
      return id;
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateVehicle(Vehicle vehicle) async {
    try {
      await _repository.updateVehicle(vehicle);
      await NotificationService.instance.scheduleForVehicle(vehicle);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteVehicle(String id) async {
    try {
      await _repository.deleteVehicle(id);
      await NotificationService.instance.cancelForVehicle(id);
      return true;
    } catch (e) {
      return false;
    }
  }

  void _invalidateProviders() {
    _ref.invalidate(vehicleCountByProvinceProvider);
    _ref.invalidate(totalVehicleCountProvider);
    _ref.invalidate(expiringDocumentsProvider);
    _ref.invalidate(vehiclesProvider);
  }
}

final vehicleNotifierProvider = StateNotifierProvider<VehicleNotifier, AsyncValue<List<Vehicle>>>((ref) {
  final repository = ref.watch(vehicleRepositoryProvider);
  return VehicleNotifier(repository, ref);
});

// Query de búsqueda activa
final searchQueryProvider = StateProvider<String>((ref) => '');

// Vehículos filtrados por jerarquía de ubicación (provincia -> ciudad -> lugar)
final vehiclesByLocationFilterProvider = Provider<AsyncValue<List<Vehicle>>>((ref) {
  final locationFilter = ref.watch(locationFilterProvider);
  final vehiclesAsync = ref.watch(vehicleNotifierProvider);

  return vehiclesAsync.whenData((vehicles) {
    var filtered = vehicles;

    if (locationFilter.provinceId != null) {
      filtered = filtered.where((v) => v.provinceId == locationFilter.provinceId).toList();
    }

    if (locationFilter.cityId != null) {
      filtered = filtered.where((v) => v.cityId == locationFilter.cityId).toList();
    }

    if (locationFilter.lugarId != null) {
      filtered = filtered.where((v) => v.lugarId == locationFilter.lugarId).toList();
    }

    return filtered;
  });
});

/// Filtro de estado del listado (null = todos). Vive fuera de la pantalla para
/// que la Home pueda abrir el listado ya filtrado y el filtro persista entre
/// pestañas, igual que el de ubicación.
final statusFilterProvider = StateProvider<VehicleStatus?>((ref) => null);

/// Conteo de vehículos por estado (solo estados con vehículos), para la Home.
final vehicleStatusCountsProvider =
    Provider<AsyncValue<Map<VehicleStatus, int>>>((ref) {
  return ref.watch(vehiclesProvider).whenData(FleetSummary.countByStatus);
});
