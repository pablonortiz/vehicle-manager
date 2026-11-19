import 'models/vehicle.dart';
import 'models/fuel_charge.dart';
import 'models/maintenance.dart';

/// Gasto consolidado (combustible + mantenimiento) de un vehículo.
class VehicleExpense {
  final String vehicleId;
  final String label;
  final double fuelTotal;
  final double maintenanceTotal;

  /// El vehículo, para mostrarlo con la misma fila que en el resto de la app.
  final Vehicle? vehicle;

  const VehicleExpense({
    required this.vehicleId,
    required this.label,
    required this.fuelTotal,
    required this.maintenanceTotal,
    this.vehicle,
  });

  double get total => fuelTotal + maintenanceTotal;
}

/// Gasto consolidado de un mes.
class MonthlyExpense {
  final int year;
  final int month;
  final double fuelTotal;
  final double maintenanceTotal;

  const MonthlyExpense({
    required this.year,
    required this.month,
    required this.fuelTotal,
    required this.maintenanceTotal,
  });

  double get total => fuelTotal + maintenanceTotal;
}

/// Dashboard de gastos: por vehículo (ranking) y por mes (tendencia).
class ExpenseDashboard {
  final List<VehicleExpense> byVehicle;
  final List<MonthlyExpense> byMonth;

  /// Mantenimientos del rango sin costo cargado: gasto real que el dashboard
  /// no puede sumar. Sirve para avisar que los totales están incompletos.
  final int uncostedMaintenances;

  /// Vehículos que no gastaron nada en el período (no aparecen en el ranking).
  final int vehiclesWithoutExpenses;

  const ExpenseDashboard({
    required this.byVehicle,
    required this.byMonth,
    this.uncostedMaintenances = 0,
    this.vehiclesWithoutExpenses = 0,
  });

  double get fuelTotal =>
      byMonth.fold(0.0, (sum, m) => sum + m.fuelTotal);
  double get maintenanceTotal =>
      byMonth.fold(0.0, (sum, m) => sum + m.maintenanceTotal);
  double get grandTotal => fuelTotal + maintenanceTotal;
}

/// Construye el dashboard de gastos de los últimos [months] meses (incluido el
/// actual). Considera combustible (price de cada carga) y mantenimiento
/// (cost ?? 0). Solo cuenta registros desde el inicio del primer mes del rango.
/// Pura y testeable.
ExpenseDashboard buildExpenseDashboard({
  required List<Vehicle> vehicles,
  required List<FuelCharge> fuelCharges,
  required List<Maintenance> maintenances,
  required DateTime now,
  int months = 6,
}) {
  // Lista de (año, mes) del rango, del más viejo al actual.
  final monthsRange = List.generate(months, (i) {
    final m = DateTime(now.year, now.month - (months - 1 - i));
    return (year: m.year, month: m.month);
  });
  final cutoff = DateTime(monthsRange.first.year, monthsRange.first.month);

  bool inRange(DateTime d) => !d.isBefore(cutoff) && !d.isAfter(now);
  String monthKey(int year, int month) => '$year-$month';

  // Acumuladores.
  final fuelByVehicle = <String, double>{};
  final maintByVehicle = <String, double>{};
  final fuelByMonth = <String, double>{};
  final maintByMonth = <String, double>{};

  for (final charge in fuelCharges) {
    if (!inRange(charge.date)) continue;
    fuelByVehicle.update(charge.vehicleId, (v) => v + charge.price,
        ifAbsent: () => charge.price);
    final key = monthKey(charge.date.year, charge.date.month);
    fuelByMonth.update(key, (v) => v + charge.price, ifAbsent: () => charge.price);
  }

  var uncostedMaintenances = 0;
  for (final maintenance in maintenances) {
    final cost = maintenance.cost ?? 0;
    if (!inRange(maintenance.date)) continue;
    if (cost == 0) {
      uncostedMaintenances++;
      continue;
    }
    maintByVehicle.update(maintenance.vehicleId, (v) => v + cost,
        ifAbsent: () => cost);
    final key = monthKey(maintenance.date.year, maintenance.date.month);
    maintByMonth.update(key, (v) => v + cost, ifAbsent: () => cost);
  }

  final byVehicle = vehicles
      .map((v) => VehicleExpense(
            vehicleId: v.id ?? '',
            label: '${v.displayName} (${v.plate})',
            fuelTotal: fuelByVehicle[v.id] ?? 0,
            maintenanceTotal: maintByVehicle[v.id] ?? 0,
            vehicle: v,
          ))
      .where((e) => e.total > 0)
      .toList()
    ..sort((a, b) => b.total.compareTo(a.total));

  final byMonth = monthsRange
      .map((m) => MonthlyExpense(
            year: m.year,
            month: m.month,
            fuelTotal: fuelByMonth[monthKey(m.year, m.month)] ?? 0,
            maintenanceTotal: maintByMonth[monthKey(m.year, m.month)] ?? 0,
          ))
      .toList();

  return ExpenseDashboard(
    byVehicle: byVehicle,
    byMonth: byMonth,
    uncostedMaintenances: uncostedMaintenances,
    vehiclesWithoutExpenses: vehicles.length - byVehicle.length,
  );
}
