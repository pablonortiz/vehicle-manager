import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/supabase_config.dart';
import '../database/database.dart';
import '../../domain/models/vehicle.dart';
import '../../domain/models/vehicle_history.dart';
import '../../domain/models/maintenance.dart';
import '../../domain/models/vehicle_note.dart';
import '../../domain/models/vehicle_photo.dart';
import '../../domain/models/document_photo.dart';
import '../../domain/models/city.dart';
import '../../domain/models/lugar.dart';
import '../../domain/models/fuel_charge.dart';

enum SyncStatus {
  idle,
  syncing,
  success,
  error,
  offline,
}

class SyncState {
  final SyncStatus status;
  final String? message;
  final DateTime? lastSync;

  SyncState({
    this.status = SyncStatus.idle,
    this.message,
    this.lastSync,
  });

  SyncState copyWith({
    SyncStatus? status,
    String? message,
    DateTime? lastSync,
  }) {
    return SyncState(
      status: status ?? this.status,
      message: message ?? this.message,
      lastSync: lastSync ?? this.lastSync,
    );
  }
}

class SyncService extends StateNotifier<SyncState> {
  SyncService() : super(SyncState());

  final _db = DatabaseHelper.instance;
  
  // Verificar conectividad
  Future<bool> get isOnline async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  // Sincronización completa desde Supabase
  Future<void> fullSync() async {
    debugPrint('🔄 [SYNC] Iniciando fullSync...');
    
    if (!await isOnline) {
      debugPrint('❌ [SYNC] Sin conexión a internet');
      state = state.copyWith(status: SyncStatus.offline, message: 'Sin conexión');
      return;
    }

    if (!SupabaseConfig.isConfigured) {
      debugPrint('❌ [SYNC] Supabase no configurado');
      state = state.copyWith(status: SyncStatus.error, message: 'Supabase no configurado');
      return;
    }

    state = state.copyWith(status: SyncStatus.syncing, message: 'Sincronizando...');

    try {
      final client = SupabaseConfig.client;
      final db = await _db.database;

      // PRIMERO: Subir datos locales no sincronizados a Supabase
      debugPrint('📤 [SYNC] Subiendo datos locales no sincronizados...');
      await _uploadUnsyncedData();
      
      // Procesar cola de sincronización pendiente
      debugPrint('📤 [SYNC] Procesando cola de sincronización...');
      await _processSyncQueue();

      // AHORA: Descargar datos de Supabase (sin borrar antes)
      debugPrint('📥 [SYNC] Descargando vehículos de Supabase...');
      final vehiclesData = await client.from('vehicles').select();
      debugPrint('📥 [SYNC] Recibidos ${vehiclesData.length} vehículos de Supabase');
      
      // Solo limpiar y reemplazar si la descarga fue exitosa
      if (vehiclesData is List) {
        // Limpiar tablas locales
        await _db.clearAllTables();
        debugPrint('🗑️ [SYNC] Tablas locales limpiadas');

        // Descargar ciudades primero (antes de vehículos por la FK)
        try {
          final citiesData = await client.from('cities').select();
          for (final data in citiesData) {
            final city = City.fromSupabase(data);
            await db.insert('cities', {...city.toMap(), 'synced': 1});
          }
          debugPrint('✅ [SYNC] ${citiesData.length} ciudades guardadas localmente');
        } catch (e) {
          debugPrint('⚠️ [SYNC] Tabla cities no existe aún: $e');
        }

        // Descargar lugares
        try {
          final lugaresData = await client.from('lugares').select();
          for (final data in lugaresData) {
            final lugar = Lugar.fromSupabase(data);
            await db.insert('lugares', {...lugar.toMap(), 'synced': 1});
          }
          debugPrint('✅ [SYNC] ${lugaresData.length} lugares guardados localmente');
        } catch (e) {
          debugPrint('⚠️ [SYNC] Tabla lugares no existe aún: $e');
        }

        // Descargar vehículos
        for (final data in vehiclesData) {
          final vehicle = Vehicle.fromSupabase(data);
          await db.insert('vehicles', {...vehicle.toMap(), 'synced': 1});
        }
        debugPrint('✅ [SYNC] ${vehiclesData.length} vehículos guardados localmente');

        // Descargar historial
        final historyData = await client.from('vehicle_history').select();
        for (final data in historyData) {
          final history = VehicleHistory.fromSupabase(data);
          await db.insert('vehicle_history', {...history.toMap(), 'synced': 1});
        }
        debugPrint('✅ [SYNC] ${historyData.length} registros de historial');

        // Descargar mantenimientos
        final maintenancesData = await client.from('maintenances').select();
        for (final data in maintenancesData) {
          final maintenance = Maintenance.fromSupabase(data);
          await db.insert('maintenances', {...maintenance.toMap(), 'synced': 1});
        }

        // Descargar facturas de mantenimiento
        final invoicesData = await client.from('maintenance_invoices').select();
        for (final data in invoicesData) {
          final invoice = MaintenanceInvoice.fromSupabase(data);
          await db.insert('maintenance_invoices', {...invoice.toMap(), 'synced': 1});
        }

        // Descargar notas
        final notesData = await client.from('vehicle_notes').select();
        for (final data in notesData) {
          final note = VehicleNote.fromSupabase(data);
          await db.insert('vehicle_notes', {...note.toMap(), 'synced': 1});
        }

        // Descargar fotos de notas
        final notePhotosData = await client.from('note_photos').select();
        for (final data in notePhotosData) {
          final photo = NotePhoto.fromSupabase(data);
          await db.insert('note_photos', {...photo.toMap(), 'synced': 1});
        }

        // Descargar fotos de vehículos
        final vehiclePhotosData = await client.from('vehicle_photos').select();
        for (final data in vehiclePhotosData) {
          final photo = VehiclePhoto.fromSupabase(data);
          await db.insert('vehicle_photos', {...photo.toMap(), 'synced': 1});
        }

        // Descargar fotos de documentos
        try {
          final documentPhotosData = await client.from('document_photos').select();
          for (final data in documentPhotosData) {
            final photo = DocumentPhoto.fromSupabase(data);
            await db.insert('document_photos', {...photo.toMap(), 'synced': 1});
          }
          debugPrint('✅ [SYNC] ${documentPhotosData.length} fotos de documentos');
        } catch (e) {
          debugPrint('⚠️ [SYNC] Tabla document_photos no existe aún: $e');
        }

        // Descargar cargas de combustible
        try {
          final fuelChargesData = await client.from('fuel_charges').select();
          for (final data in fuelChargesData) {
            final fuelCharge = FuelCharge.fromSupabase(data);
            await db.insert('fuel_charges', {...fuelCharge.toMap(), 'synced': 1});
          }
          debugPrint('✅ [SYNC] ${fuelChargesData.length} cargas de combustible');
        } catch (e) {
          debugPrint('⚠️ [SYNC] Tabla fuel_charges no existe aún: $e');
        }
      }

      debugPrint('✅ [SYNC] Sincronización completa exitosa');
      state = state.copyWith(
        status: SyncStatus.success,
        message: 'Sincronización completa',
        lastSync: DateTime.now(),
      );
    } catch (e, stack) {
      debugPrint('❌ [SYNC] Error en fullSync: $e');
      debugPrint('❌ [SYNC] Stack: $stack');
      state = state.copyWith(
        status: SyncStatus.error,
        message: 'Error: ${e.toString()}',
      );
    }
  }
  
