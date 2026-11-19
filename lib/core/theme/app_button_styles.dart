import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Variantes de botón que no tiene Material: el relleno `danger` (solo dentro
/// del diálogo de confirmación) y el de WhatsApp.
abstract final class AppButtonStyles {
  static ButtonStyle danger(BuildContext context) {
    final c = context.colors;
    return FilledButton.styleFrom(
      backgroundColor: c.danger,
      foregroundColor: c.onDanger,
    );
  }

  /// Texto destructivo, para iniciar un borrado desde la pantalla.
  static ButtonStyle dangerText(BuildContext context) =>
      TextButton.styleFrom(foregroundColor: context.colors.danger);

  static ButtonStyle whatsapp(BuildContext context) {
    final c = context.colors;
    return FilledButton.styleFrom(
      backgroundColor: c.whatsapp,
      foregroundColor: c.onWhatsapp,
    );
  }
}
