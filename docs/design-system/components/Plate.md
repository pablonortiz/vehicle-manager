# Plate

Patente en estilo `plate`: monoespaciada, mayúsculas, con el espacio del formato y fondo `surface-raised`.

Formatos: Mercosur auto `AB 123 CD`, Mercosur moto `A 123 BCD`, anterior `ABC 123`. El consumidor provee la patente tal como está guardada; el componente la normaliza y agrega los espacios. Es el identificador principal del vehículo: va junto al nombre en toda fila y como `plate-lg` en la cabecera del detalle.

En Flutter: `PlateText(plate, {large})`. Reemplaza los 6 `TextStyle` con `letterSpacing` 1 o 2 y color accent.
