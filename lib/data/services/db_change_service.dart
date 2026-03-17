import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';

class DbChangeService {
  static final DbChangeService instance = DbChangeService._();
  DbChangeService._();

  final _controller = StreamController<String>.broadcast();
  Stream<String> get changes => _controller.stream;

  RealtimeChannel? _channel;
  Timer? _debounceTimer;

  /// Callback para triggear un sync cuando llegan cambios remotos
  void Function()? onRemoteChange;

  void notifyChange(String table) {
    _controller.add(table);
  }

  /// Suscribirse a cambios en tiempo real de Supabase
  void startRealtimeSubscription() {
    if (!SupabaseConfig.isConfigured) return;

    try {
      final client = SupabaseConfig.client;

      _channel = client.channel('db-changes');

      // Suscribirse a todas las tablas relevantes
      const tables = [
        'vehicles',
        'vehicle_photos',
        'document_photos',
        'maintenances',
        'maintenance_invoices',
        'vehicle_notes',
        'note_photos',
        'fuel_charges',
        'cities',
        'lugares',
      ];

      for (final table in tables) {
        _channel!.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          callback: (payload) {
            debugPrint('🔄 [REALTIME] Cambio en $table: ${payload.eventType}');
            // Solo triggear sync (con debounce) para bajar datos frescos.
            // El sync ya llama notifyChange al terminar, así las pantallas
            // se actualizan DESPUÉS de tener los datos nuevos en SQLite.
            _debounceTimer?.cancel();
            _debounceTimer = Timer(const Duration(milliseconds: 500), () {
              onRemoteChange?.call();
            });
          },
        );
      }

      _channel!.subscribe((status, error) {
        debugPrint('🔄 [REALTIME] Status: $status${error != null ? ', Error: $error' : ''}');
      });
    } catch (e) {
      debugPrint('🔄 [REALTIME] Error al suscribirse: $e');
    }
  }

  /// Detener suscripción
  void stopRealtimeSubscription() {
    _channel?.unsubscribe();
    _channel = null;
  }

  void dispose() {
    stopRealtimeSubscription();
    _debounceTimer?.cancel();
    _controller.close();
  }
}
