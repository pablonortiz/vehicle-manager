import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_vehiculos/domain/expiry_status.dart';

void main() {
  final today = DateTime(2026, 11, 19, 15, 30);

  ExpiryStatus statusIn(int days) => ExpiryStatus.of(
    DateTime(2026, 11, 19).add(Duration(days: days)),
    today: today,
  );

  test('sin fecha es desconocido', () {
    final status = ExpiryStatus.of(null, today: today);

    expect(status.state, ExpiryState.unknown);
    expect(status.label, 'Sin fecha');
    expect(status.needsAttention, isFalse);
  });

  test('más de 30 días es vigente', () {
    expect(statusIn(31).state, ExpiryState.valid);
    expect(statusIn(31).label, 'Vigente');
  });

  test('30 días o menos es por vencer', () {
    expect(statusIn(30).state, ExpiryState.expiringSoon);
    expect(statusIn(30).label, 'Vence en 30 días');
    expect(statusIn(1).label, 'Vence mañana');
  });

  test('el mismo día todavía no está vencido', () {
    final status = statusIn(0);

    expect(status.state, ExpiryState.expiringSoon);
    expect(status.label, 'Vence hoy');
  });

  test('pasada la fecha está vencido y cuenta los días', () {
    expect(statusIn(-1).state, ExpiryState.expired);
    expect(statusIn(-1).label, 'Vencido hace 1 día');
    expect(statusIn(-52).label, 'Vencido hace 52 días');
  });

  test('la hora de hoy no corre el día', () {
    final lateAtNight = ExpiryStatus.of(
      DateTime(2026, 11, 20),
      today: DateTime(2026, 11, 19, 23, 59),
    );

    expect(lateAtNight.days, 1);
  });

  test('la frase verbal sirve para cualquier documento', () {
    expect(statusIn(-1).phrase, 'venció ayer');
    expect(statusIn(-81).phrase, 'venció hace 81 días');
    expect(statusIn(0).phrase, 'vence hoy');
    expect(statusIn(12).phrase, 'vence en 12 días');
  });
}
