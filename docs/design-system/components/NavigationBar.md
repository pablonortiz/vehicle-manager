# NavigationBar

Barra inferior con cuatro destinos (Inicio, Vehículos, Gastos, Ajustes) y FAB extendido para la acción de alta de la pestaña.

Gastos pasa a ser un destino propio: hoy solo se llega por un ícono sin rótulo en Inicio. El destino activo lleva indicador `accent-soft`, ícono relleno en `accent` y label en `text`. El FAB es extendido (ícono + palabra): "Vehículo" en Inicio y Vehículos, "Carga" en la pantalla de combustible; no aparece en Gastos ni Ajustes.

El consumidor provee el destino activo y la acción del FAB.

En Flutter: `NavigationBar` con `navigationBarTheme` y `FloatingActionButton.extended` con tooltip, en `MainShell` (`lib/core/utils/router.dart`).
