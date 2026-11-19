import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_vehiculos/core/constants/vehicle_constants.dart';
import 'package:gestor_vehiculos/domain/expense_summary.dart';
import 'package:gestor_vehiculos/domain/models/vehicle.dart';
import 'package:gestor_vehiculos/domain/models/fuel_charge.dart';
import 'package:gestor_vehiculos/domain/models/maintenance.dart';

Vehicle _v(String id, String plate) => Vehicle(
      id: id,
      plate: plate,
      type: VehicleType.car,
      brand: 'B',
      model: 'M',
      year: 2020,
      color: const Color(0xFFFFFFFF),
      km: 0,
      fuelType: FuelType.nafta,
      status: VehicleStatus.available,
      provinceId: 1,
      city: 'C',
      responsibleName: 'R',
      responsiblePhone: 'P',
    );

FuelCharge _f(String vid, DateTime date, double price) =>
    FuelCharge(vehicleId: vid, date: date, liters: 10, price: price);

Maintenance _m(String vid, DateTime date, double? cost) =>
    Maintenance(vehicleId: vid, date: date, detail: 'd', cost: cost);

void main() {
  final now = DateTime(2026, 6, 15);

  group('buildExpenseDashboard (#Ft3)', () {
    test('agrega por vehículo y por mes, con ranking descendente', () {
      final dash = buildExpenseDashboard(
        vehicles: [_v('a', 'AAA'), _v('b', 'BBB')],
        fuelCharges: [
          _f('a', DateTime(2026, 6, 1), 1000),
          _f('a', DateTime(2026, 5, 1), 500),
          _f('b', DateTime(2026, 6, 5), 300),
        ],
        maintenances: [
          _m('a', DateTime(2026, 6, 10), 2000),
          _m('b', DateTime(2026, 6, 12), null), // sin costo → no suma
        ],
        now: now,
      );

      expect(dash.byVehicle.length, 2);
      expect(dash.byVehicle.first.vehicleId, 'a'); // mayor total primero
      expect(dash.byVehicle.first.total, 3500); // 1500 fuel + 2000 maint
      expect(dash.byVehicle[1].total, 300);
      expect(dash.fuelTotal, 1800);
      expect(dash.maintenanceTotal, 2000);
      expect(dash.grandTotal, 3800);
      expect(dash.byMonth.length, 6);
    });

    test('excluye registros fuera del rango de 6 meses', () {
      final dash = buildExpenseDashboard(
        vehicles: [_v('a', 'AAA')],
        fuelCharges: [
          _f('a', DateTime(2026, 6, 1), 1000),
          _f('a', DateTime(2025, 1, 1), 9999), // muy viejo
        ],
        maintenances: [],
        now: now,
      );
      expect(dash.grandTotal, 1000);
    });

    test('un vehículo sin gastos no aparece en el ranking', () {
      final dash = buildExpenseDashboard(
        vehicles: [_v('a', 'AAA'), _v('b', 'BBB')],
        fuelCharges: [_f('a', DateTime(2026, 6, 1), 1000)],
        maintenances: [],
        now: now,
      );
      expect(dash.byVehicle.length, 1);
      expect(dash.byVehicle.first.vehicleId, 'a');
      expect(dash.byVehicle.first.vehicle?.plate, 'AAA');
      expect(dash.vehiclesWithoutExpenses, 1);
    });

    test('el rango sigue la cantidad de meses pedida', () {
      final dash = buildExpenseDashboard(
        vehicles: [_v('a', 'AAA')],
        fuelCharges: [
          _f('a', DateTime(2026, 6, 1), 1000),
          _f('a', DateTime(2025, 8, 1), 500), // entra en 12 meses, no en 6
        ],
        maintenances: [],
        now: now,
        months: 12,
      );
      expect(dash.byMonth.length, 12);
      expect(dash.grandTotal, 1500);
    });
  });
}
