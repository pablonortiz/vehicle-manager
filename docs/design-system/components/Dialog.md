# Dialog

Diálogo de confirmación con título en forma de pregunta, una consecuencia concreta y dos acciones con verbo.

- **Destructivo irreversible** (vehículo, foto, documento, factura): botón `danger` relleno con el verbo ("Eliminar"), y el texto dice qué más se borra.
- **Descartar cambios**: no es destructivo; botón secundario "Descartar" y "Seguir editando" como salida.
- **Borrado reversible** (carga, mantenimiento, nota): sin diálogo; se borra y se ofrece "Deshacer" en el snackbar. No combinar confirmación y deshacer.
- **Cambio masivo** (seguro de flota): confirma con el número de vehículos afectados.

El consumidor provee título, consecuencia y el label del verbo.

En Flutter: `confirmDestructive()` y `confirmDiscard()` en `lib/core/utils/confirm_dialog.dart`. Reemplaza el uso de `confirmDelete` para descartar y el diálogo propio del detalle.
