import 'package:intl/intl.dart';

/// Formateo de números en convención es_AR: "$ 1.234.567", "194.571 km", "23,562 L".
class AppFormats {
  AppFormats._();

  // customPattern: la data de intl para es_AR pone el símbolo detrás
  // ("159.000 $"); la convención local es adelante ("$ 159.000").
  static final NumberFormat _money = NumberFormat.currency(
    locale: 'es_AR',
    symbol: r'$',
    decimalDigits: 0,
    customPattern: '¤ #,##0',
  );
  static final NumberFormat _integer = NumberFormat.decimalPattern('es_AR');
  // Siempre 3 decimales: es la precisión que muestra el surtidor. Mantener
  // también los ceros finales evita que 240,320 L se vea como 240,32 L.
  static final NumberFormat _liters = NumberFormat('#,##0.000', 'es_AR');

  static String money(num value) => _money.format(value);

  static String integer(num value) => _integer.format(value);

  static String km(num value) => '${_integer.format(value)} km';

  static String liters(num value) => '${_liters.format(value)} L';
}
