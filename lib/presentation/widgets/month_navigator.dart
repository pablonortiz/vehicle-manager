import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../providers/fuel_charge_provider.dart';

class MonthNavigator extends StatelessWidget {
  final SelectedMonthState selectedMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  const MonthNavigator({
    super.key,
    required this.selectedMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentMonth =
        selectedMonth.year == now.year && selectedMonth.month == now.month;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(color: AppTheme.border),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: onPreviousMonth,
            icon: const Icon(Icons.chevron_left, color: AppTheme.accentPrimary),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.surfaceLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Text(
            selectedMonth.displayText,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          IconButton(
            onPressed: isCurrentMonth ? null : onNextMonth,
            icon: Icon(
              Icons.chevron_right,
              color: isCurrentMonth
                  ? AppTheme.textSecondary.withOpacity(0.3)
                  : AppTheme.accentPrimary,
            ),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.surfaceLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
