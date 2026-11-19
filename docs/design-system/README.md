# Gestor de Vehículos: design system

Gestor de Vehículos es una app Android para administrar una flota en Argentina: qué vehículos hay, dónde están, quién los tiene, qué documentos vencen y cuánto se gasta en combustible y mantenimiento. Se usa parado al lado del vehículo, en la calle o en el taller, muchas veces con una mano y sin conexión.

Este sistema fija cómo se ve y cómo habla la app. Parte del tema actual (celeste argentino sobre azul noche) y lo ordena: una sola paleta semántica, una escala tipográfica real, y un componente por cada patrón que hoy está repetido a mano.

## Principios

1. **La patente y el estado primero.** En toda fila, card o cabecera de vehículo se leen antes que nada la patente (`plate`) y el estado (`StatusPill`).
2. **Lo que vence no se esconde.** Un documento vencido o por vencer aparece en Inicio, en la fila del vehículo y en su detalle, con el mismo ícono, color y texto.
3. **Estado con ícono y palabra.** El color acompaña; nunca es el único indicio.
4. **Una mano, al sol.** Objetivos táctiles de `touch-min` (48px), texto mínimo de 11px, contraste 4.5:1 en los dos temas.
5. **Nada falla en silencio.** Toda carga tiene estado de carga, vacío y error con "Reintentar"; toda acción confirma su resultado.

## Voz y contenido

- **Voseo, siempre.** "Tocá", "Ingresá", "Elegí", "Revisá". Nunca "Ingrese" ni "Toca".
- **Sentence case** en títulos, botones y labels: "Nuevo vehículo", "Guardar cambios", "Por vencer", "Cargas de combustible". Nunca mayúsculas sostenidas en un botón; las mayúsculas quedan para el estilo `overline` y la patente.
- **Botones con verbo**: "Guardar carga", "Generar PDF", "Eliminar". Diálogos con pregunta: "¿Eliminar este vehículo?".
- **Errores**: "No se pudo guardar. Revisá la conexión." Empiezan con "No se pudo…", dicen qué hacer y nunca muestran la excepción.
- **Éxito** en dos o tres palabras: "Carga guardada", "Listado exportado".
- **Validación** dice qué falta: "Ingresá la patente", no "Requerido".
- **Sin conexión**, no "Offline". **Sincronización**, no "sync".
- Sin emoji ni signos de exclamación.

Términos fijos:

| Usar | En lugar de |
|---|---|
| Vencimientos (fechas de VTV y seguro) | Documentación |
| Papeles (fotos de cédula, título y VTV) | Documentos |
| Cambios (registro de modificaciones del vehículo) | Historial |
| Cargas de combustible | Registro de combustible, Ver historial |
| Adjuntos | Facturas/Archivos, Archivos guardados |
| Sin conexión | Offline |

Formatos:

- **Patente**: mayúsculas con el espacio del formato: `AE 472 KP`, `OXN 318`, `A 041 TRB`.
- **Moneda**: `$ 1.284.500` con espacio y separador de miles `es_AR`; decimales solo en precio por litro (`$ 1.289,50`).
- **Fecha**: `12 dic 2026` en lectura; `12/12/2026` solo dentro de un campo en edición; con hora `12 dic, 14:30`. Relativa para vencimientos: "Vence en 23 días", "Vencido hace 3 días".
- **Unidades**: `84.300 km`, `42,500 L` (tres decimales), `11,2 km/L`.
- **Locale**: `es_AR`.

## Color

Dos temas, Oscuro (el principal) y Claro. Todo color sale de un token; no hay hex, `Colors.*` ni opacidades en los widgets.

- **Fondos en tres niveles**: `bg` para la pantalla, `surface` para cards, sheets y barra de navegación, `surface-raised` para inputs, tiles y patente. No usar gradientes.
- **Texto en dos niveles**: `text` y `text-muted`. No bajar la opacidad de ninguno: `text-muted` ya es el mínimo legible.
- **`accent`** es la acción: botón primario, links, selección y foco. Sobre un relleno `accent` el texto es `on-accent`. `brand` (el celeste de marca) queda para la portada, el ícono de la app y el PDF.
- **Semánticos**: `success`, `warning` y `danger` como texto o ícono, cada uno con su fondo `-soft`. El texto sobre un fondo `-soft` es `text` o el color semántico, nunca blanco.
- **`warning` significa atención**, nada más: por vencer, en taller, sin conexión, pendiente de subir. No es el color de las notas ni de una categoría.
- **Estado del vehículo**: `status-available`, `status-in-use`, `status-workshop`, `status-out`. Son alias de los semánticos: "Disponible" tiene el mismo verde que "Guardado".
- **Categorías de gasto**: `cat-fuel` y `cat-maintenance`. En gráficos, cada serie lleva además su rótulo.
- **Color físico del vehículo** (`paint-*`): solo como muestra circular con anillo. Nunca tiñe el ícono ni el fondo de la cabecera.
- **Bordes**: `border` es decorativo (divisores, contorno de card). Todo control usa `border-strong`, que sí alcanza 3:1.
- **Foco**: anillo sólido de 2px en `accent` con 2px de separación.

