import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';

/// Campo de fecha con look de input: abre el date picker con el tema oscuro
/// de la app y permite limpiar el valor con la cruz. Cancelar el picker no
/// toca el valor actual.
class DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String placeholder;

  const DatePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.placeholder = 'Seleccionar fecha',
  });

  static final _dateFormat = DateFormat('dd/MM/yyyy');

  Future<void> _pick(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.accentPrimary,
            surface: AppTheme.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (date != null) onChanged(date);
  }

  @override
  Widget build(BuildContext context) {
    final current = value;
    return GestureDetector(
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today),
          suffixIcon: current != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  tooltip: 'Limpiar fecha',
                  onPressed: () => onChanged(null),
                )
              : null,
        ),
        child: Text(
          current != null ? _dateFormat.format(current) : placeholder,
          style: TextStyle(
            color: current != null ? AppTheme.textPrimary : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
