# TextField

Campo de formulario con el label siempre arriba en `overline`, relleno `surface-raised`, borde `border-strong` y alto `control-h`.

- **Label**: arriba, nunca flotante ni adentro. Obligatorio se marca con " *".
- **Foco**: borde `accent` de 2px. **Error**: borde `danger` + mensaje con ícono, en voseo y diciendo qué hacer ("Ingresá los litros cargados").
- **Fecha**: mismo campo con ícono `calendar_today` a la derecha; abre el date picker con el tema de la app. **Autocompletado**: mismo campo; el overlay usa `surface-raised` y `shadow-overlay`.
- **Dato leído por OCR**: ayuda en `success` "Leído del ticket".

El consumidor provee label, valor, `prefixText` opcional ("$" en montos), teclado adecuado (numérico para km, litros y montos), validador y formateador.

En Flutter: `AppTextField` y `AppDateField` sobre `inputDecorationTheme`. Reemplaza la mezcla de labels afuera/adentro del formulario de vehículo, el `OutlineInputBorder()` sin tema de los autocompletados (radio 4) y los tres selectores de fecha distintos.
