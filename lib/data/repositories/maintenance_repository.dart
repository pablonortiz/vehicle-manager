import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../database/database.dart';
import '../services/db_change_service.dart';
import '../services/sync_service.dart';
import '../../core/config/supabase_config.dart';
import '../../domain/models/maintenance.dart';

class MaintenanceRepository {
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

  // Obtener mantenimientos de un vehículo
  Future<List<Maintenance>> getMaintenancesByVehicle(String vehicleId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'maintenances',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'date DESC',
    );
    
    final maintenances = <Maintenance>[];
    for (final map in maps) {
      final invoices = await getInvoicesByMaintenance(map['id'] as String);
      maintenances.add(Maintenance.fromMap(map).copyWith(invoices: invoices));
    }
    
    return maintenances;
  }

  // Obtener un mantenimiento por ID
  Future<Maintenance?> getMaintenanceById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'maintenances',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    
    final invoices = await getInvoicesByMaintenance(id);
    return Maintenance.fromMap(maps.first).copyWith(invoices: invoices);
  }

  // Insertar mantenimiento
  Future<String> insertMaintenance(Maintenance maintenance) async {
    final db = await _dbHelper.database;
    final id = _uuid.v4();
    final newMaintenance = maintenance.copyWith(id: id);
    
    final map = newMaintenance.toMap();
    map['synced'] = 0;
    
    await db.insert('maintenances', map);
    
    // Sincronizar con Supabase
    if (await _isOnline) {
      try {
        await SupabaseConfig.client.from('maintenances').insert(newMaintenance.toSupabase());
        await db.update('maintenances', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
      } catch (e) {
        _syncService?.addToSyncQueue(
          tableName: 'maintenances',
          recordId: id,
          operation: 'insert',
          data: newMaintenance.toSupabase(),
        );
      }
    } else {
      _syncService?.addToSyncQueue(
        tableName: 'maintenances',
        recordId: id,
        operation: 'insert',
        data: newMaintenance.toSupabase(),
      );
    }

    DbChangeService.instance.notifyChange('maintenances');
    return id;
  }

  // Actualizar mantenimiento
  Future<int> updateMaintenance(Maintenance maintenance) async {
    if (maintenance.id == null) throw Exception('Maintenance ID is required');
    
    final db = await _dbHelper.database;
    final updatedMaintenance = maintenance.copyWith(updatedAt: DateTime.now());
    final map = updatedMaintenance.toMap();
    map['synced'] = 0;
    
    final result = await db.update(
      'maintenances',
      map,
      where: 'id = ?',
      whereArgs: [maintenance.id],
    );
    
    // Sincronizar con Supabase
    if (await _isOnline) {
      try {
        await SupabaseConfig.client
            .from('maintenances')
            .update(updatedMaintenance.toSupabase())
            .eq('id', maintenance.id!);
        await db.update('maintenances', {'synced': 1}, where: 'id = ?', whereArgs: [maintenance.id]);
      } catch (e) {
        _syncService?.addToSyncQueue(
          tableName: 'maintenances',
          recordId: maintenance.id!,
          operation: 'update',
          data: updatedMaintenance.toSupabase(),
        );
      }
    } else {
      _syncService?.addToSyncQueue(
        tableName: 'maintenances',
        recordId: maintenance.id!,
        operation: 'update',
        data: updatedMaintenance.toSupabase(),
      );
    }

    DbChangeService.instance.notifyChange('maintenances');
    return result;
  }

  // Eliminar mantenimiento
  Future<int> deleteMaintenance(String id) async {
    final db = await _dbHelper.database;
    
    // Eliminar facturas primero
    await db.delete('maintenance_invoices', where: 'maintenance_id = ?', whereArgs: [id]);
    
    final result = await db.delete('maintenances', where: 'id = ?', whereArgs: [id]);
    
    // Sincronizar con Supabase
    if (await _isOnline) {
      try {
        await SupabaseConfig.client.from('maintenances').delete().eq('id', id);
      } catch (e) {
        _syncService?.addToSyncQueue(
          tableName: 'maintenances',
          recordId: id,
          operation: 'delete',
          data: {},
        );
      }
    } else {
      _syncService?.addToSyncQueue(
        tableName: 'maintenances',
        recordId: id,
        operation: 'delete',
        data: {},
      );
    }

    DbChangeService.instance.notifyChange('maintenances');
    DbChangeService.instance.notifyChange('maintenance_invoices');
    return result;
  }

  // Facturas de mantenimiento
  Future<List<MaintenanceInvoice>> getInvoicesByMaintenance(String maintenanceId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'maintenance_invoices',
      where: 'maintenance_id = ?',
      whereArgs: [maintenanceId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => MaintenanceInvoice.fromMap(map)).toList();
  }

  Future<String> insertInvoice(MaintenanceInvoice invoice) async {
    final db = await _dbHelper.database;
    final id = _uuid.v4();
    final newInvoice = MaintenanceInvoice(
      id: id,
      maintenanceId: invoice.maintenanceId,
      cloudinaryUrl: invoice.cloudinaryUrl,
      cloudinaryPublicId: invoice.cloudinaryPublicId,
      fileType: invoice.fileType,
      fileName: invoice.fileName,
    );
    
    final map = newInvoice.toMap();
    map['synced'] = 0;
    
    await db.insert('maintenance_invoices', map);
    
    // Sincronizar con Supabase
    if (await _isOnline) {
      try {
        await SupabaseConfig.client.from('maintenance_invoices').insert(newInvoice.toSupabase());
        await db.update('maintenance_invoices', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
      } catch (e) {
        _syncService?.addToSyncQueue(
          tableName: 'maintenance_invoices',
          recordId: id,
          operation: 'insert',
          data: newInvoice.toSupabase(),
        );
      }
    } else {
      _syncService?.addToSyncQueue(
        tableName: 'maintenance_invoices',
        recordId: id,
        operation: 'insert',
        data: newInvoice.toSupabase(),
      );
    }

    DbChangeService.instance.notifyChange('maintenance_invoices');
    return id;
  }

  Future<int> deleteInvoice(String id) async {
    final db = await _dbHelper.database;
    final result = await db.delete('maintenance_invoices', where: 'id = ?', whereArgs: [id]);
    
    // Sincronizar con Supabase
    if (await _isOnline) {
      try {
        await SupabaseConfig.client.from('maintenance_invoices').delete().eq('id', id);
      } catch (e) {
        _syncService?.addToSyncQueue(
          tableName: 'maintenance_invoices',
          recordId: id,
          operation: 'delete',
          data: {},
        );
      }
    } else {
      _syncService?.addToSyncQueue(
        tableName: 'maintenance_invoices',
        recordId: id,
        operation: 'delete',
        data: {},
      );
    }

    DbChangeService.instance.notifyChange('maintenance_invoices');
    return result;
  }
}
