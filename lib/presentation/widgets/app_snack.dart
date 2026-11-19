import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_tone.dart';

/// Mensajes breves sobre el resultado de una acción. El fondo es siempre
/// neutro y el estado va en el ícono: texto sobre `success`/`danger` no
/// alcanza contraste. Éxito en dos o tres palabras; error con "No se pudo…".
abstract final class AppSnack {
  static void success(BuildContext context, String message) =>
      _show(context, message, Icons.check_circle_rounded, Tone.success);

  static void error(
    BuildContext context,
    String message, {
    SnackBarAction? action,
  }) =>
      _show(context, message, Icons.error_rounded, Tone.danger, action: action);

  static void offline(BuildContext context, String message) =>
      _show(context, message, Icons.cloud_off_rounded, Tone.warning);

  static void info(BuildContext context, String message) =>
      _show(context, message, Icons.info_rounded, Tone.info);

  /// Borrado reversible: la fila ya se ocultó y el borrado real corre solo si
  /// el snackbar vence sin "Deshacer". Devuelve true si hay que borrar.
  static Future<bool> undoableDelete(
    BuildContext context,
    String message,
  ) async {
    final controller = _show(
      context,
      message,
      Icons.delete_rounded,
      Tone.neutral,
      action: SnackBarAction(label: 'Deshacer', onPressed: () {}),
    );
    final reason = await controller.closed;
    return reason != SnackBarClosedReason.action;
  }

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> _show(
    BuildContext context,
    String message,
    IconData icon,
    Tone tone, {
    SnackBarAction? action,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    return messenger.showSnackBar(
      SnackBar(
        duration: Duration(seconds: action == null ? 4 : 6),
        // Desde Flutter 3.29 un snackbar con acción no se cierra solo: el
        // borrado diferido nunca se confirmaría.
        persist: false,
        action: action,
        content: Row(
          children: [
            Icon(
              icon,
              size: Sizes.iconMd,
              color: tone.foreground(context.colors),
            ),
            const Gap(Space.s3),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
