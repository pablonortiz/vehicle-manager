# ChartScale

Escala de ejes para los gráficos de combustible y gastos: topes redondos y etiquetas que no se cortan.

- El máximo del eje se redondea hacia arriba a un valor legible; las etiquetas usan `AppFormats.moneyCompact` ("$ 250 mil", "$ 1,25 M").
- Las etiquetas reservan lugar según el tamaño de fuente del sistema, así no se recortan con letra grande.
- Series: `cat-fuel` y `cat-maintenance`, cada una con su rótulo. Texto de ejes en `caption` y `text-muted`.

El consumidor provee los valores de la serie.

En Flutter: `ChartScale`, usado por `fl_chart` en Cargas de combustible y Gastos.
