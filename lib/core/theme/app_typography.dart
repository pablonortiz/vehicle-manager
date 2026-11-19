import 'package:flutter/painting.dart';

abstract final class AppFonts {
  /// Cifras y títulos.
  static const display = 'Outfit';

  /// Todo el texto de interfaz.
  static const body = 'IBMPlexSans';

  /// Solo la patente.
  static const mono = 'IBMPlexMono';
}

/// Escala tipográfica del design system. Sin color: lo aporta el tema o el
/// call site con `context.colors`. Nunca crear un `TextStyle(fontSize: …)`.
abstract final class AppText {
  static const _tabular = [FontFeature.tabularFigures()];

  /// Cifra protagonista; una por pantalla.
  static const display = TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 32,
    height: 36 / 32,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    fontFeatures: _tabular,
  );

  /// Título de pantalla raíz y nombre del vehículo en el detalle.
  static const titleLg = TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 24,
    height: 30 / 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.25,
  );

  /// Título de AppBar, sheet y diálogo.
  static const titleMd = TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w600,
  );

  /// Título de sección y de card; nombre del vehículo en una fila.
  static const titleSm = TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w600,
  );

  /// Texto de inputs y valores de dato.
  static const bodyLg = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
  );

  /// Texto corrido, filas y descripciones.
  static const body = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );

  /// Botones, chips, tabs y valor destacado.
  static const label = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
  );

  /// Metadatos, ayudas, pills y tabs. Junto con [overline], el mínimo de la app.
  static const caption = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
  );

  /// Label de campo y rótulo de grupo; el texto va en mayúsculas.
  static const overline = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 11,
    height: 16 / 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
  );

  static const plate = TextStyle(
    fontFamily: AppFonts.mono,
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.2,
  );

  /// Patente en la cabecera del detalle.
  static const plateLg = TextStyle(
    fontFamily: AppFonts.mono,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.8,
  );
}

extension TabularFigures on TextStyle {
  /// Cifras de ancho fijo para montos, litros, kilómetros y contadores.
  TextStyle get tabular =>
      copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}
