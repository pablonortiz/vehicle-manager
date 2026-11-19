import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_vehiculos/domain/models/fuel_charge.dart';
import 'package:gestor_vehiculos/presentation/widgets/fuel_charts.dart';

FuelCharge _c({required DateTime date, required double liters, int? odometer}) =>
    FuelCharge(
      vehicleId: 'v1',
      date: date,
      liters: liters,
      price: 1000,
      odometer: odometer,
    );

void main() {
  group('consumptionPoints (#Ft2)', () {
    test('km/L por tramo entre cargas consecutivas con odómetro', () {
      final pts = consumptionPoints([
        _c(date: DateTime(2026, 1, 1), liters: 40, odometer: 1000),
        _c(date: DateTime(2026, 1, 10), liters: 40, odometer: 1400), // 400/40 = 10
        _c(date: DateTime(2026, 1, 20), liters: 50, odometer: 1900), // 500/50 = 10
      ]);
      expect(pts.length, 2);
      expect(pts[0].kmPerLiter, 10);
      expect(pts[0].date, DateTime(2026, 1, 10));
      expect(pts[1].kmPerLiter, 10);
    });

    test('saltea cargas sin odómetro y calcula el tramo entre las que sí tienen', () {
      final pts = consumptionPoints([
        _c(date: DateTime(2026, 1, 1), liters: 40, odometer: 1000),
        _c(date: DateTime(2026, 1, 10), liters: 40, odometer: null),
        _c(date: DateTime(2026, 1, 20), liters: 40, odometer: 1800), // 800/40 = 20
      ]);
      expect(pts.length, 1);
      expect(pts.first.kmPerLiter, 20);
    });

    test('descarta tramos con km no positivo (odómetro repetido)', () {
      final pts = consumptionPoints([
        _c(date: DateTime(2026, 1, 1), liters: 40, odometer: 1000),
        _c(date: DateTime(2026, 1, 10), liters: 40, odometer: 1000), // km=0 → descarta
        _c(date: DateTime(2026, 1, 20), liters: 40, odometer: 1400), // 400/40 = 10
      ]);
      expect(pts.length, 1);
      expect(pts.first.kmPerLiter, 10);
    });

    test('menos de 2 cargas con odómetro → vacío', () {
      expect(
        consumptionPoints([_c(date: DateTime(2026, 1, 1), liters: 40, odometer: 1000)]),
        isEmpty,
      );
      expect(consumptionPoints([]), isEmpty);
    });

    test('devuelve los tramos en orden de fecha aunque el odómetro venga cruzado', () {
      final pts = consumptionPoints([
        _c(date: DateTime(2026, 3, 1), liters: 40, odometer: 1000),
        _c(date: DateTime(2026, 1, 1), liters: 40, odometer: 1400),
        _c(date: DateTime(2026, 2, 1), liters: 50, odometer: 1900),
      ]);
      expect(pts.map((point) => point.date),
          [DateTime(2026, 1, 1), DateTime(2026, 2, 1)]);
    });
  });
}
