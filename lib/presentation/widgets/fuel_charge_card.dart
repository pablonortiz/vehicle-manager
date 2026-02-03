import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/fuel_charge.dart';

class FuelChargeCard extends StatelessWidget {
  final FuelCharge fuelCharge;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool isDeleting;

  const FuelChargeCard({
    super.key,
    required this.fuelCharge,
    required this.onTap,
    required this.onDelete,
    this.isDeleting = false,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM', 'es');
    final currencyFormat = NumberFormat.currency(
      locale: 'es_AR',
      symbol: '\$',
      decimalDigits: 0,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Fecha
                Container(
                  width: 50,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        fuelCharge.date.day.toString(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentPrimary,
                        ),
                      ),
                      Text(
                        dateFormat.format(fuelCharge.date).split(' ').last.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Info principal
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.local_gas_station,
                            size: 16,
                            color: AppTheme.accentPrimary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${fuelCharge.liters.toStringAsFixed(1)} L',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            currencyFormat.format(fuelCharge.price),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.accentPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '\$${fuelCharge.calculatedPricePerLiter.toStringAsFixed(0)}/L',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          if (fuelCharge.odometer != null) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.speed,
                              size: 12,
                              color: AppTheme.textSecondary.withOpacity(0.7),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${NumberFormat('#,###').format(fuelCharge.odometer)} km',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (fuelCharge.notes != null && fuelCharge.notes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          fuelCharge.notes!,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary.withOpacity(0.8),
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Indicadores de fotos y botón eliminar
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (fuelCharge.receiptPhotoUrl != null)
                          _PhotoIndicator(
                            icon: Icons.receipt_long,
                            imageUrl: fuelCharge.receiptPhotoUrl!,
                          ),
                        if (fuelCharge.displayPhotoUrl != null) ...[
                          if (fuelCharge.receiptPhotoUrl != null)
                            const SizedBox(width: 4),
                          _PhotoIndicator(
                            icon: Icons.local_gas_station,
                            imageUrl: fuelCharge.displayPhotoUrl!,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (isDeleting)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      GestureDetector(
                        onTap: onDelete,
                        child: Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: AppTheme.error.withOpacity(0.7),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoIndicator extends StatelessWidget {
  final IconData icon;
  final String imageUrl;

  const _PhotoIndicator({
    required this.icon,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showFullScreenImage(context, imageUrl),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppTheme.accentPrimary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 16,
          color: AppTheme.accentPrimary,
        ),
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(),
                ),
                errorWidget: (_, __, ___) => const Icon(Icons.error),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
