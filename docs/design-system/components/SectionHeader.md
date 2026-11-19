# SectionHeader

Título de sección en `title-sm` color `text`, con contador opcional y una acción de texto a la derecha.

Una sola forma para todas las secciones de pantalla y de sheet. La acción lleva verbo visible ("Agregar", "Ver todas"), no un ícono suelto. Separación: `space-6` antes del encabezado, `space-2` hasta su contenido.

El consumidor provee título en sentence case, contador y acción.

En Flutter: `SectionHeader(title, {count, action})`. Reemplaza las ~12 variantes: `_SectionTitle`, los dos `_SectionLabel`, `_SectionHeader` y los títulos inline de Ajustes, Gastos y gráficos.
