# VehicleSelectors

Selectores de tipo de vehículo y de color físico para el formulario.

- **Tipo** (`VehicleTypeSelector`): una opción por tipo con su ícono SVG y nombre.
- **Color** (`PaintColorSelector`): muestras `paint-*` de 48dp. El nombre del color va en el tooltip y en el lector de pantalla; la marca de selección usa `PaintColors.inkOn(color)` para contrastar sobre cualquier muestra.
- **Estado del vehículo**: se elige con `FilterChip` de selección única (`ChoiceChip`), no con un desplegable.

El consumidor provee el valor seleccionado y `onChanged`.

En Flutter: `lib/presentation/widgets/vehicle_selectors.dart`.
