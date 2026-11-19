import 'package:flutter/widgets.dart';

/// Escala de espaciado del design system (`space-*`). No hay valores intermedios.
abstract final class Space {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;

  /// Margen lateral de toda pantalla y sheet: único valor para el gutter.
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;
  static const double s10 = 40;
}

/// Radios de esquina (`radius-*`).
abstract final class Radii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double full = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius fullAll = BorderRadius.all(Radius.circular(full));
  static const BorderRadius xlTop =
      BorderRadius.vertical(top: Radius.circular(xl));
}

/// Medidas fijas (`size-*`).
abstract final class Sizes {
  /// Alto y ancho mínimo de todo objetivo táctil.
  static const double touchMin = 48;

  /// Alto de inputs y del botón primario de un formulario.
  static const double controlH = 52;
  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;
}

/// Duraciones de animación: cambios de estado y scroll/sheets.
abstract final class Motion {
  static const Duration short = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 300);
}

/// Espacio fijo entre hijos de un `Row` o `Column`, siempre de la escala [Space].
class Gap extends StatelessWidget {
  final double size;

  const Gap(this.size, {super.key});

  @override
  Widget build(BuildContext context) => SizedBox.square(dimension: size);
}
