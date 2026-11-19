# StatusPill

Pill que comunica un estado con ícono + palabra + color; nunca con color solo.

Estado del vehículo:

| Estado | Variante | Ícono |
|---|---|---|
| Disponible | `success` | `check_circle` |
| En uso | `info` | `key` |
| En taller | `warning` | `build` |
| Fuera de servicio | `danger` | `block` |

Vencimiento de VTV y seguro:

| Situación | Variante | Ícono | Texto |
|---|---|---|---|
| Más de 30 días | `success` | `verified` | Vigente |
| 30 días o menos | `warning` | `schedule` | Vence en N días |
| Pasada la fecha | `danger` | `error` | Vencido hace N días |
| Sin dato | neutra | `help` | Sin fecha |

Vencido usa siempre `danger` + `error`: no mostrar `warning` para un documento vencido. El consumidor provee el estado (enum); el pill resuelve color, ícono y texto.

En Flutter: `StatusPill.vehicle(VehicleStatus)` y `StatusPill.expiry(DateTime?)`. Reemplaza las 6 representaciones actuales del estado (pill del detalle, pill del form, texto de 11px, punto del dropdown, badge del ícono, chip) y los hex propios de `vehicle_constants.dart`.
