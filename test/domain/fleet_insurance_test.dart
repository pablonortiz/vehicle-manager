import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:gestor_vehiculos/core/constants/vehicle_constants.dart';
import 'package:gestor_vehiculos/domain/fleet_insurance.dart';
import 'package:gestor_vehiculos/domain/models/vehicle.dart';

Vehicle _vehicle(String plate, {String? company, DateTime? expiry}) => Vehicle(
      id: plate,
      plate: plate,
      type: VehicleType.car,
      brand: 'Marca',
      model: 'Modelo',
      year: 2020,
      color: const Color(0xFFFFFFFF),
      km: 0,
      fuelType: FuelType.nafta,
      status: VehicleStatus.available,
      provinceId: 1,
      city: 'La Plata',
      insuranceCompany: company,
      insuranceExpiry: expiry,
      responsibleName: 'Responsable',
      responsiblePhone: '221555',
    );

void main() {
  setUpAll(() => initializeDateFormatting('es_AR'));

  final renewal = DateTime(2027, 9, 28);

  group('InsuranceAssignment', () {
    test('normaliza la compañía en blanco a null y la fecha a medianoche', () {
      final blank = InsuranceAssignment(
          company: '   ', expiry: DateTime(2027, 9, 28, 15, 30));
      expect(blank.company, isNull);
      expect(blank.changesCompany, isFalse);
      expect(blank.expiry, DateTime(2027, 9, 28));

      final named =
          InsuranceAssignment(company: ' Nación Seguros ', expiry: renewal);
      expect(named.company, 'Nación Seguros');
      expect(named.changesCompany, isTrue);
    });

    test('label con y sin compañía', () {
      expect(
        InsuranceAssignment(company: 'Nación Seguros', expiry: renewal).label,
        'Nación Seguros · vence el 28 sept 2027',
      );
      expect(InsuranceAssignment(expiry: renewal).label, 'vence el 28 sept 2027');
    });

    test('applyTo asigna compañía y vencimiento y omite los que ya lo tienen',
        () {
      final assignment =
          InsuranceAssignment(company: 'Nación Seguros', expiry: renewal);
      final updates = assignment.applyTo([
        _vehicle('SIN'),
        _vehicle('VIEJO', company: 'Nación Seguros', expiry: DateTime(2026, 9, 28)),
        _vehicle('OTRA', company: 'La Segunda', expiry: renewal),
        _vehicle('IGUAL', company: 'Nación Seguros', expiry: renewal),
      ]);

      expect(updates.map((vehicle) => vehicle.plate), ['SIN', 'VIEJO', 'OTRA']);
      for (final vehicle in updates) {
        expect(vehicle.insuranceCompany, 'Nación Seguros');
        expect(vehicle.insuranceExpiry, renewal);
      }
    });

    test('sin compañía solo cambia el vencimiento y conserva la de cada uno',
        () {
      final assignment = InsuranceAssignment(company: '', expiry: renewal);
      final updates = assignment.applyTo([
        _vehicle('A', company: 'La Segunda', expiry: DateTime(2026, 1, 1)),
        _vehicle('B', company: null, expiry: DateTime(2026, 1, 1)),
        _vehicle('C', company: 'Otra', expiry: renewal),
      ]);

      expect(updates.map((vehicle) => vehicle.plate), ['A', 'B']);
      expect(updates[0].insuranceCompany, 'La Segunda');
      expect(updates[1].insuranceCompany, isNull);
      expect(updates.every((vehicle) => vehicle.insuranceExpiry == renewal),
          isTrue);
    });
  });

  group('insuranceCompaniesByFrequency', () {
    test('ordena de la más repetida a la menos e ignora las vacías', () {
      final companies = insuranceCompaniesByFrequency([
        _vehicle('1', company: 'La Segunda'),
        _vehicle('2', company: 'Nación Seguros'),
        _vehicle('3', company: 'Nación Seguros'),
        _vehicle('4', company: '  '),
        _vehicle('5'),
      ]);
      expect(companies, ['Nación Seguros', 'La Segunda']);
    });

    test('sin seguros devuelve lista vacía', () {
      expect(insuranceCompaniesByFrequency([_vehicle('1')]), isEmpty);
    });
  });
}
