# EmptyState

Bloque centrado para una lista sin datos o que no pudo cargarse: tile de ícono, título, una línea de ayuda y una acción.

- **Vacío**: dice qué falta y ofrece crearlo (botón primario).
- **Vacío por filtros**: "Ningún vehículo coincide" + "Limpiar filtros" (secundario).
- **Error**: tile `danger`, "No se pudo…" + "Reintentar" (secundario).

El ícono usa `text-muted` pleno, no con opacidad. El consumidor provee ícono, título, ayuda y acción.

En Flutter: `EmptyState` y `ErrorRetryView` (ya existen) como única implementación. Reemplaza los 8 vacíos locales y los textos planos de error de búsqueda, sheets y filtro.