  // Subir datos locales no sincronizados
  Future<void> _uploadUnsyncedData() async {
    final db = await _db.database;
    final client = SupabaseConfig.client;

    // Subir ciudades no sincronizadas primero (antes de vehículos por la FK)
    try {
      final unsyncedCities = await db.query('cities', where: 'synced = 0');
      debugPrint('📤 [SYNC] ${unsyncedCities.length} ciudades pendientes de sincronizar');

      for (final map in unsyncedCities) {
        try {
          final city = City.fromMap(map);
          final existing = await client
              .from('cities')
              .select('id')
              .eq('id', city.id!)
              .maybeSingle();

          if (existing == null) {
            await client.from('cities').insert(city.toSupabase());
            debugPrint('✅ [SYNC] Ciudad ${city.name} insertada en Supabase');
          } else {
            await client.from('cities').update(city.toSupabase()).eq('id', city.id!);
            debugPrint('✅ [SYNC] Ciudad ${city.name} actualizada en Supabase');
          }

          await db.update('cities', {'synced': 1}, where: 'id = ?', whereArgs: [city.id]);
        } catch (e) {
          debugPrint('❌ [SYNC] Error subiendo ciudad: $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️ [SYNC] Tabla cities no existe localmente: $e');
    }

    // Subir lugares no sincronizados
    try {
      final unsyncedLugares = await db.query('lugares', where: 'synced = 0');
      debugPrint('📤 [SYNC] ${unsyncedLugares.length} lugares pendientes de sincronizar');

      for (final map in unsyncedLugares) {
        try {
          final lugar = Lugar.fromMap(map);
          final existing = await client
              .from('lugares')
              .select('id')
              .eq('id', lugar.id!)
              .maybeSingle();

          if (existing == null) {
            await client.from('lugares').insert(lugar.toSupabase());
            debugPrint('✅ [SYNC] Lugar ${lugar.name} insertado en Supabase');
          } else {
            await client.from('lugares').update(lugar.toSupabase()).eq('id', lugar.id!);
            debugPrint('✅ [SYNC] Lugar ${lugar.name} actualizado en Supabase');
          }

          await db.update('lugares', {'synced': 1}, where: 'id = ?', whereArgs: [lugar.id]);
        } catch (e) {
          debugPrint('❌ [SYNC] Error subiendo lugar: $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️ [SYNC] Tabla lugares no existe localmente: $e');
    }

    // Subir vehículos no sincronizados
    final unsyncedVehicles = await db.query('vehicles', where: 'synced = 0');
    debugPrint('📤 [SYNC] ${unsyncedVehicles.length} vehículos pendientes de sincronizar');
    
    for (final map in unsyncedVehicles) {
      try {
        final vehicle = Vehicle.fromMap(map);
        debugPrint('📤 [SYNC] Subiendo vehículo: ${vehicle.plate}');
        
        // Verificar si ya existe en Supabase
        final existing = await client
            .from('vehicles')
            .select('id')
            .eq('id', vehicle.id!)
            .maybeSingle();
        
        if (existing == null) {
          // Insertar nuevo
          await client.from('vehicles').insert(vehicle.toSupabase());
          debugPrint('✅ [SYNC] Vehículo ${vehicle.plate} insertado en Supabase');
        } else {
          // Actualizar existente
          await client.from('vehicles').update(vehicle.toSupabase()).eq('id', vehicle.id!);
          debugPrint('✅ [SYNC] Vehículo ${vehicle.plate} actualizado en Supabase');
        }
        
        // Marcar como sincronizado localmente
        await db.update('vehicles', {'synced': 1}, where: 'id = ?', whereArgs: [vehicle.id]);
      } catch (e) {
        debugPrint('❌ [SYNC] Error subiendo vehículo: $e');
      }
    }
    
    // Subir historial no sincronizado
    final unsyncedHistory = await db.query('vehicle_history', where: 'synced = 0');
    for (final map in unsyncedHistory) {
      try {
        final history = VehicleHistory.fromMap(map);
        final existing = await client
            .from('vehicle_history')
            .select('id')
            .eq('id', history.id!)
            .maybeSingle();

        if (existing == null) {
          await client.from('vehicle_history').insert(history.toSupabase());
        }
        await db.update('vehicle_history', {'synced': 1}, where: 'id = ?', whereArgs: [history.id]);
      } catch (e) {
        debugPrint('❌ [SYNC] Error subiendo historial: $e');
      }
    }

    // Subir cargas de combustible no sincronizadas
    try {
      final unsyncedFuelCharges = await db.query('fuel_charges', where: 'synced = 0');
      debugPrint('📤 [SYNC] ${unsyncedFuelCharges.length} cargas de combustible pendientes de sincronizar');

      for (final map in unsyncedFuelCharges) {
        try {
          final fuelCharge = FuelCharge.fromMap(map);
          final existing = await client
              .from('fuel_charges')
              .select('id')
              .eq('id', fuelCharge.id!)
              .maybeSingle();

          if (existing == null) {
            await client.from('fuel_charges').insert(fuelCharge.toSupabase());
            debugPrint('✅ [SYNC] Carga de combustible insertada en Supabase');
          } else {
            await client.from('fuel_charges').update(fuelCharge.toSupabase()).eq('id', fuelCharge.id!);
            debugPrint('✅ [SYNC] Carga de combustible actualizada en Supabase');
          }

          await db.update('fuel_charges', {'synced': 1}, where: 'id = ?', whereArgs: [fuelCharge.id]);
        } catch (e) {
          debugPrint('❌ [SYNC] Error subiendo carga de combustible: $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️ [SYNC] Tabla fuel_charges no existe localmente: $e');
    }
  }

  // Procesar cola de sincronización pendiente
  Future<void> _processSyncQueue() async {
    final db = await _db.database;
    final queue = await db.query('sync_queue', orderBy: 'created_at ASC');

    for (final item in queue) {
      try {
        final tableName = item['table_name'] as String;
        final operation = item['operation'] as String;
        final data = jsonDecode(item['data'] as String) as Map<String, dynamic>;

        final client = SupabaseConfig.client;

        switch (operation) {
          case 'insert':
            await client.from(tableName).insert(data);
            break;
          case 'update':
            final id = item['record_id'] as String;
            await client.from(tableName).update(data).eq('id', id);
            break;
          case 'delete':
            final id = item['record_id'] as String;
            await client.from(tableName).delete().eq('id', id);
            break;
        }

        // Eliminar de la cola si fue exitoso
        await db.delete('sync_queue', where: 'id = ?', whereArgs: [item['id']]);
      } catch (e) {
        // Incrementar retry count
        final retryCount = (item['retry_count'] as int) + 1;
        if (retryCount >= 5) {
          // Eliminar después de 5 intentos
          await db.delete('sync_queue', where: 'id = ?', whereArgs: [item['id']]);
        } else {
          await db.update(
            'sync_queue',
            {'retry_count': retryCount},
            where: 'id = ?',
            whereArgs: [item['id']],
          );
        }
      }
    }
  }

  // Agregar operación a la cola de sincronización
  Future<void> addToSyncQueue({
    required String tableName,
    required String recordId,
    required String operation,
    required Map<String, dynamic> data,
  }) async {
    final db = await _db.database;
    await db.insert('sync_queue', {
      'table_name': tableName,
      'record_id': recordId,
      'operation': operation,
      'data': jsonEncode(data),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });

    // Intentar sincronizar si está online
    if (await isOnline && SupabaseConfig.isConfigured) {
      await _processSyncQueue();
    }
  }
}

// Provider para el servicio de sincronización
final syncServiceProvider = StateNotifierProvider<SyncService, SyncState>((ref) {
  return SyncService();
});
