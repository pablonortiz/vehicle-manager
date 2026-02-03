import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/vehicle_repository.dart';
import '../../data/repositories/maintenance_repository.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/repositories/photo_repository.dart';
import '../../data/services/sync_service.dart';
import '../../domain/models/vehicle.dart';
import '../../domain/models/vehicle_history.dart';
import '../../domain/models/maintenance.dart';
import '../../domain/models/vehicle_note.dart';
import '../../domain/models/vehicle_photo.dart';
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
  final repository = ref.watch(vehicleRepositoryProvider);
  return repository.getAllVehicles();
});

// Vehículos por provincia
final vehiclesByProvinceProvider = FutureProvider.family<List<Vehicle>, int>((ref, provinceId) async {
  final repository = ref.watch(vehicleRepositoryProvider);
  return repository.getVehiclesByProvince(provinceId);
});

// Conteo de vehículos por provincia
final vehicleCountByProvinceProvider = FutureProvider<Map<int, int>>((ref) async {
  final repository = ref.watch(vehicleRepositoryProvider);
  return repository.getVehicleCountByProvince();
});

// Total de vehículos
final totalVehicleCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(vehicleRepositoryProvider);
  return repository.getTotalVehicleCount();
});

// Vehículo por ID
final vehicleByIdProvider = FutureProvider.family<Vehicle?, String>((ref, id) async {
  final repository = ref.watch(vehicleRepositoryProvider);
  return repository.getVehicleById(id);
});

// Búsqueda de vehículos
final vehicleSearchProvider = FutureProvider.family<List<Vehicle>, String>((ref, query) async {
  final repository = ref.watch(vehicleRepositoryProvider);
  if (query.isEmpty) return [];
  return repository.searchVehicles(query);
});

// Historial de un vehículo
final vehicleHistoryProvider = FutureProvider.family<List<VehicleHistory>, String>((ref, vehicleId) async {
  final repository = ref.watch(vehicleRepositoryProvider);
  return repository.getVehicleHistory(vehicleId);
});

// Vehículos con documentos por vencer
final expiringDocumentsProvider = FutureProvider<List<Vehicle>>((ref) async {
  final repository = ref.watch(vehicleRepositoryProvider);
  return repository.getVehiclesWithExpiringDocuments();
});

// Mantenimientos de un vehículo
final maintenancesByVehicleProvider = FutureProvider.family<List<Maintenance>, String>((ref, vehicleId) async {
  final repository = ref.watch(maintenanceRepositoryProvider);
  return repository.getMaintenancesByVehicle(vehicleId);
});

// Notas de un vehículo
final notesByVehicleProvider = FutureProvider.family<List<VehicleNote>, String>((ref, vehicleId) async {
  final repository = ref.watch(noteRepositoryProvider);
  return repository.getNotesByVehicle(vehicleId);
});

// Fotos de un vehículo
final photosByVehicleProvider = FutureProvider.family<List<VehiclePhoto>, String>((ref, vehicleId) async {
  final repository = ref.watch(photoRepositoryProvider);
  return repository.getPhotosByVehicle(vehicleId);
});

// Notifier para manejar el estado mutable de vehículos
class VehicleNotifier extends StateNotifier<AsyncValue<List<Vehicle>>> {
  final VehicleRepository _repository;
  final Ref _ref;

  VehicleNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    loadVehicles();
  }

  Future<void> loadVehicles() async {
    state = const AsyncValue.loading();
    try {
      final vehicles = await _repository.getAllVehicles();
      state = AsyncValue.data(vehicles);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await loadVehicles();
    _invalidateProviders();
  }

  Future<String?> addVehicle(Vehicle vehicle) async {
    try {
      final id = await _repository.insertVehicle(vehicle);
      await loadVehicles();
      _invalidateProviders();
      return id;
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateVehicle(Vehicle vehicle) async {
    try {
      await _repository.updateVehicle(vehicle);
      await loadVehicles();
      _invalidateProviders();
      // Invalidar el provider específico del vehículo actualizado
      if (vehicle.id != null) {
        _ref.invalidate(vehicleByIdProvider(vehicle.id!));
        _ref.invalidate(vehicleHistoryProvider(vehicle.id!));
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteVehicle(String id) async {
    try {
      await _repository.deleteVehicle(id);
      await loadVehicles();
      _invalidateProviders();
      // Invalidar el provider específico del vehículo eliminado
      _ref.invalidate(vehicleByIdProvider(id));
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

// Resultados de búsqueda filtrados
final filteredVehiclesProvider = Provider<AsyncValue<List<Vehicle>>>((ref) {
  final query = ref.watch(searchQueryProvider);
  final vehiclesAsync = ref.watch(vehicleNotifierProvider);
  
  return vehiclesAsync.whenData((vehicles) {
    if (query.isEmpty) return vehicles;
    
    final lowerQuery = query.toLowerCase();
    return vehicles.where((v) =>
      v.plate.toLowerCase().contains(lowerQuery) ||
      v.brand.toLowerCase().contains(lowerQuery) ||
      v.model.toLowerCase().contains(lowerQuery) ||
      v.responsibleName.toLowerCase().contains(lowerQuery) ||
      v.city.toLowerCase().contains(lowerQuery)
    ).toList();
  });
});

// Provincia seleccionada para filtrar
final selectedProvinceProvider = StateProvider<int?>((ref) => null);

// Vehículos filtrados por provincia
final vehiclesBySelectedProvinceProvider = Provider<AsyncValue<List<Vehicle>>>((ref) {
  final selectedProvince = ref.watch(selectedProvinceProvider);
  final vehiclesAsync = ref.watch(vehicleNotifierProvider);

  return vehiclesAsync.whenData((vehicles) {
    if (selectedProvince == null) return vehicles;
    return vehicles.where((v) => v.provinceId == selectedProvince).toList();
  });
});

// Vehículos por ciudad
final vehiclesByCityProvider = FutureProvider.family<List<Vehicle>, String>((ref, cityId) async {
  final repository = ref.watch(vehicleRepositoryProvider);
  return repository.getVehiclesByCity(cityId);
});

// Vehículos por lugar
final vehiclesByLugarProvider = FutureProvider.family<List<Vehicle>, String>((ref, lugarId) async {
  final repository = ref.watch(vehicleRepositoryProvider);
  return repository.getVehiclesByLugar(lugarId);
});

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

// Combined filter: search + location
final filteredBySearchAndLocationProvider = Provider<AsyncValue<List<Vehicle>>>((ref) {
  final query = ref.watch(searchQueryProvider);
  final locationFilter = ref.watch(locationFilterProvider);
  final vehiclesAsync = ref.watch(vehicleNotifierProvider);

  return vehiclesAsync.whenData((vehicles) {
    var filtered = vehicles;

    // Apply location filter
    if (locationFilter.provinceId != null) {
      filtered = filtered.where((v) => v.provinceId == locationFilter.provinceId).toList();
    }

    if (locationFilter.cityId != null) {
      filtered = filtered.where((v) => v.cityId == locationFilter.cityId).toList();
    }

    if (locationFilter.lugarId != null) {
      filtered = filtered.where((v) => v.lugarId == locationFilter.lugarId).toList();
    }

    // Apply search filter
    if (query.isNotEmpty) {
      final lowerQuery = query.toLowerCase();
      filtered = filtered.where((v) =>
        v.plate.toLowerCase().contains(lowerQuery) ||
        v.brand.toLowerCase().contains(lowerQuery) ||
        v.model.toLowerCase().contains(lowerQuery) ||
        v.responsibleName.toLowerCase().contains(lowerQuery) ||
        v.city.toLowerCase().contains(lowerQuery) ||
        (v.lugar?.toLowerCase().contains(lowerQuery) ?? false)
      ).toList();
    }

    return filtered;
  });
});
