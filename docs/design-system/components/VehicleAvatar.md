# VehicleAvatar

Ícono del tipo de vehículo en `text` sobre `surface-raised`, con una muestra circular del color físico en la esquina.

El ícono nunca se tiñe con el color del vehículo: hoy un vehículo Negro, Azul Marino, Gris Oscuro o Marrón queda invisible sobre su propio tinte (contraste 1.05 a 1.7). El color físico se muestra aparte como `gv-paint`, con anillo `surface` + `border-strong` para que Blanco y Negro se distingan en ambos temas. El estado del vehículo no va en el avatar: lo comunica `StatusPill`.

El consumidor provee `VehicleType` y el color. Tamaños: 48 (filas) y 72 (cabecera del detalle).

En Flutter: `VehicleIcon` simplificado (`lib/presentation/widgets/vehicle_icon.dart`). Usar los SVG de `assets/icons/`.
