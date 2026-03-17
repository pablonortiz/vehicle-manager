import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../database/database.dart';
import '../services/db_change_service.dart';
import '../services/sync_service.dart';
import '../../core/config/supabase_config.dart';
import '../../domain/models/vehicle_photo.dart';

class PhotoRepository {
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

  // Obtener fotos de un vehículo
  Future<List<VehiclePhoto>> getPhotosByVehicle(String vehicleId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'vehicle_photos',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'is_primary DESC, created_at DESC',
    );
    return maps.map((map) => VehiclePhoto.fromMap(map)).toList();
  }

  // Obtener foto principal
  Future<VehiclePhoto?> getPrimaryPhoto(String vehicleId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'vehicle_photos',
      where: 'vehicle_id = ? AND is_primary = 1',
      whereArgs: [vehicleId],
    );
    if (maps.isEmpty) return null;
    return VehiclePhoto.fromMap(maps.first);
  }

  // Insertar foto
  Future<String> insertPhoto(VehiclePhoto photo) async {
    final db = await _dbHelper.database;
    final id = _uuid.v4();
    
    // Si es la primera foto o está marcada como principal, desmarcar las demás
    if (photo.isPrimary) {
      await db.update(
        'vehicle_photos',
        {'is_primary': 0},
        where: 'vehicle_id = ?',
        whereArgs: [photo.vehicleId],
      );
    }
    
    // Verificar si es la primera foto
    final existingPhotos = await getPhotosByVehicle(photo.vehicleId);
    final isPrimary = existingPhotos.isEmpty ? true : photo.isPrimary;
    
    final newPhoto = VehiclePhoto(
      id: id,
      vehicleId: photo.vehicleId,
      cloudinaryUrl: photo.cloudinaryUrl,
      cloudinaryPublicId: photo.cloudinaryPublicId,
      isPrimary: isPrimary,
      isPdf: photo.isPdf,
      fileName: photo.fileName,
    );
    
    final map = newPhoto.toMap();
    map['synced'] = 0;
    
    await db.insert('vehicle_photos', map);
    
    // Sincronizar con Supabase
    if (await _isOnline) {
      try {
        if (isPrimary) {
          await SupabaseConfig.client
              .from('vehicle_photos')
              .update({'is_primary': false})
              .eq('vehicle_id', photo.vehicleId);
        }
        await SupabaseConfig.client.from('vehicle_photos').insert(newPhoto.toSupabase());
        await db.update('vehicle_photos', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
      } catch (e) {
        _syncService?.addToSyncQueue(
          tableName: 'vehicle_photos',
          recordId: id,
          operation: 'insert',
          data: newPhoto.toSupabase(),
        );
      }
    } else {
      _syncService?.addToSyncQueue(
        tableName: 'vehicle_photos',
        recordId: id,
        operation: 'insert',
        data: newPhoto.toSupabase(),
      );
    }

    DbChangeService.instance.notifyChange('vehicle_photos');
    return id;
  }

  // Establecer foto como principal
  Future<void> setPrimaryPhoto(String photoId, String vehicleId) async {
    final db = await _dbHelper.database;
    
    // Desmarcar todas las fotos del vehículo
    await db.update(
      'vehicle_photos',
      {'is_primary': 0, 'synced': 0},
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
    );
    
    // Marcar la foto seleccionada como principal
    await db.update(
      'vehicle_photos',
      {'is_primary': 1, 'synced': 0},
      where: 'id = ?',
      whereArgs: [photoId],
    );
    
    // Sincronizar con Supabase
    if (await _isOnline) {
      try {
        await SupabaseConfig.client
            .from('vehicle_photos')
            .update({'is_primary': false})
            .eq('vehicle_id', vehicleId);
        await SupabaseConfig.client
            .from('vehicle_photos')
            .update({'is_primary': true})
            .eq('id', photoId);
        
        await db.update('vehicle_photos', {'synced': 1}, where: 'vehicle_id = ?', whereArgs: [vehicleId]);
      } catch (e) {
        // Se sincronizará después
      }
    }

    DbChangeService.instance.notifyChange('vehicle_photos');
  }

  // Eliminar foto
  Future<int> deletePhoto(String id) async {
    final db = await _dbHelper.database;
    
    // Obtener la foto antes de eliminar
    final maps = await db.query('vehicle_photos', where: 'id = ?', whereArgs: [id]);
    final wasPrimary = maps.isNotEmpty && (maps.first['is_primary'] as int) == 1;
    final vehicleId = maps.isNotEmpty ? maps.first['vehicle_id'] as String : null;
    
    final result = await db.delete('vehicle_photos', where: 'id = ?', whereArgs: [id]);
    
    // Si era la foto principal, establecer otra como principal
    if (wasPrimary && vehicleId != null) {
      final remainingPhotos = await getPhotosByVehicle(vehicleId);
      if (remainingPhotos.isNotEmpty) {
        await setPrimaryPhoto(remainingPhotos.first.id!, vehicleId);
      }
    }
    
    // Sincronizar con Supabase
    if (await _isOnline) {
      try {
        await SupabaseConfig.client.from('vehicle_photos').delete().eq('id', id);
      } catch (e) {
        _syncService?.addToSyncQueue(
          tableName: 'vehicle_photos',
          recordId: id,
          operation: 'delete',
          data: {},
        );
      }
    } else {
      _syncService?.addToSyncQueue(
        tableName: 'vehicle_photos',
        recordId: id,
        operation: 'delete',
        data: {},
      );
    }

    DbChangeService.instance.notifyChange('vehicle_photos');
    return result;
  }
}
