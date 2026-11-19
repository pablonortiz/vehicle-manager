import 'package:flutter/material.dart';

import '../theme/app_button_styles.dart';

/// Confirmación de un borrado irreversible (vehículo, foto, papel, adjunto):
/// título en forma de pregunta, la consecuencia concreta y el verbo en un
/// botón `danger`. Devuelve true solo si el usuario confirma.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Eliminar',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    // Material en español anuncia la barrera como "Descartar": choca con el
    // botón homónimo de confirmDiscard.
    barrierLabel: 'Cerrar',
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: AppButtonStyles.danger(dialogContext),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Salir con cambios sin guardar. No es destructivo: "Descartar" es un botón
/// secundario y "Seguir editando" la salida. Devuelve true si descarta.
Future<bool> confirmDiscard(BuildContext context) async {
  final discard = await showDialog<bool>(
    context: context,
    barrierLabel: 'Cerrar',
    builder: (dialogContext) => AlertDialog(
      title: const Text('¿Descartar los cambios?'),
      content: const Text('Lo que cargaste todavía no está guardado.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Seguir editando'),
        ),
        OutlinedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Descartar'),
        ),
      ],
    ),
  );
  return discard ?? false;
}
