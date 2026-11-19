# StatTile

Cifra en `display` con un rótulo arriba y una línea de contexto abajo; toda la tile navega al listado filtrado.

El número va siempre en `text`; el color semántico vive en el rótulo y su ícono. Estados: cargando muestra un guion "–" (no "..."); si la consulta falla muestra "–" y la línea "No se pudo cargar", nunca "0". "Por vencer" y "Vencidos" son tiles separadas.

El consumidor provee rótulo en sentence case, valor, contexto y destino.

En Flutter: `StatTile`. Reemplaza `_StatCard` (`home_screen.dart`) y las estadísticas de Ajustes.
