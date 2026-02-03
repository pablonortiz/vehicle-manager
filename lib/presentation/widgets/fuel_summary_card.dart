import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/fuel_charge.dart';

class FuelSummaryCard extends StatelessWidget {
  final FuelChargeSummary summary;

  const FuelSummaryCard({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'es_AR',
      symbol: '\$',
      decimalDigits: 0,
    );

    final pricePerLiterFormat = NumberFormat.currency(
      locale: 'es_AR',
      symbol: '\$',
      decimalDigits: 0,
    );

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentPrimary.withOpacity(0.15),
            AppTheme.accentDark.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentPrimary.withOpacity(0.3)),
      ),
      child: summary.chargeCount == 0
          ? _buildEmptyState()
          : _buildSummaryContent(currencyFormat, pricePerLiterFormat),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Sin cargas este mes',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryContent(
    NumberFormat currencyFormat,
    NumberFormat pricePerLiterFormat,
  ) {
    return Row(
      children: [
        Expanded(
          child: _SummaryItem(
            icon: Icons.local_gas_station,
            label: 'Total',
            value: '${summary.totalLiters.toStringAsFixed(1)} L',
          ),
        ),
        Container(
          width: 1,
          height: 40,
          color: AppTheme.border,
        ),
        Expanded(
          child: _SummaryItem(
            icon: Icons.attach_money,
            label: 'Gastado',
            value: currencyFormat.format(summary.totalPrice),
          ),
        ),
        Container(
          width: 1,
          height: 40,
          color: AppTheme.border,
        ),
        Expanded(
          child: _SummaryItem(
            icon: Icons.trending_up,
            label: 'Promedio',
            value: '${pricePerLiterFormat.format(summary.averagePricePerLiter)}/L',
          ),
        ),
        Container(
          width: 1,
          height: 40,
          color: AppTheme.border,
        ),
        Expanded(
          child: _SummaryItem(
            icon: Icons.format_list_numbered,
            label: 'Cargas',
            value: summary.chargeCount.toString(),
          ),
        ),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.accentPrimary, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppTheme.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
