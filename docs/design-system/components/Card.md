# Card

Superficie única para agrupar contenido: `surface`, borde `border` de 1px, `radius-lg`, padding `space-4`, sin sombra.

- **Base**: un bloque de contenido.
- **Lista agrupada** (`gv-card--flush`): filas separadas por un divisor `border`; reemplaza a una card por fila en Ajustes, Información y Documentación.
- **Atención** (`gv-card--attention`): borde `warning`; solo cuando el contenido pide una acción del usuario.

No anidar cards. No usar gradientes ni sombras. Las cards tocables llevan `InkWell` (ripple), nunca `GestureDetector`.

En Flutter: `AppCard` (ya existe en `lib/presentation/widgets/app_card.dart`) extendido con `onTap` y la variante `flush`. Reemplaza los ~20 `Container` + `BoxDecoration` armados a mano y sus radios 12/14/16/20.
