import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/location_repository.dart';
import '../../data/services/sync_service.dart';
import '../../domain/models/city.dart';
import '../../domain/models/lugar.dart';

// Repository provider
final locationRepositoryProvider = Provider((ref) {
  final repo = LocationRepository();
  final syncService = ref.read(syncServiceProvider.notifier);
  repo.setSyncService(syncService);
  return repo;
});

// ============================================================
// CITY PROVIDERS
// ============================================================

/// Cities by province
final citiesByProvinceProvider = FutureProvider.family<List<City>, int>((ref, provinceId) async {
  final repository = ref.watch(locationRepositoryProvider);
  return repository.getCitiesByProvince(provinceId);
});

/// Search cities in a province
final citySearchProvider = FutureProvider.family<List<City>, ({int provinceId, String query})>((ref, params) async {
  final repository = ref.watch(locationRepositoryProvider);
  return repository.searchCities(params.provinceId, params.query);
});

/// City by ID
final cityByIdProvider = FutureProvider.family<City?, String>((ref, id) async {
  final repository = ref.watch(locationRepositoryProvider);
  return repository.getCityById(id);
});

/// Vehicle count by city in a province
final vehicleCountByCityProvider = FutureProvider.family<Map<String, int>, int>((ref, provinceId) async {
  final repository = ref.watch(locationRepositoryProvider);
  return repository.getVehicleCountByCity(provinceId);
});

// ============================================================
// LUGAR PROVIDERS
// ============================================================

/// Lugares by city
final lugaresByCityProvider = FutureProvider.family<List<Lugar>, String>((ref, cityId) async {
  final repository = ref.watch(locationRepositoryProvider);
  return repository.getLugaresByCity(cityId);
});

/// Search lugares in a city
final lugarSearchProvider = FutureProvider.family<List<Lugar>, ({String cityId, String query})>((ref, params) async {
  final repository = ref.watch(locationRepositoryProvider);
  return repository.searchLugares(params.cityId, params.query);
});

/// Lugar by ID
final lugarByIdProvider = FutureProvider.family<Lugar?, String>((ref, id) async {
  final repository = ref.watch(locationRepositoryProvider);
  return repository.getLugarById(id);
});

/// Vehicle count by lugar in a city
final vehicleCountByLugarProvider = FutureProvider.family<Map<String, int>, String>((ref, cityId) async {
  final repository = ref.watch(locationRepositoryProvider);
  return repository.getVehicleCountByLugar(cityId);
});

// ============================================================
// FILTER STATE PROVIDERS
// ============================================================

/// Selected city for filtering (null = all cities)
final selectedCityProvider = StateProvider<String?>((ref) => null);

/// Selected lugar for filtering (null = all lugares)
final selectedLugarProvider = StateProvider<String?>((ref) => null);

/// Notifier for managing cities (create, etc.)
class CityNotifier extends StateNotifier<AsyncValue<List<City>>> {
  final LocationRepository _repository;
  final Ref _ref;
  final int provinceId;

  CityNotifier(this._repository, this._ref, this.provinceId) : super(const AsyncValue.loading()) {
    loadCities();
  }

  Future<void> loadCities() async {
    state = const AsyncValue.loading();
    try {
      final cities = await _repository.getCitiesByProvince(provinceId);
      state = AsyncValue.data(cities);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<City?> getOrCreateCity(String name) async {
    try {
      final city = await _repository.getOrCreateCity(provinceId, name);
      await loadCities();
      _ref.invalidate(citiesByProvinceProvider(provinceId));
      return city;
    } catch (e) {
      return null;
    }
  }

  Future<void> refresh() async {
    await loadCities();
    _ref.invalidate(citiesByProvinceProvider(provinceId));
  }
}

final cityNotifierProvider = StateNotifierProvider.family<CityNotifier, AsyncValue<List<City>>, int>((ref, provinceId) {
  final repository = ref.watch(locationRepositoryProvider);
  return CityNotifier(repository, ref, provinceId);
});

/// Notifier for managing lugares (create, etc.)
class LugarNotifier extends StateNotifier<AsyncValue<List<Lugar>>> {
  final LocationRepository _repository;
  final Ref _ref;
  final String cityId;

  LugarNotifier(this._repository, this._ref, this.cityId) : super(const AsyncValue.loading()) {
    loadLugares();
  }

  Future<void> loadLugares() async {
    state = const AsyncValue.loading();
    try {
      final lugares = await _repository.getLugaresByCity(cityId);
      state = AsyncValue.data(lugares);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Lugar?> getOrCreateLugar(String name) async {
    try {
      final lugar = await _repository.getOrCreateLugar(cityId, name);
      await loadLugares();
      _ref.invalidate(lugaresByCityProvider(cityId));
      return lugar;
    } catch (e) {
      return null;
    }
  }

  Future<void> refresh() async {
    await loadLugares();
    _ref.invalidate(lugaresByCityProvider(cityId));
  }
}

final lugarNotifierProvider = StateNotifierProvider.family<LugarNotifier, AsyncValue<List<Lugar>>, String>((ref, cityId) {
  final repository = ref.watch(locationRepositoryProvider);
  return LugarNotifier(repository, ref, cityId);
});

// ============================================================
// COMBINED LOCATION STATE
// ============================================================

/// Class to hold selected location hierarchy
class LocationFilter {
  final int? provinceId;
  final String? cityId;
  final String? lugarId;

  const LocationFilter({
    this.provinceId,
    this.cityId,
    this.lugarId,
  });

  LocationFilter copyWith({
    int? provinceId,
    String? cityId,
    String? lugarId,
    bool clearProvince = false,
    bool clearCity = false,
    bool clearLugar = false,
  }) {
    return LocationFilter(
      provinceId: clearProvince ? null : (provinceId ?? this.provinceId),
      cityId: clearCity ? null : (cityId ?? this.cityId),
      lugarId: clearLugar ? null : (lugarId ?? this.lugarId),
    );
  }

  bool get hasFilter => provinceId != null || cityId != null || lugarId != null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocationFilter &&
        other.provinceId == provinceId &&
        other.cityId == cityId &&
        other.lugarId == lugarId;
  }

  @override
  int get hashCode => Object.hash(provinceId, cityId, lugarId);
}

/// Combined location filter state provider
final locationFilterProvider = StateNotifierProvider<LocationFilterNotifier, LocationFilter>((ref) {
  return LocationFilterNotifier();
});

class LocationFilterNotifier extends StateNotifier<LocationFilter> {
  LocationFilterNotifier() : super(const LocationFilter());

  void setProvince(int? provinceId) {
    // Cascading reset: changing province clears city & lugar
    state = LocationFilter(provinceId: provinceId);
  }

  void setCity(String? cityId) {
    // Cascading reset: changing city clears lugar
    state = state.copyWith(cityId: cityId, clearLugar: true);
  }

  void setLugar(String? lugarId) {
    state = state.copyWith(lugarId: lugarId);
  }

  void clearAll() {
    state = const LocationFilter();
  }

  void clearCity() {
    state = state.copyWith(clearCity: true, clearLugar: true);
  }

  void clearLugar() {
    state = state.copyWith(clearLugar: true);
  }
}
