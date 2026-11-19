# Notice

Aviso dentro del contenido (información, atención o error) y banner global de "Sin conexión".

- **Aviso**: fondo `-soft`, ícono en el color semántico, texto en `text`. Explica algo sobre los datos que se ven; puede traer una acción de texto.
- **Error de sección**: cuando falla la carga de fotos, documentos, combustible o gráficos se muestra este aviso con "Reintentar". Nunca ocultar la sección.
- **Banner sin conexión**: `warning-soft` con texto `text` (no blanco sobre ámbar). Ocupa lugar en el layout, debajo de la barra de estado: empuja el contenido, no lo tapa. Es el único indicador offline; no repetirlo como chip.

El consumidor provee tono, texto y acción opcional.

En Flutter: `SheetNotice` generalizado a `AppNotice`, y `OfflineBanner` dentro de un `Column`. Reemplaza `_UncostedNotice`, el chip "Offline" de Inicio y los `SizedBox.shrink` de error.
