import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../database/database.dart';
import '../services/sync_service.dart';
import '../../core/config/supabase_config.dart';
import '../../core/utils/text_normalizer.dart';
import '../../domain/models/city.dart';
import '../../domain/models/lugar.dart';

class LocationRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final _uuid = const Uuid();
  SyncService? _syncService;

  void setSyncService(SyncService syncService) {
    _syncService = syncService;
  }

  Future<bool> get _isOnline async {
    if (kIsWeb) return SupabaseConfig.isConfigured;
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none && SupabaseConfig.isConfigured;
  }

  // ============================================================
  // CITIES
  // ============================================================

  /// Get all cities for a province
  Future<List<City>> getCitiesByProvince(int provinceId) async {
    if (kIsWeb) {
      if (!SupabaseConfig.isConfigured) return [];
      final data = await SupabaseConfig.client
          .from('cities')
          .select()
          .eq('province_id', provinceId)
          .order('name');
      return (data as List).map((e) => City.fromSupabase(e)).toList();
    }

    final db = await _dbHelper.database;
    final maps = await db.query(
      'cities',
      where: 'province_id = ?',
      whereArgs: [provinceId],
      orderBy: 'name ASC',
    );
    return maps.map((map) => City.fromMap(map)).toList();
  }

  /// Search cities by query within a province
  Future<List<City>> searchCities(int provinceId, String query) async {
    if (query.isEmpty) return getCitiesByProvince(provinceId);

    final normalizedQuery = TextNormalizer.normalize(query);

    if (kIsWeb) {
      if (!SupabaseConfig.isConfigured) return [];
      final data = await SupabaseConfig.client
          .from('cities')
          .select()
          .eq('province_id', provinceId)
          .ilike('name_normalized', '%$normalizedQuery%')
          .order('name')
          .limit(20);
      return (data as List).map((e) => City.fromSupabase(e)).toList();
    }

    final db = await _dbHelper.database;
    final maps = await db.query(
      'cities',
      where: 'province_id = ? AND name_normalized LIKE ?',
      whereArgs: [provinceId, '%$normalizedQuery%'],
      orderBy: 'name ASC',
      limit: 20,
    );
    return maps.map((map) => City.fromMap(map)).toList();
  }

  /// Get city by ID
  Future<City?> getCityById(String id) async {
    if (kIsWeb) {
      if (!SupabaseConfig.isConfigured) return null;
      final data = await SupabaseConfig.client
          .from('cities')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (data == null) return null;
      return City.fromSupabase(data);
    }

    final db = await _dbHelper.database;
    final maps = await db.query(
      'cities',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return City.fromMap(maps.first);
  }

  /// Find city by normalized name in a province
  Future<City?> findCityByName(int provinceId, String name) async {
    final normalizedName = TextNormalizer.normalize(name);

    if (kIsWeb) {
      if (!SupabaseConfig.isConfigured) return null;
      final data = await SupabaseConfig.client
          .from('cities')
          .select()
          .eq('province_id', provinceId)
          .eq('name_normalized', normalizedName)
          .maybeSingle();
      if (data == null) return null;
      return City.fromSupabase(data);
    }

    final db = await _dbHelper.database;
    final maps = await db.query(
      'cities',
      where: 'province_id = ? AND name_normalized = ?',
      whereArgs: [provinceId, normalizedName],
    );
    if (maps.isEmpty) return null;
    return City.fromMap(maps.first);
  }

  /// Get or create a city by name (used for autocomplete behavior)
  Future<City> getOrCreateCity(int provinceId, String name) async {
    // Try to find existing city
    final existing = await findCityByName(provinceId, name);
    if (existing != null) return existing;

    // Create new city
    return await insertCity(City(
      provinceId: provinceId,
      name: name,
    ));
  }

  /// Insert a new city
  Future<City> insertCity(City city) async {
    final id = _uuid.v4();
    final newCity = city.copyWith(id: id);

    if (kIsWeb) {
      if (!SupabaseConfig.isConfigured) throw Exception('Supabase no configurado');
      await SupabaseConfig.client.from('cities').insert(newCity.toSupabase());
      return newCity;
    }

    final db = await _dbHelper.database;
    final map = newCity.toMap();
    map['synced'] = 0;

    await db.insert('cities', map);

    // Sync with Supabase
    if (await _isOnline) {
      try {
        await SupabaseConfig.client.from('cities').insert(newCity.toSupabase());
        await db.update('cities', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
      } catch (e) {
        debugPrint('Error syncing city: $e');
        _syncService?.addToSyncQueue(
          tableName: 'cities',
          recordId: id,
          operation: 'insert',
          data: newCity.toSupabase(),
        );
      }
    } else {
      _syncService?.addToSyncQueue(
        tableName: 'cities',
        recordId: id,
        operation: 'insert',
        data: newCity.toSupabase(),
      );
    }

    return newCity;
  }

  /// Get count of vehicles per city in a province
  Future<Map<String, int>> getVehicleCountByCity(int provinceId) async {
    if (kIsWeb) {
      if (!SupabaseConfig.isConfigured) return {};
      final data = await SupabaseConfig.client.rpc('get_vehicle_count_by_city', params: {
        'p_province_id': provinceId,
      });
      return {
        for (var row in (data as List))
          row['city_id'] as String: row['count'] as int
      };
    }

    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT city_id, COUNT(*) as count
      FROM vehicles
      WHERE province_id = ? AND city_id IS NOT NULL
      GROUP BY city_id
    ''', [provinceId]);

    return {
      for (var row in result)
        row['city_id'] as String: row['count'] as int
    };
  }

  // ============================================================
  // LUGARES
  // ============================================================

  /// Get all lugares for a city
  Future<List<Lugar>> getLugaresByCity(String cityId) async {
    if (kIsWeb) {
      if (!SupabaseConfig.isConfigured) return [];
      final data = await SupabaseConfig.client
          .from('lugares')
          .select()
          .eq('city_id', cityId)
          .order('name');
      return (data as List).map((e) => Lugar.fromSupabase(e)).toList();
    }

    final db = await _dbHelper.database;
    final maps = await db.query(
      'lugares',
      where: 'city_id = ?',
      whereArgs: [cityId],
      orderBy: 'name ASC',
    );
    return maps.map((map) => Lugar.fromMap(map)).toList();
  }

  /// Search lugares by query within a city
  Future<List<Lugar>> searchLugares(String cityId, String query) async {
    if (query.isEmpty) return getLugaresByCity(cityId);

    final normalizedQuery = TextNormalizer.normalize(query);

    if (kIsWeb) {
      if (!SupabaseConfig.isConfigured) return [];
      final data = await SupabaseConfig.client
          .from('lugares')
          .select()
          .eq('city_id', cityId)
          .ilike('name_normalized', '%$normalizedQuery%')
          .order('name')
          .limit(20);
      return (data as List).map((e) => Lugar.fromSupabase(e)).toList();
    }

    final db = await _dbHelper.database;
    final maps = await db.query(
      'lugares',
      where: 'city_id = ? AND name_normalized LIKE ?',
      whereArgs: [cityId, '%$normalizedQuery%'],
      orderBy: 'name ASC',
      limit: 20,
    );
    return maps.map((map) => Lugar.fromMap(map)).toList();
  }

  /// Get lugar by ID
  Future<Lugar?> getLugarById(String id) async {
    if (kIsWeb) {
      if (!SupabaseConfig.isConfigured) return null;
      final data = await SupabaseConfig.client
          .from('lugares')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (data == null) return null;
      return Lugar.fromSupabase(data);
    }

    final db = await _dbHelper.database;
    final maps = await db.query(
      'lugares',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Lugar.fromMap(maps.first);
  }

  /// Find lugar by normalized name in a city
  Future<Lugar?> findLugarByName(String cityId, String name) async {
    final normalizedName = TextNormalizer.normalize(name);

    if (kIsWeb) {
      if (!SupabaseConfig.isConfigured) return null;
      final data = await SupabaseConfig.client
          .from('lugares')
          .select()
          .eq('city_id', cityId)
          .eq('name_normalized', normalizedName)
          .maybeSingle();
      if (data == null) return null;
      return Lugar.fromSupabase(data);
    }

    final db = await _dbHelper.database;
    final maps = await db.query(
      'lugares',
      where: 'city_id = ? AND name_normalized = ?',
      whereArgs: [cityId, normalizedName],
    );
    if (maps.isEmpty) return null;
    return Lugar.fromMap(maps.first);
  }

  /// Get or create a lugar by name (used for autocomplete behavior)
  Future<Lugar> getOrCreateLugar(String cityId, String name) async {
    // Try to find existing lugar
    final existing = await findLugarByName(cityId, name);
    if (existing != null) return existing;

    // Create new lugar
    return await insertLugar(Lugar(
      cityId: cityId,
      name: name,
    ));
  }

  /// Insert a new lugar
  Future<Lugar> insertLugar(Lugar lugar) async {
    final id = _uuid.v4();
    final newLugar = lugar.copyWith(id: id);

    if (kIsWeb) {
      if (!SupabaseConfig.isConfigured) throw Exception('Supabase no configurado');
      await SupabaseConfig.client.from('lugares').insert(newLugar.toSupabase());
      return newLugar;
    }

    final db = await _dbHelper.database;
    final map = newLugar.toMap();
    map['synced'] = 0;

    await db.insert('lugares', map);

    // Sync with Supabase
    if (await _isOnline) {
      try {
        await SupabaseConfig.client.from('lugares').insert(newLugar.toSupabase());
        await db.update('lugares', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
      } catch (e) {
        debugPrint('Error syncing lugar: $e');
        _syncService?.addToSyncQueue(
          tableName: 'lugares',
          recordId: id,
          operation: 'insert',
          data: newLugar.toSupabase(),
        );
      }
    } else {
      _syncService?.addToSyncQueue(
        tableName: 'lugares',
        recordId: id,
        operation: 'insert',
        data: newLugar.toSupabase(),
      );
    }

    return newLugar;
  }

  /// Get count of vehicles per lugar in a city
  Future<Map<String, int>> getVehicleCountByLugar(String cityId) async {
    if (kIsWeb) {
      if (!SupabaseConfig.isConfigured) return {};
      final data = await SupabaseConfig.client.rpc('get_vehicle_count_by_lugar', params: {
        'p_city_id': cityId,
      });
      return {
        for (var row in (data as List))
          row['lugar_id'] as String: row['count'] as int
      };
    }

    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT lugar_id, COUNT(*) as count
      FROM vehicles
      WHERE city_id = ? AND lugar_id IS NOT NULL
      GROUP BY lugar_id
    ''', [cityId]);

    return {
      for (var row in result)
        row['lugar_id'] as String: row['count'] as int
    };
  }

  // ============================================================
  // SYNC SUPPORT
  // ============================================================

  /// Get all cities (for sync)
  Future<List<City>> getAllCities() async {
    if (kIsWeb) {
      if (!SupabaseConfig.isConfigured) return [];
      final data = await SupabaseConfig.client.from('cities').select().order('name');
      return (data as List).map((e) => City.fromSupabase(e)).toList();
    }

    final db = await _dbHelper.database;
    final maps = await db.query('cities', orderBy: 'name ASC');
    return maps.map((map) => City.fromMap(map)).toList();
  }

  /// Get all lugares (for sync)
  Future<List<Lugar>> getAllLugares() async {
    if (kIsWeb) {
      if (!SupabaseConfig.isConfigured) return [];
      final data = await SupabaseConfig.client.from('lugares').select().order('name');
      return (data as List).map((e) => Lugar.fromSupabase(e)).toList();
    }

    final db = await _dbHelper.database;
    final maps = await db.query('lugares', orderBy: 'name ASC');
    return maps.map((map) => Lugar.fromMap(map)).toList();
  }

  /// Get unsynced cities
  Future<List<City>> getUnsyncedCities() async {
    if (kIsWeb) return [];
    final db = await _dbHelper.database;
    final maps = await db.query('cities', where: 'synced = 0');
    return maps.map((map) => City.fromMap(map)).toList();
  }

  /// Get unsynced lugares
  Future<List<Lugar>> getUnsyncedLugares() async {
    if (kIsWeb) return [];
    final db = await _dbHelper.database;
    final maps = await db.query('lugares', where: 'synced = 0');
    return maps.map((map) => Lugar.fromMap(map)).toList();
  }

  /// Mark city as synced
  Future<void> markCitySynced(String id) async {
    if (kIsWeb) return;
    final db = await _dbHelper.database;
    await db.update('cities', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  /// Mark lugar as synced
  Future<void> markLugarSynced(String id) async {
    if (kIsWeb) return;
    final db = await _dbHelper.database;
    await db.update('lugares', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  /// Insert city from Supabase (during sync)
  Future<void> insertCityFromSupabase(City city) async {
    if (kIsWeb) return;
    final db = await _dbHelper.database;
    final map = city.toMap();
    map['synced'] = 1;
    await db.insert('cities', map);
  }

  /// Insert lugar from Supabase (during sync)
  Future<void> insertLugarFromSupabase(Lugar lugar) async {
    if (kIsWeb) return;
    final db = await _dbHelper.database;
    final map = lugar.toMap();
    map['synced'] = 1;
    await db.insert('lugares', map);
  }

  /// Clear all cities and lugares (for full sync)
  Future<void> clearAll() async {
    if (kIsWeb) return;
    final db = await _dbHelper.database;
    await db.delete('lugares');
    await db.delete('cities');
  }
}
