# Snackbar

Mensaje breve sobre el resultado de una acción: siempre sobre `surface-raised`, con el estado en el ícono y no en el fondo.

El texto del snackbar sobre fondos `success`, `warning` o `error` hoy queda entre 1.57 y 3.15 de contraste; por eso el fondo es neutro y el color va solo en el ícono (`success`, `danger`, `warning`). Duración: 4 s; 6 s si trae acción. Una sola acción de texto ("Deshacer", "Reintentar").

Redacción: éxito en dos o tres palabras ("Carga guardada"); error como "No se pudo…" más qué hacer. Nunca mostrar la excepción (`Error: $e`).

El consumidor provee tipo, mensaje y acción.

En Flutter: `AppSnack.success/error/offline(context, message, {action})`. Reemplaza los 38 `showSnackBar` y las tres copias del borrado diferido con deshacer.
