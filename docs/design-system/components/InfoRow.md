# InfoRow

Par label-valor dentro de una card agrupada: label en `text-muted`, valor en `text` peso 500.

La columna del label ocupa 38% con mínimo 96px (no un ancho fijo de 90), y el valor puede partirse en varias líneas, así resiste texto ampliado. Un `StatusPill` puede acompañar al valor. Los números usan cifras tabulares y formato `es_AR`.

El consumidor provee label, valor y estado opcional.

En Flutter: `InfoRow` dentro de `AppCard.flush`. Reemplaza `_InfoCard` e `_InfoRow` de `detail_widgets.dart`.
