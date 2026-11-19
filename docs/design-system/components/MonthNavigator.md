# MonthNavigator

Selector de mes con anterior y siguiente, y el mes en `title-sm`.

Los botones miden 48×48 y llevan tooltip ("Mes anterior", "Mes siguiente"). El botón deshabilitado usa `text-muted` pleno, no una opacidad de 0.3. Tocar el mes abre un selector de mes y año.

El consumidor provee el mes actual y los límites.

En Flutter: `MonthNavigator` (`lib/presentation/widgets/month_navigator.dart`), compartido por Combustible y Gastos.
