final _mercosurCar = RegExp(r'^([A-Z]{2})(\d{3})([A-Z]{2})$');
final _mercosurMoto = RegExp(r'^([A-Z])(\d{3})([A-Z]{3})$');
final _legacyCar = RegExp(r'^([A-Z]{3})(\d{3})$');
final _legacyMoto = RegExp(r'^(\d{3})([A-Z]{3})$');

/// Patente en mayúsculas con el espacio del formato: "AE 472 KP" (Mercosur),
/// "A 041 TRB" (moto Mercosur), "OXN 318" y "123 ABC" (anteriores). Un formato
/// desconocido se devuelve tal cual, en mayúsculas.
String formatPlate(String raw) {
  final compact = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  for (final format in [_mercosurCar, _mercosurMoto, _legacyCar, _legacyMoto]) {
    final match = format.firstMatch(compact);
    if (match != null) {
      return [
        for (var i = 1; i <= match.groupCount; i++) match.group(i),
      ].join(' ');
    }
  }
  return raw.trim().toUpperCase();
}
