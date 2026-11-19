# AppBar

Barra superior con dos formas: raíz (título `title-lg`, sin volver) y de detalle (volver + título `title-md`).

Todas las pantallas usan esta barra, también Inicio, Vehículos, Ajustes y el formulario. Hasta dos acciones con ícono a la derecha; el resto va en el menú "Más opciones". Todo `IconButton` lleva tooltip ("Volver", "Buscar", "Cerrar"). El botón volver es el de Material por defecto, no uno propio.

El consumidor provee título en sentence case y acciones.

En Flutter: `AppBar` / `SliverAppBar` con `appBarTheme`. Reemplaza los 5 sistemas de título (headers inline de Inicio, Vehículos y Ajustes, el `SliverAppBar` custom y el header sticky del formulario).
