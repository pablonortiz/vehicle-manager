import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/fuel_charge_repository.dart';
import '../../data/services/sync_service.dart';
import '../../domain/models/fuel_charge.dart';

// Repository provider
final fuelChargeRepositoryProvider = Provider((ref) {
  final repo = FuelChargeRepository();
  final syncService = ref.read(syncServiceProvider.notifier);
  repo.setSyncService(syncService);
  return repo;
});

// Cargas de combustible de un vehículo
final fuelChargesByVehicleProvider = FutureProvider.family<List<FuelCharge>, String>((ref, vehicleId) async {
  final repository = ref.watch(fuelChargeRepositoryProvider);
  return repository.getFuelChargesByVehicle(vehicleId);
});

// Parámetros para consulta mensual
class MonthlyFuelParams {
  final String vehicleId;
  final int year;
  final int month;

  MonthlyFuelParams({
    required this.vehicleId,
    required this.year,
    required this.month,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthlyFuelParams &&
          vehicleId == other.vehicleId &&
          year == other.year &&
          month == other.month;

  @override
  int get hashCode => Object.hash(vehicleId, year, month);
}

// Cargas de combustible por mes
final fuelChargesByMonthProvider = FutureProvider.family<List<FuelCharge>, MonthlyFuelParams>((ref, params) async {
  final repository = ref.watch(fuelChargeRepositoryProvider);
  return repository.getFuelChargesByMonth(params.vehicleId, params.year, params.month);
});

// Resumen mensual
final fuelChargeSummaryProvider = FutureProvider.family<FuelChargeSummary, MonthlyFuelParams>((ref, params) async {
  final repository = ref.watch(fuelChargeRepositoryProvider);
  return repository.getMonthlySummary(params.vehicleId, params.year, params.month);
});

// Parámetros para consulta por rango de fechas
class DateRangeFuelParams {
  final String vehicleId;
  final DateTime startDate;
  final DateTime endDate;

  DateRangeFuelParams({
    required this.vehicleId,
    required this.startDate,
    required this.endDate,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DateRangeFuelParams &&
          vehicleId == other.vehicleId &&
          startDate == other.startDate &&
          endDate == other.endDate;

  @override
  int get hashCode => Object.hash(vehicleId, startDate, endDate);
}

// Cargas de combustible por rango de fechas
final fuelChargesByDateRangeProvider = FutureProvider.family<List<FuelCharge>, DateRangeFuelParams>((ref, params) async {
  final repository = ref.watch(fuelChargeRepositoryProvider);
  return repository.getFuelChargesByDateRange(params.vehicleId, params.startDate, params.endDate);
});

// Parámetros para gráficos mensuales
class ChartDataParams {
  final String vehicleId;
  final int months;

  ChartDataParams({
    required this.vehicleId,
    this.months = 6,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartDataParams &&
          vehicleId == other.vehicleId &&
          months == other.months;

  @override
  int get hashCode => Object.hash(vehicleId, months);
}

// Datos mensuales para gráficos
final fuelChartDataProvider = FutureProvider.family<List<MonthlyFuelData>, ChartDataParams>((ref, params) async {
  final repository = ref.watch(fuelChargeRepositoryProvider);
  return repository.getMonthlyChartData(params.vehicleId, months: params.months);
});

// Últimas cargas de combustible de un vehículo
final recentFuelChargesProvider = FutureProvider.family<List<FuelCharge>, String>((ref, vehicleId) async {
  final repository = ref.watch(fuelChargeRepositoryProvider);
  return repository.getRecentFuelCharges(vehicleId, limit: 3);
});

// Estado del mes seleccionado (para navegación)
class SelectedMonthState {
  final int year;
  final int month;

  SelectedMonthState({required this.year, required this.month});

  SelectedMonthState copyWith({int? year, int? month}) {
    return SelectedMonthState(
      year: year ?? this.year,
      month: month ?? this.month,
    );
  }

  factory SelectedMonthState.now() {
    final now = DateTime.now();
    return SelectedMonthState(year: now.year, month: now.month);
  }

  SelectedMonthState previousMonth() {
    if (month == 1) {
      return SelectedMonthState(year: year - 1, month: 12);
    }
    return SelectedMonthState(year: year, month: month - 1);
  }

  SelectedMonthState nextMonth() {
    if (month == 12) {
      return SelectedMonthState(year: year + 1, month: 1);
    }
    return SelectedMonthState(year: year, month: month + 1);
  }

  String get monthName {
    const months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return months[month - 1];
  }

  String get displayText => '$monthName $year';
}

// Provider para el mes seleccionado (por vehículo)
final selectedMonthProvider = StateProvider.family<SelectedMonthState, String>((ref, vehicleId) {
  return SelectedMonthState.now();
});
