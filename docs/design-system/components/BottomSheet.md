# BottomSheet

Marco común de todo bottom sheet: `surface`, esquinas superiores `radius-xl`, handle, título `title-md` a la izquierda, cerrar a la derecha y la acción primaria a ancho completo al pie.

- Handle de 32×4 en `border-strong`, solo si el sheet se puede arrastrar. Los sheets con formulario no se arrastran (`enableDrag: false`) y se cierran con el botón.
- Botón cerrar con tooltip "Cerrar". Si hay cambios sin guardar, cerrar pide confirmación con el diálogo "Descartar cambios".
- El contenido hace scroll; el botón primario queda fijo sobre el teclado.
- Sheets de opciones (origen de foto, exportar) usan filas de 56 con tile de ícono en lugar de formulario.

El consumidor provee título, contenido y acción primaria.

En Flutter: `AppSheet` + `bottomSheetTheme`. Reemplaza las 18 llamadas a `showModalBottomSheet` con 4 estilos y 3 colores de handle, y los 4 sheets copiados de "Cámara / Galería / Archivo".
