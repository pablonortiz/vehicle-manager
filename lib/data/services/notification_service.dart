import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../../core/utils/formatters.dart';
import '../../core/utils/plate_format.dart';
import '../../domain/models/vehicle.dart';

/// Días antes del vencimiento en los que se avisa.
const List<int> kReminderOffsets = [30, 7, 1];

/// Hora del día (24h) en que se dispara el recordatorio.
const int kReminderHour = 9;

/// Para un vencimiento, calcula los recordatorios a programar (a [kReminderHour]),
/// descartando los que ya pasaron respecto de [now]. Devuelve el índice del
/// offset (para un id estable) y la fecha. Pura y testeable.
List<({int index, DateTime date})> reminderSchedule(
  DateTime expiry,
  DateTime now, {
  List<int> offsets = kReminderOffsets,
}) {
  final result = <({int index, DateTime date})>[];
  for (var i = 0; i < offsets.length; i++) {
    final date = DateTime(
      expiry.year,
      expiry.month,
      expiry.day - offsets[i],
      kReminderHour,
    );
    if (date.isAfter(now)) result.add((index: i, date: date));
  }
  return result;
}

/// Recordatorios locales de vencimiento (VTV / seguro). No requiere backend.
/// Las operaciones son best-effort: si el plugin falla (permiso denegado,
/// plataforma sin soporte, entorno de test) se loguea y se sigue sin romper.
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'vehicle_reminders';

  Future<void> init() async {
    if (_initialized) return;
    try {
      tzdata.initializeTimeZones();
      // App de uso argentino: programamos en hora local de Argentina.
      tz.setLocalLocation(tz.getLocation('America/Argentina/Buenos_Aires'));

      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(settings);
      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService.init falló: $e');
    }
  }

  /// Pide permiso de notificaciones (Android 13+ / iOS lo requieren en runtime).
  Future<void> requestPermission() async {
    await init();
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('NotificationService.requestPermission falló: $e');
    }
  }

  /// Reprograma los recordatorios de un vehículo (cancela los previos primero).
  /// Si el vehículo tiene vencimientos, pide permiso acá: es el momento con
  /// contexto (el usuario acaba de cargar una fecha a recordar).
  Future<void> scheduleForVehicle(Vehicle vehicle) async {
    await init();
    if (vehicle.vtvExpiry != null || vehicle.insuranceExpiry != null) {
      await requestPermission();
    }
    await cancelForVehicle(vehicle.id ?? '');
    await _scheduleAll(vehicle);
  }

  Future<void> cancelForVehicle(String vehicleId) async {
    if (vehicleId.isEmpty) return;
    try {
      for (final type in const ['vtv', 'seguro']) {
        for (var i = 0; i < kReminderOffsets.length; i++) {
          await _plugin.cancel(_notifId(vehicleId, type, i));
        }
      }
    } catch (e) {
      debugPrint('NotificationService.cancelForVehicle falló: $e');
    }
  }

  /// Reprograma TODOS los recordatorios desde cero. Se llama al abrir la app:
  /// un reinicio/reinstalación del teléfono borra las notificaciones agendadas.
  Future<void> syncAll(List<Vehicle> vehicles) async {
    await init();
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('NotificationService.syncAll cancelAll falló: $e');
      return;
    }
    for (final vehicle in vehicles) {
      await _scheduleAll(vehicle);
    }
  }

  Future<void> _scheduleAll(Vehicle vehicle) async {
    if (vehicle.id == null) return;
    final now = DateTime.now();
    if (vehicle.vtvExpiry != null) {
      await _scheduleSet(vehicle, 'vtv', 'VTV', vehicle.vtvExpiry!, now);
    }
    if (vehicle.insuranceExpiry != null) {
      await _scheduleSet(
          vehicle, 'seguro', 'Seguro', vehicle.insuranceExpiry!, now);
    }
  }

  Future<void> _scheduleSet(
    Vehicle vehicle,
    String type,
    String label,
    DateTime expiry,
    DateTime now,
  ) async {
    try {
      for (final reminder in reminderSchedule(expiry, now)) {
        await _plugin.zonedSchedule(
          _notifId(vehicle.id!, type, reminder.index),
          '$label por vencer',
          '${vehicle.displayName} (${formatPlate(vehicle.plate)}): vence el '
              '${AppFormats.date(expiry)}',
          tz.TZDateTime.from(reminder.date, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              'Recordatorios de vencimiento',
              channelDescription: 'Avisos de VTV y seguro por vencer',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          // Inexacto: no necesitamos precisión al segundo y así evitamos el
          // permiso especial de alarmas exactas en Android 12+.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (e) {
      debugPrint('NotificationService._scheduleSet falló ($type): $e');
    }
  }

  // Id estable por (vehículo, tipo, índice de offset): no depende de la fecha,
  // así reprogramar tras editar el vencimiento cancela el id correcto.
  int _notifId(String vehicleId, String type, int offsetIndex) {
    return (Object.hash(vehicleId, type) & 0x0FFFFFFF) * kReminderOffsets.length +
        offsetIndex;
  }
}
