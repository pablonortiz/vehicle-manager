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

  // Decimales solo en el precio por litro: "$ 1.289,50".
  static final NumberFormat _pricePerLiter = NumberFormat.currency(
    locale: 'es_AR',
    symbol: r'$',
    decimalDigits: 2,
    // Espacio no separable, como en money: el signo nunca queda solo al final
    // de una línea.
    customPattern: '¤\u00A0#,##0.00',
  );
  static final DateFormat _date = DateFormat('d MMM y', 'es_AR');
  static final DateFormat _dayMonth = DateFormat('d MMM', 'es_AR');
  static final DateFormat _time = DateFormat('HH:mm', 'es_AR');

  static String pricePerLiter(num value) => _pricePerLiter.format(value);

  /// Fecha de lectura: "12 dic 2026" (en un campo en edición va dd/MM/yyyy).
  static String date(DateTime value) => _stripDots(_date.format(value));

  /// "12 dic, 14:30"; con el año si no es el actual: "12 dic 2025, 14:30".
  static String dateTime(DateTime value, {DateTime? now}) {
    final day = value.year == (now ?? DateTime.now()).year
        ? _dayMonth.format(value)
        : _date.format(value);
    return '${_stripDots(day)}, ${_time.format(value)}';
  }

  /// Algunas versiones de la data de intl abrevian el mes con punto ("dic.").
  static String _stripDots(String value) => value.replaceAll('.', '');
}
