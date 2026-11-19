# VehicleRow

Fila de vehículo: avatar, marca y modelo, patente, ubicación y responsable, estado a la derecha y, si corresponde, una línea de alerta de vencimiento.

Es la misma fila en la lista de Vehículos, los resultados de búsqueda, el sheet de vencimientos, el selector de seguro de flota y el ranking de gastos; cada contexto solo cambia el elemento de la derecha (pill, checkbox, monto). La alerta usa `warning` + `schedule` para "por vencer" y `danger` + `error` para "vencido". El título se trunca con elipsis; la línea de metadatos puede partirse.

El consumidor provee el `Vehicle` y el trailing. Alto mínimo 72; toda la fila es el objetivo táctil.

En Flutter: `VehicleListTile`. Reemplaza `_VehicleCard`, `_SearchResultCard`, el `ListTile` de `home_sheets.dart`, `_VehicleCheckTile` y la fila del ranking.
