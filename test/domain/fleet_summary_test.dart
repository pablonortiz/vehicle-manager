import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_vehiculos/core/constants/vehicle_constants.dart';
import 'package:gestor_vehiculos/domain/fleet_summary.dart';
import 'package:gestor_vehiculos/domain/models/vehicle.dart';

Vehicle _vehicle(
  String plate, {
  int provinceId = 1,
  String city = 'La Plata',
  VehicleStatus status = VehicleStatus.available,
  VehicleType type = VehicleType.car,
}) =>
    Vehicle(
      id: plate,
      plate: plate,
      type: type,
      brand: 'Marca',
      model: 'Modelo',
      year: 2020,
      color: const Color(0xFFFFFFFF),
      km: 0,
      fuelType: FuelType.nafta,
      status: status,
      provinceId: provinceId,
      city: city,
      responsibleName: 'Responsable',
      responsiblePhone: '221555',
    );

void main() {
  group('FleetSummary.countByStatus', () {
    test('cuenta por estado y omite los estados sin vehículos', () {
      final counts = FleetSummary.countByStatus([
        _vehicle('A'),
        _vehicle('B'),
        _vehicle('C', status: VehicleStatus.outOfService),
      ]);
      expect(counts, {
        VehicleStatus.available: 2,
        VehicleStatus.outOfService: 1,
      });
      expect(counts.containsKey(VehicleStatus.inUse), isFalse);
    });

    test('sin vehículos devuelve un mapa vacío', () {
      expect(FleetSummary.countByStatus([]), isEmpty);
    });
  });

  group('FleetSummary.from', () {
    test('agrupa por provincia en orden alfabético y ordena por ciudad y patente',
        () {
      final summary = FleetSummary.from([
        _vehicle('ZZZ111', provinceId: 6, city: 'Río Cuarto'),
        _vehicle('AAA222', provinceId: 1, city: 'Mar del Plata'),
        _vehicle('BBB333', provinceId: 1, city: 'La Plata'),
        _vehicle('AAA111', provinceId: 1, city: 'la plata'),
        _vehicle('CCC444', provinceId: 6, city: 'Córdoba'),
      ]);

      expect(summary.total, 5);
      expect(
        summary.byProvince.map((group) => group.province.name),
        ['Buenos Aires', 'Córdoba'],
      );
      expect(
        summary.byProvince.first.vehicles.map((vehicle) => vehicle.plate),
        ['AAA111', 'BBB333', 'AAA222'],
      );
      expect(
        summary.sortedVehicles.map((vehicle) => vehicle.plate),
        ['AAA111', 'BBB333', 'AAA222', 'CCC444', 'ZZZ111'],
      );
    });

    test('cuenta por tipo y por estado', () {
      final summary = FleetSummary.from([
        _vehicle('A', type: VehicleType.truck),
        _vehicle('B', type: VehicleType.truck, status: VehicleStatus.inUse),
        _vehicle('C', type: VehicleType.motorcycle),
      ]);
      expect(summary.byType, {VehicleType.truck: 2, VehicleType.motorcycle: 1});
      expect(summary.byStatus,
          {VehicleStatus.available: 2, VehicleStatus.inUse: 1});
    });

    test('sin vehículos no tiene grupos', () {
      final summary = FleetSummary.from([]);
      expect(summary.total, 0);
      expect(summary.byProvince, isEmpty);
      expect(summary.sortedVehicles, isEmpty);
    });
  });

  group('FleetReportScope', () {
    test('toda la flota', () {
      const scope = FleetReportScope();
      expect(scope.title, 'Flota completa');
      expect(scope.subtitle, 'Flota completa');
      expect(scope.fileName(DateTime(2026, 9, 5)), 'listado_vehiculos_20260905');
    });

    test('acotado a una ubicación sin estado', () {
      const scope = FleetReportScope(locationLabel: 'Córdoba');
      expect(scope.title, 'Flota completa');
      expect(scope.subtitle, 'Todos los vehículos · Córdoba');
    });

    test('acotado a un estado y una ubicación', () {
      const scope = FleetReportScope(
        status: VehicleStatus.outOfService,
        locationLabel: 'Buenos Aires > La Plata',
      );
      expect(scope.title, 'Vehículos fuera de servicio');
      expect(scope.subtitle,
          'Vehículos fuera de servicio · Buenos Aires > La Plata');
      expect(
        scope.fileName(DateTime(2026, 9, 15)),
        'listado_vehiculos_fuera_de_servicio_20260915',
      );
    });
  });
}
