import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_tone.dart';
import '../../core/theme/app_typography.dart';
import 'app_text_field.dart';

/// Date picker con el tema de la app y los textos en voseo y sentence case
/// (Material en español trae "Selecciona una fecha" y "ACEPTAR").
Future<DateTime?> showAppDatePicker(
  BuildContext context, {
  DateTime? initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
  DatePickerMode initialMode = DatePickerMode.day,
}) {
  return showDatePicker(
    context: context,
    initialDate: initialDate ?? DateTime.now(),
    firstDate: firstDate ?? DateTime(2000),
    lastDate: lastDate ?? DateTime(2100),
    initialDatePickerMode: initialMode,
    helpText: 'Elegí una fecha',
    cancelText: 'Cancelar',
    confirmText: 'Aceptar',
    fieldLabelText: 'Fecha',
    fieldHintText: 'dd/mm/aaaa',
    errorFormatText: 'Ingresá una fecha válida',
    errorInvalidText: 'La fecha está fuera de rango',
  );
}

/// Campo de fecha: mismo aspecto que `AppTextField`, con `calendar_today` a
/// la derecha. Cancelar el picker no toca el valor; [onCleared] habilita
/// "Quitar fecha" para los campos opcionales.
class AppDateField extends StatelessWidget {
  final String label;
  final bool required;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final VoidCallback? onCleared;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String? errorText;

  const AppDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.required = false,
    this.onCleared,
    this.firstDate,
    this.lastDate,
    this.errorText,
  });

  static final _format = DateFormat('dd/MM/yyyy');

  Future<void> _pick(BuildContext context) async {
    final picked = await showAppDatePicker(
      context,
      initialDate: value,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final current = value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldLabel(label, required: required),
        const Gap(Space.s2),
        Semantics(
          button: true,
          label: label,
          value: current == null ? 'Sin fecha' : _format.format(current),
          excludeSemantics: true,
          // Sin esto TalkBack no lo puede activar: excludeSemantics descarta
          // también la acción del InkWell.
          onTap: () => _pick(context),
          child: InkWell(
            onTap: () => _pick(context),
            borderRadius: Radii.mdAll,
            child: InputDecorator(
              isEmpty: current == null,
              decoration: InputDecoration(
                hintText: 'Elegí una fecha',
                error: errorText == null
                    ? null
                    : FieldMessage(errorText!, tone: Tone.danger),
                suffixIcon: const Icon(
                  Icons.calendar_today_rounded,
                  size: Sizes.iconMd,
                ),
              ),
              child: current == null
                  ? null
                  : Text(
                      _format.format(current),
                      style: AppText.bodyLg.tabular.copyWith(color: c.text),
                    ),
            ),
          ),
        ),
        if (current != null && onCleared != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onCleared,
              child: const Text('Quitar fecha'),
            ),
          ),
      ],
    );
  }
}
