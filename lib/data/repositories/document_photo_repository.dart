import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../services/db_change_service.dart';
import '../services/sync_service.dart';
import '../../core/config/supabase_config.dart';
import '../../domain/models/document_photo.dart';
import '../../presentation/providers/db_change_provider.dart';

final documentPhotoRepositoryProvider = Provider<DocumentPhotoRepository>((ref) {
  final repo = DocumentPhotoRepository();
  return repo;
});

final documentPhotosByVehicleProvider = FutureProvider.family<List<DocumentPhoto>, String>((ref, vehicleId) async {
  ref.watch(photosChangeProvider);
  final repo = ref.watch(documentPhotoRepositoryProvider);
  return repo.getPhotosByVehicle(vehicleId);
});

final documentPhotosByTypeProvider = FutureProvider.family<List<DocumentPhoto>, ({String vehicleId, DocumentType type})>((ref, params) async {
  ref.watch(photosChangeProvider);
  final repo = ref.watch(documentPhotoRepositoryProvider);
  return repo.getPhotosByType(params.vehicleId, params.type);
});

class DocumentPhotoRepository {
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

  // Obtener todas las fotos de documentos de un vehículo
  Future<List<DocumentPhoto>> getPhotosByVehicle(String vehicleId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'document_photos',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'document_type ASC, created_at DESC',
    );
    return maps.map((map) => DocumentPhoto.fromMap(map)).toList();
  }

  // Obtener fotos de un tipo específico de documento
  Future<List<DocumentPhoto>> getPhotosByType(String vehicleId, DocumentType type) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'document_photos',
      where: 'vehicle_id = ? AND document_type = ?',
      whereArgs: [vehicleId, type.value],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => DocumentPhoto.fromMap(map)).toList();
  }

  // Insertar foto de documento
  Future<String> insertPhoto(DocumentPhoto photo) async {
    final db = await _dbHelper.database;
    final id = _uuid.v4();
    
    final newPhoto = DocumentPhoto(
      id: id,
      vehicleId: photo.vehicleId,
      documentType: photo.documentType,
      cloudinaryUrl: photo.cloudinaryUrl,
      cloudinaryPublicId: photo.cloudinaryPublicId,
      isPdf: photo.isPdf,
      fileName: photo.fileName,
    );
    
    final map = newPhoto.toMap();
    map['synced'] = 0;
    
    await db.insert('document_photos', map);
    
    // Sincronizar con Supabase
    if (await _isOnline) {
      try {
        await SupabaseConfig.client.from('document_photos').insert(newPhoto.toSupabase());
        await db.update('document_photos', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
      } catch (e) {
        _syncService?.addToSyncQueue(
          tableName: 'document_photos',
          recordId: id,
          operation: 'insert',
          data: newPhoto.toSupabase(),
        );
      }
    } else {
      _syncService?.addToSyncQueue(
        tableName: 'document_photos',
        recordId: id,
        operation: 'insert',
        data: newPhoto.toSupabase(),
      );
    }

    DbChangeService.instance.notifyChange('document_photos');
    return id;
  }

  // Eliminar foto de documento
  Future<int> deletePhoto(String id) async {
    final db = await _dbHelper.database;
    
    final result = await db.delete('document_photos', where: 'id = ?', whereArgs: [id]);
    
    // Sincronizar con Supabase
    if (await _isOnline) {
      try {
        await SupabaseConfig.client.from('document_photos').delete().eq('id', id);
      } catch (e) {
        _syncService?.addToSyncQueue(
          tableName: 'document_photos',
          recordId: id,
          operation: 'delete',
          data: {},
        );
      }
    } else {
      _syncService?.addToSyncQueue(
        tableName: 'document_photos',
        recordId: id,
        operation: 'delete',
        data: {},
      );
    }

    DbChangeService.instance.notifyChange('document_photos');
    return result;
  }
}
