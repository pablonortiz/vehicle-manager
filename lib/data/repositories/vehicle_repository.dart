import 'package:flutter/foundation.dart';
import '../../domain/expiry_status.dart';
import 'package:uuid/uuid.dart';
import '../database/database.dart';
import '../services/db_change_service.dart';
import '../services/sync_service.dart';
import '../../core/config/supabase_config.dart';
import '../../core/constants/vehicle_constants.dart';
import '../../domain/models/vehicle.dart';
import '../../domain/models/vehicle_history.dart';
import 'syncable_repository.dart';

class VehicleRepository with SyncableRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final _uuid = const Uuid();
  SyncService? _syncService;

  void setSyncService(SyncService syncService) {
    _syncService = syncService;
  }

  @override
  SyncService? get syncService => _syncService;

  Future<List<Vehicle>> getAllVehicles() async {
    final db = await _dbHelper.database;
    final maps = await db.query('vehicles', orderBy: 'updated_at DESC');
    return maps.map((map) => Vehicle.fromMap(map)).toList();
  }

  Future<List<Vehicle>> getVehiclesByProvince(int provinceId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'vehicles',
      where: 'province_id = ?',
      whereArgs: [provinceId],
      orderBy: 'updated_at DESC',
    );
    return maps.map((map) => Vehicle.fromMap(map)).toList();
  }

  Future<List<Vehicle>> getVehiclesByStatus(int statusIndex) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'vehicles',
      where: 'status = ?',
      whereArgs: [statusIndex],
      orderBy: 'updated_at DESC',
    );
    return maps.map((map) => Vehicle.fromMap(map)).toList();
  }

  Future<List<Vehicle>> getVehiclesByCity(String cityId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'vehicles',
      where: 'city_id = ?',
      whereArgs: [cityId],
      orderBy: 'updated_at DESC',
    );
    return maps.map((map) => Vehicle.fromMap(map)).toList();
  }

  Future<List<Vehicle>> getVehiclesByLugar(String lugarId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'vehicles',
      where: 'lugar_id = ?',
      whereArgs: [lugarId],
      orderBy: 'updated_at DESC',
    );
    return maps.map((map) => Vehicle.fromMap(map)).toList();
  }

  /// Get vehicles filtered by province, city, and/or lugar
  Future<List<Vehicle>> getVehiclesFiltered({
    int? provinceId,
    String? cityId,
    String? lugarId,
  }) async {
    final db = await _dbHelper.database;
    final List<String> conditions = [];
    final List<dynamic> args = [];

    if (provinceId != null) {
      conditions.add('province_id = ?');
      args.add(provinceId);
    }
    if (cityId != null) {
      conditions.add('city_id = ?');
      args.add(cityId);
    }
    if (lugarId != null) {
      conditions.add('lugar_id = ?');
      args.add(lugarId);
    }

    final maps = await db.query(
      'vehicles',
      where: conditions.isNotEmpty ? conditions.join(' AND ') : null,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'updated_at DESC',
    );
    return maps.map((map) => Vehicle.fromMap(map)).toList();
  }

  Future<Vehicle?> getVehicleById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'vehicles',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Vehicle.fromMap(maps.first);
  }

  Future<Vehicle?> getVehicleByPlate(String plate) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'vehicles',
      where: 'plate = ?',
      whereArgs: [plate.toUpperCase()],
    );
    if (maps.isEmpty) return null;
    return Vehicle.fromMap(maps.first);
  }

  Future<String> insertVehicle(Vehicle vehicle) async {
    debugPrint('🚗 [REPO] Insertando vehículo: ${vehicle.plate}');
    
    final id = _uuid.v4();
    final newVehicle = vehicle.copyWith(id: id);
    final historyId = _uuid.v4();

    final db = await _dbHelper.database;
    
    final map = newVehicle.toMap();
    map['plate'] = (map['plate'] as String).toUpperCase();
    map['synced'] = 0;
    
    await db.insert('vehicles', map);
    debugPrint('✅ [REPO] Vehículo guardado localmente con ID: $id');
    
    // Registrar en historial como creación
    await _insertHistory(VehicleHistory(
      id: historyId,
      vehicleId: id,
      field: 'created',
      oldValue: '',
      newValue: 'Vehículo creado',
    ));
    
    // Sincronizar con Supabase
    await pushWrite(
      table: 'vehicles',
      recordId: id,
      operation: 'insert',
      data: newVehicle.toSupabase(),
      remoteOp: () async {
        debugPrint('📤 [REPO] Intentando subir a Supabase...');
        debugPrint('📤 [REPO] Datos: ${newVehicle.toSupabase()}');

        await SupabaseConfig.client.from('vehicles').insert(newVehicle.toSupabase());
        debugPrint('✅ [REPO] Vehículo subido a Supabase exitosamente');

        await SupabaseConfig.client.from('vehicle_history').insert({
          'id': historyId,
          'vehicle_id': id,
          'field': 'created',
          'old_value': '',
          'new_value': 'Vehículo creado',
        });
      },
      markSynced: () async {
        await db.update('vehicles', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
        debugPrint('✅ [REPO] Marcado como sincronizado');
      },
    );

    DbChangeService.instance.notifyChange('vehicles');
    return id;
  }

  Future<int> updateVehicle(Vehicle vehicle) async {
    if (vehicle.id == null) throw Exception('Vehicle ID is required');
    
    final db = await _dbHelper.database;
    
    // Obtener vehículo anterior para comparar cambios
    final oldVehicle = await getVehicleById(vehicle.id!);
    
    final updatedVehicle = vehicle.copyWith(updatedAt: DateTime.now());
    final map = updatedVehicle.toMap();
    map['plate'] = (map['plate'] as String).toUpperCase();
    map['synced'] = 0;
    
    final result = await db.update(
      'vehicles',
      map,
      where: 'id = ?',
      whereArgs: [vehicle.id],
    );
    
    // Registrar cambios en historial
    if (oldVehicle != null) {
      await _recordChanges(oldVehicle, updatedVehicle);
    }
    
    // Sincronizar con Supabase
    await pushWrite(
      table: 'vehicles',
      recordId: vehicle.id!,
      operation: 'update',
      data: updatedVehicle.toSupabase(),
      remoteOp: () async {
        await SupabaseConfig.client
            .from('vehicles')
            .update(updatedVehicle.toSupabase())
            .eq('id', vehicle.id!);
      },
      markSynced: () async {
        await db.update('vehicles', {'synced': 1}, where: 'id = ?', whereArgs: [vehicle.id]);
      },
    );

    DbChangeService.instance.notifyChange('vehicles');
    return result;
  }

  Future<int> deleteVehicle(String id) async {
    final db = await _dbHelper.database;

    // Con foreign_keys=ON (ver DatabaseHelper._onConfigure), borrar el vehículo
    // elimina en cascada su historial, mantenimientos (y facturas), notas (y sus
    // fotos), fotos, documentos y cargas de combustible vía los ON DELETE CASCADE
    // del schema. Un único delete es atómico, sin riesgo de borrado parcial.
    final result = await db.delete('vehicles', where: 'id = ?', whereArgs: [id]);

    // Sincronizar con Supabase
    await pushWrite(
      table: 'vehicles',
      recordId: id,
      operation: 'delete',
      data: {},
      remoteOp: () async {
        await SupabaseConfig.client.from('vehicles').delete().eq('id', id);
      },
    );

    DbChangeService.instance.notifyChange('vehicles');
    return result;
  }

  Future<List<Vehicle>> searchVehicles(String query) async {
    final db = await _dbHelper.database;
    final searchQuery = '%${query.toLowerCase()}%';

    final maps = await db.rawQuery('''
      SELECT * FROM vehicles
      WHERE LOWER(plate) LIKE ?
         OR LOWER(brand) LIKE ?
         OR LOWER(model) LIKE ?
         OR LOWER(responsible_name) LIKE ?
         OR LOWER(city) LIKE ?
         OR LOWER(lugar) LIKE ?
      ORDER BY updated_at DESC
    ''', [searchQuery, searchQuery, searchQuery, searchQuery, searchQuery, searchQuery]);

    return maps.map((map) => Vehicle.fromMap(map)).toList();
  }

  Future<Map<int, int>> getVehicleCountByProvince() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT province_id, COUNT(*) as count 
      FROM vehicles 
      GROUP BY province_id
    ''');
    
    return {
      for (var row in result)
        row['province_id'] as int: row['count'] as int
    };
  }

  Future<int> getTotalVehicleCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM vehicles');
    return result.first['count'] as int;
  }

  Future<List<Vehicle>> getVehiclesWithExpiringDocuments() async {
    final db = await _dbHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    // Un día de margen: la ventana exacta (30 días de calendario) la decide
    // ExpiryStatus al filtrar, así todas las pantallas cuentan igual.
    final thirtyDaysLater = DateTime.now()
        .add(const Duration(days: ExpiryStatus.warningDays + 1))
        .millisecondsSinceEpoch;
    
    final maps = await db.rawQuery('''
      SELECT * FROM vehicles 
      WHERE (vtv_expiry IS NOT NULL AND vtv_expiry BETWEEN ? AND ?)
         OR (insurance_expiry IS NOT NULL AND insurance_expiry BETWEEN ? AND ?)
         OR (vtv_expiry IS NOT NULL AND vtv_expiry < ?)
         OR (insurance_expiry IS NOT NULL AND insurance_expiry < ?)
      ORDER BY vtv_expiry ASC, insurance_expiry ASC
    ''', [now, thirtyDaysLater, now, thirtyDaysLater, now, now]);
    
    return maps
        .map((map) => Vehicle.fromMap(map))
        .where((vehicle) => vehicle.expiringDocuments.isNotEmpty)
        .toList();
  }

  // Historial
  Future<void> _insertHistory(VehicleHistory history) async {
    final db = await _dbHelper.database;
    final map = history.toMap();
    map['synced'] = 0;
    await db.insert('vehicle_history', map);

    // Sincronizar con Supabase
    await pushWrite(
      table: 'vehicle_history',
      recordId: history.id!,
      operation: 'insert',
      data: history.toSupabase(),
      remoteOp: () async {
        await SupabaseConfig.client.from('vehicle_history').insert(history.toSupabase());
      },
      markSynced: () async {
        await db.update('vehicle_history', {'synced': 1}, where: 'id = ?', whereArgs: [history.id]);
      },
    );
  }

  Future<void> _recordChanges(Vehicle oldVehicle, Vehicle newVehicle) async {
    final changes = <VehicleHistory>[];
    
    if (oldVehicle.plate != newVehicle.plate) {
      changes.add(VehicleHistory(
        id: _uuid.v4(),
        vehicleId: newVehicle.id!,
        field: 'plate',
        oldValue: oldVehicle.plate,
        newValue: newVehicle.plate,
      ));
    }
    
    if (oldVehicle.type != newVehicle.type) {
      changes.add(VehicleHistory(
        id: _uuid.v4(),
        vehicleId: newVehicle.id!,
        field: 'type',
        oldValue: oldVehicle.type.label,
        newValue: newVehicle.type.label,
      ));
    }
    
    if (oldVehicle.brand != newVehicle.brand) {
      changes.add(VehicleHistory(
        id: _uuid.v4(),
        vehicleId: newVehicle.id!,
        field: 'brand',
        oldValue: oldVehicle.brand,
        newValue: newVehicle.brand,
      ));
    }
    
    if (oldVehicle.model != newVehicle.model) {
      changes.add(VehicleHistory(
        id: _uuid.v4(),
        vehicleId: newVehicle.id!,
        field: 'model',
        oldValue: oldVehicle.model,
        newValue: newVehicle.model,
      ));
    }
    
    if (oldVehicle.year != newVehicle.year) {
      changes.add(VehicleHistory(
        id: _uuid.v4(),
        vehicleId: newVehicle.id!,
        field: 'year',
        oldValue: oldVehicle.year.toString(),
        newValue: newVehicle.year.toString(),
      ));
    }
    
    if (oldVehicle.color.toARGB32() != newVehicle.color.toARGB32()) {
      changes.add(VehicleHistory(
        id: _uuid.v4(),
        vehicleId: newVehicle.id!,
        field: 'color',
        oldValue: oldVehicle.color.toARGB32().toString(),
        newValue: newVehicle.color.toARGB32().toString(),
      ));
    }
    
    if (oldVehicle.km != newVehicle.km) {
      changes.add(VehicleHistory(
        id: _uuid.v4(),
        vehicleId: newVehicle.id!,
        field: 'km',
        oldValue: oldVehicle.km.toString(),
        newValue: newVehicle.km.toString(),
      ));
    }
    
    if (oldVehicle.status != newVehicle.status) {
      changes.add(VehicleHistory(
        id: _uuid.v4(),
        vehicleId: newVehicle.id!,
        field: 'status',
        oldValue: oldVehicle.status.label,
        newValue: newVehicle.status.label,
      ));
    }
    
    if (oldVehicle.provinceId != newVehicle.provinceId) {
      changes.add(VehicleHistory(
        id: _uuid.v4(),
        vehicleId: newVehicle.id!,
        field: 'provinceId',
        oldValue: oldVehicle.provinceId.toString(),
        newValue: newVehicle.provinceId.toString(),
      ));
    }
    
    if (oldVehicle.city != newVehicle.city) {
      changes.add(VehicleHistory(
        id: _uuid.v4(),
        vehicleId: newVehicle.id!,
        field: 'city',
        oldValue: oldVehicle.city,
        newValue: newVehicle.city,
      ));
    }

    if (oldVehicle.lugar != newVehicle.lugar) {
      changes.add(VehicleHistory(
        id: _uuid.v4(),
        vehicleId: newVehicle.id!,
        field: 'lugar',
        oldValue: oldVehicle.lugar ?? 'Sin lugar',
        newValue: newVehicle.lugar ?? 'Sin lugar',
      ));
    }

    if (oldVehicle.responsibleName != newVehicle.responsibleName) {
      changes.add(VehicleHistory(
        id: _uuid.v4(),
        vehicleId: newVehicle.id!,
        field: 'responsibleName',
        oldValue: oldVehicle.responsibleName,
        newValue: newVehicle.responsibleName,
      ));
    }
    
    if (oldVehicle.responsiblePhone != newVehicle.responsiblePhone) {
      changes.add(VehicleHistory(
        id: _uuid.v4(),
        vehicleId: newVehicle.id!,
        field: 'responsiblePhone',
        oldValue: oldVehicle.responsiblePhone,
        newValue: newVehicle.responsiblePhone,
      ));
    }
    
    if (oldVehicle.vtvExpiry?.toIso8601String() != newVehicle.vtvExpiry?.toIso8601String()) {
      changes.add(VehicleHistory(
        id: _uuid.v4(),
        vehicleId: newVehicle.id!,
        field: 'vtvExpiry',
        oldValue: oldVehicle.vtvExpiry?.toIso8601String() ?? 'Sin fecha',
        newValue: newVehicle.vtvExpiry?.toIso8601String() ?? 'Sin fecha',
      ));
    }
    
    if (oldVehicle.insuranceCompany != newVehicle.insuranceCompany) {
      changes.add(VehicleHistory(
        id: _uuid.v4(),
        vehicleId: newVehicle.id!,
        field: 'insuranceCompany',
        oldValue: oldVehicle.insuranceCompany ?? 'Sin compañía',
        newValue: newVehicle.insuranceCompany ?? 'Sin compañía',
      ));
    }
    
    if (oldVehicle.insuranceExpiry?.toIso8601String() != newVehicle.insuranceExpiry?.toIso8601String()) {
      changes.add(VehicleHistory(
        id: _uuid.v4(),
        vehicleId: newVehicle.id!,
        field: 'insuranceExpiry',
        oldValue: oldVehicle.insuranceExpiry?.toIso8601String() ?? 'Sin fecha',
        newValue: newVehicle.insuranceExpiry?.toIso8601String() ?? 'Sin fecha',
      ));
    }
    
    if (oldVehicle.fuelType != newVehicle.fuelType) {
      changes.add(VehicleHistory(
        id: _uuid.v4(),
        vehicleId: newVehicle.id!,
        field: 'fuelType',
        oldValue: oldVehicle.fuelType.label,
        newValue: newVehicle.fuelType.label,
      ));
    }
    
    for (final change in changes) {
      await _insertHistory(change);
    }
  }

  Future<List<VehicleHistory>> getVehicleHistory(String vehicleId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'vehicle_history',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'changed_at DESC',
    );
    return maps.map((map) => VehicleHistory.fromMap(map)).toList();
  }

  Future<List<VehicleHistory>> getAllHistory() async {
    final db = await _dbHelper.database;
    final maps = await db.query('vehicle_history', orderBy: 'changed_at DESC');
    return maps.map((map) => VehicleHistory.fromMap(map)).toList();
  }
}
