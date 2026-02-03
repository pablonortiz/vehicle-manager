import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../database/database.dart';
import '../services/sync_service.dart';
import '../../core/config/supabase_config.dart';
import '../../domain/models/fuel_charge.dart';

class FuelChargeRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final _uuid = const Uuid();
  SyncService? _syncService;

  void setSyncService(SyncService syncService) {
    _syncService = syncService;
  }

  Future<bool> get _isOnline async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none && SupabaseConfig.isConfigured;
  }

  // Obtener cargas de combustible de un vehículo
  Future<List<FuelCharge>> getFuelChargesByVehicle(String vehicleId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'fuel_charges',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'date DESC',
    );
    return maps.map((map) => FuelCharge.fromMap(map)).toList();
  }

  // Obtener cargas de combustible por mes
  Future<List<FuelCharge>> getFuelChargesByMonth(
    String vehicleId,
    int year,
    int month,
  ) async {
    final db = await _dbHelper.database;
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);

    final maps = await db.query(
      'fuel_charges',
      where: 'vehicle_id = ? AND date >= ? AND date <= ?',
      whereArgs: [
        vehicleId,
        startOfMonth.millisecondsSinceEpoch,
        endOfMonth.millisecondsSinceEpoch,
      ],
      orderBy: 'date DESC',
    );
    return maps.map((map) => FuelCharge.fromMap(map)).toList();
  }

  // Obtener cargas de combustible por rango de fechas
  Future<List<FuelCharge>> getFuelChargesByDateRange(
    String vehicleId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'fuel_charges',
      where: 'vehicle_id = ? AND date >= ? AND date <= ?',
      whereArgs: [
        vehicleId,
        startDate.millisecondsSinceEpoch,
        endDate.millisecondsSinceEpoch,
      ],
      orderBy: 'date DESC',
    );
    return maps.map((map) => FuelCharge.fromMap(map)).toList();
  }

  // Obtener resumen mensual
  Future<FuelChargeSummary> getMonthlySummary(
    String vehicleId,
    int year,
    int month,
  ) async {
    final db = await _dbHelper.database;
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);

    final result = await db.rawQuery('''
      SELECT
        COALESCE(SUM(liters), 0) as totalLiters,
        COALESCE(SUM(price), 0) as totalPrice,
        COUNT(*) as chargeCount
      FROM fuel_charges
      WHERE vehicle_id = ?
        AND date >= ?
        AND date <= ?
    ''', [
      vehicleId,
      startOfMonth.millisecondsSinceEpoch,
      endOfMonth.millisecondsSinceEpoch,
    ]);

    if (result.isEmpty) {
      return FuelChargeSummary.empty(year, month);
    }

    final row = result.first;
    return FuelChargeSummary(
      totalLiters: (row['totalLiters'] as num).toDouble(),
      totalPrice: (row['totalPrice'] as num).toDouble(),
      chargeCount: row['chargeCount'] as int,
      year: year,
      month: month,
    );
  }

  // Obtener datos mensuales para gráficos (últimos N meses)
  Future<List<MonthlyFuelData>> getMonthlyChartData(
    String vehicleId, {
    int months = 6,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final data = <MonthlyFuelData>[];

    for (int i = months - 1; i >= 0; i--) {
      final targetDate = DateTime(now.year, now.month - i, 1);
      final year = targetDate.year;
      final month = targetDate.month;

      final startOfMonth = DateTime(year, month, 1);
      final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);

      final result = await db.rawQuery('''
        SELECT
          COALESCE(SUM(liters), 0) as totalLiters,
          COALESCE(SUM(price), 0) as totalPrice
        FROM fuel_charges
        WHERE vehicle_id = ?
          AND date >= ?
          AND date <= ?
      ''', [
        vehicleId,
        startOfMonth.millisecondsSinceEpoch,
        endOfMonth.millisecondsSinceEpoch,
      ]);

      final row = result.first;
      final totalLiters = (row['totalLiters'] as num).toDouble();
      final totalPrice = (row['totalPrice'] as num).toDouble();

      data.add(MonthlyFuelData(
        year: year,
        month: month,
        totalLiters: totalLiters,
        totalPrice: totalPrice,
        averagePricePerLiter: totalLiters > 0 ? totalPrice / totalLiters : 0,
      ));
    }

    return data;
  }

  // Obtener una carga por ID
  Future<FuelCharge?> getFuelChargeById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'fuel_charges',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return FuelCharge.fromMap(maps.first);
  }

  // Insertar carga de combustible
  Future<String> insertFuelCharge(FuelCharge fuelCharge) async {
    final db = await _dbHelper.database;
    final id = _uuid.v4();
    final newCharge = fuelCharge.copyWith(id: id);

    final map = newCharge.toMap();
    map['synced'] = 0;

    await db.insert('fuel_charges', map);

    // Sincronizar con Supabase
    if (await _isOnline) {
      try {
        await SupabaseConfig.client.from('fuel_charges').insert(newCharge.toSupabase());
        await db.update('fuel_charges', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
      } catch (e) {
        debugPrint('Error syncing fuel charge: $e');
        _syncService?.addToSyncQueue(
          tableName: 'fuel_charges',
          recordId: id,
          operation: 'insert',
          data: newCharge.toSupabase(),
        );
      }
    } else {
      _syncService?.addToSyncQueue(
        tableName: 'fuel_charges',
        recordId: id,
        operation: 'insert',
        data: newCharge.toSupabase(),
      );
    }

    return id;
  }

  // Actualizar carga de combustible
  Future<int> updateFuelCharge(FuelCharge fuelCharge) async {
    if (fuelCharge.id == null) throw Exception('FuelCharge ID is required');

    final db = await _dbHelper.database;
    final updatedCharge = fuelCharge.copyWith(updatedAt: DateTime.now());
    final map = updatedCharge.toMap();
    map['synced'] = 0;

    final result = await db.update(
      'fuel_charges',
      map,
      where: 'id = ?',
      whereArgs: [fuelCharge.id],
    );

    // Sincronizar con Supabase
    if (await _isOnline) {
      try {
        await SupabaseConfig.client
            .from('fuel_charges')
            .update(updatedCharge.toSupabase())
            .eq('id', fuelCharge.id!);
        await db.update('fuel_charges', {'synced': 1}, where: 'id = ?', whereArgs: [fuelCharge.id]);
      } catch (e) {
        debugPrint('Error syncing fuel charge update: $e');
        _syncService?.addToSyncQueue(
          tableName: 'fuel_charges',
          recordId: fuelCharge.id!,
          operation: 'update',
          data: updatedCharge.toSupabase(),
        );
      }
    } else {
      _syncService?.addToSyncQueue(
        tableName: 'fuel_charges',
        recordId: fuelCharge.id!,
        operation: 'update',
        data: updatedCharge.toSupabase(),
      );
    }

    return result;
  }

  // Eliminar carga de combustible
  Future<int> deleteFuelCharge(String id) async {
    final db = await _dbHelper.database;
    final result = await db.delete('fuel_charges', where: 'id = ?', whereArgs: [id]);

    // Sincronizar con Supabase
    if (await _isOnline) {
      try {
        await SupabaseConfig.client.from('fuel_charges').delete().eq('id', id);
      } catch (e) {
        debugPrint('Error syncing fuel charge delete: $e');
        _syncService?.addToSyncQueue(
          tableName: 'fuel_charges',
          recordId: id,
          operation: 'delete',
          data: {},
        );
      }
    } else {
      _syncService?.addToSyncQueue(
        tableName: 'fuel_charges',
        recordId: id,
        operation: 'delete',
        data: {},
      );
    }

    return result;
  }

  // Obtener últimas N cargas de un vehículo
  Future<List<FuelCharge>> getRecentFuelCharges(String vehicleId, {int limit = 3}) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'fuel_charges',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'date DESC',
      limit: limit,
    );
    return maps.map((map) => FuelCharge.fromMap(map)).toList();
  }
}
