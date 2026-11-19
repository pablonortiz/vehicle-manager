import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/fuel_charge.dart';
import 'app_card.dart';

/// Resumen de un mes de cargas: gasto, litros, precio promedio y cantidad.
class FuelMonthSummary extends StatelessWidget {
  final FuelChargeSummary summary;

  const FuelMonthSummary({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final charges = summary.chargeCount;
    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryValue(
                  label: 'Gastado',
                  value: AppFormats.money(summary.totalPrice),
                ),
              ),
              Expanded(
                child: _SummaryValue(
                  label: 'Litros',
                  value: AppFormats.liters(summary.totalLiters),
                ),
              ),
            ],
          ),
          const Gap(Space.s4),
          Row(
            children: [
              Expanded(
                child: _SummaryValue(
                  label: 'Precio por litro',
                  value: AppFormats.pricePerLiter(summary.averagePricePerLiter),
                ),
              ),
              Expanded(
                child: _SummaryValue(
                  label: 'Cargas',
                  value: charges == 1 ? '1 carga' : '$charges cargas',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.caption.copyWith(color: c.textMuted)),
        const Gap(Space.s1),
        Text(value, style: AppText.titleMd.tabular.copyWith(color: c.text)),
      ],
    );
  }
}
