import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/db_change_service.dart';

// Generic stream provider for all changes
final dbChangeStreamProvider = StreamProvider<String>((ref) {
  return DbChangeService.instance.changes;
});

// Table-specific change providers that act as "refresh triggers"
// Providers watching these will refetch when the relevant table changes

final vehiclesChangeProvider = StreamProvider<void>((ref) {
  return DbChangeService.instance.changes
      .where((table) => table == 'vehicles')
      .map((_) {});
});

final photosChangeProvider = StreamProvider<void>((ref) {
  return DbChangeService.instance.changes
      .where((table) => table == 'vehicle_photos' || table == 'document_photos')
      .map((_) {});
});

final maintenancesChangeProvider = StreamProvider<void>((ref) {
  return DbChangeService.instance.changes
      .where((table) => table == 'maintenances' || table == 'maintenance_invoices')
      .map((_) {});
});

final notesChangeProvider = StreamProvider<void>((ref) {
  return DbChangeService.instance.changes
      .where((table) => table == 'vehicle_notes' || table == 'note_photos')
      .map((_) {});
});

final fuelChargesChangeProvider = StreamProvider<void>((ref) {
  return DbChangeService.instance.changes
      .where((table) => table == 'fuel_charges')
      .map((_) {});
});

final locationsChangeProvider = StreamProvider<void>((ref) {
  return DbChangeService.instance.changes
      .where((table) => table == 'cities' || table == 'lugares')
      .map((_) {});
});