`success` y `danger` tienen luminosidad parecida; por eso todo estado lleva ícono y palabra (principio 3).

## Tipografía

Tres familias, cada una con un trabajo:

- **Outfit** (`display`) para cifras y títulos: `display`, `title-lg`, `title-md`, `title-sm`.
- **IBM Plex Sans** (`body`) para todo el texto de interfaz: `body-lg`, `body`, `label`, `caption`, `overline`.
- **IBM Plex Mono** (`mono`) solo para la patente: `plate`, `plate-lg`.

Reglas:

- Usar los estilos por nombre. Un `TextStyle` con `fontSize` literal es un error.
- El mínimo es 11px (`overline`) y 12px (`caption`). No hay texto de 8, 9 ni 10px.
- Pesos: 400, 500 y 600. No usar `bold` ni 700.
- Una sola cifra en `display` por pantalla.
- Cifras tabulares en montos, litros, kilómetros y contadores.
- El texto respeta el tamaño de fuente del sistema hasta 1.3; ningún texto usa `RichText` sin `textScaler`.

## Espaciado y layout

- Escala: `space-1` (4) a `space-10` (40). No hay valores intermedios (6, 10, 14).
- **Margen lateral de pantalla: `space-5`** en todas las pantallas y sheets.
- Entre secciones `space-6`; entre un encabezado de sección y su contenido `space-2`; entre cards de una lista `space-3`; padding de card `space-4`.
- Listas largas se agrupan en una card con divisores (`Card` flush + `VehicleRow` o `InfoRow`) en vez de una card por ítem.
- Formularios: una columna; dos campos por fila solo si son cortos y relacionados (Año y Kilometraje, Litros y Precio).
- El formulario de vehículo se divide en grupos con `SectionHeader`: Identificación, Ubicación, Responsable, Vencimientos.

## Forma, bordes y elevación

- Radios: `radius-sm` tags, patente y tiles; `radius-md` botones, inputs y avisos; `radius-lg` cards y FAB; `radius-xl` sheets y diálogos; `radius-full` pills y chips.
- La jerarquía se arma con `surface` y `border`, no con sombra. `shadow-overlay` es la única sombra y solo va en lo que flota: FAB, menús, overlay de autocompletado, snackbar y diálogo.

## Interacción y estados

- Todo lo tocable mide al menos `touch-min` y responde con ripple (`InkWell`), no con `GestureDetector`.
- Ninguna función depende de un gesto oculto. El long-press puede existir como atajo, pero la misma acción está a la vista (un "Más opciones" en la foto, "Ver ciudades" en la provincia).
- Cargando: esqueleto o spinner dentro del componente, que conserva su tamaño. Vacío: `EmptyState`. Error: `EmptyState` de error o `Notice` con "Reintentar". Sin conexión: `Notice` banner.
- Borrado reversible: sin diálogo, con "Deshacer" en el `Snackbar`. Borrado irreversible: `Dialog` destructivo. Nunca las dos cosas.
- Movimiento: 200 ms para cambios de estado, 300 ms para scroll y sheets, curva estándar de Material. Con "reducir movimiento" activo, sin animación.

## Iconografía

- **Material Symbols Rounded**, contorno, peso 400. En Flutter: las variantes `Icons.*_rounded`. La versión rellena se reserva para el estado activo (tab seleccionada, ícono dentro de un pill).
- Tamaños: `icon-sm` (16) en pills y metadatos, `icon-md` (20) en botones y filas, `icon-lg` (24) en barras y FAB.
- Un ícono, un significado: `directions_car` es "vehículos" (no el estado "En uso", que usa `key`); `schedule` es "por vencer"; `error` es "vencido" o error; `picture_as_pdf` es exportar; `delete` es eliminar; `add_a_photo` es agregar foto.
- **Tipos de vehículo**: los SVG propios del repositorio, en `assets/icons/` (auto, camioneta, camión y moto; SUV y van existen pero ningún tipo los usa todavía), viewBox 64, una tinta con `currentColor`. Se pintan en `text`.
- Sin emoji.

## Accesibilidad

- Texto 4.5:1 y controles 3:1 en los dos temas; los tokens ya lo cumplen sobre los fondos que nombra cada nota.
- Todo `IconButton` y FAB tiene `tooltip`. Toda imagen tiene `semanticLabel`. Las cards tocables se anuncian como botón.
- El orden de foco sigue el orden visual; el foco es visible.
