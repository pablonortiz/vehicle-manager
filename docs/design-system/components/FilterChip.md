# FilterChip

Chip de selección para filtrar una lista, con contador opcional.

Seleccionado: fondo `accent-soft` y borde `accent`; sin seleccionar: borde `border-strong`. El dibujo mide 36 de alto dentro de un objetivo táctil de 48. La fila hace scroll horizontal con `space-5` de margen inicial.

El consumidor provee label, contador y estado.

En Flutter: `FilterChip` de Material estilizado por `chipTheme` con `materialTapTargetSize: padded`. Reemplaza `StatusFilterChip` (33dp de alto) y los `ActionChip` compactos.
