# AppForm

Formulario que valida todos sus campos al guardar y lleva la vista al primer error.

- Antes del primer intento de guardar no muestra errores. Después de ese intento, cada campo se revalida mientras se corrige.
- Al fallar, hace scroll hasta el campo con error que esté más arriba.
- Los campos se agrupan con `SectionHeader`. En el formulario de vehículo: Identificación, Ubicación, Responsable y Vencimientos.

El consumidor provee los campos y llama a `validateAndReveal()` antes de guardar.

En Flutter: `AppForm` (`lib/presentation/widgets/app_form.dart`).
