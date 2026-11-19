# Button

Botón con una jerarquía fija: un solo primario por pantalla o sheet.

- **Primario** (`gv-btn--primary`): la acción que cierra la tarea. En formularios y sheets va a ancho completo (`gv-btn--block`, alto `control-h`).
- **Secundario**: acción alternativa del mismo peso (Llamar, Exportar listado, Limpiar filtros).
- **Texto**: acción de baja jerarquía dentro de una sección (Ver todos, Deshacer, Cancelar).
- **Destructivo**: relleno `danger` solo dentro del diálogo de confirmación; como texto (`gv-btn--danger-text`) para iniciar el borrado desde la pantalla.
- **WhatsApp**: único uso de `whatsapp`.
- **Ícono** (`gv-iconbtn`): 48×48 siempre, con `tooltip` obligatorio.

El consumidor provee: label en sentence case con verbo ("Guardar cambios", nunca "GUARDAR"), ícono opcional a la izquierda, y el estado de carga. En carga el botón conserva el ancho, muestra el spinner en `currentColor` y el gerundio ("Guardando…").

En Flutter: `FilledButton`, `OutlinedButton`, `TextButton` e `IconButton` estilizados desde `ThemeData`; no pasar `style:` en el call site. Reemplaza los `ElevatedButton` con `SizedBox(width: double.infinity)` y los `GestureDetector` usados como botón.
