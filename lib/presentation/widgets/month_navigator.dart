import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../providers/fuel_charge_provider.dart';
import 'app_date_field.dart';

/// Selector de mes con anterior y siguiente (48×48, con tooltip). Tocar el mes
/// abre un selector de mes y año cuando hay [onSelectMonth].
class MonthNavigator extends StatelessWidget {
  final SelectedMonthState selectedMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<SelectedMonthState>? onSelectMonth;

  const MonthNavigator({
    super.key,
    required this.selectedMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
    this.onSelectMonth,
  });

  Future<void> _pickMonth(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context,
      initialDate: DateTime(selectedMonth.year, selectedMonth.month),
      lastDate: now,
      initialMode: DatePickerMode.year,
    );
    if (picked != null) {
      onSelectMonth!(
        SelectedMonthState(year: picked.year, month: picked.month),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentMonth =
        selectedMonth.year == now.year && selectedMonth.month == now.month;
    final label = Text(
      selectedMonth.displayText,
      style: AppText.titleSm.copyWith(color: context.colors.text),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.s2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'Mes anterior',
            onPressed: onPreviousMonth,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Flexible(
            child: onSelectMonth == null
                ? label
                : TextButton(
                    onPressed: () => _pickMonth(context),
                    child: label,
                  ),
          ),
          IconButton(
            tooltip: 'Mes siguiente',
            onPressed: isCurrentMonth ? null : onNextMonth,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}
