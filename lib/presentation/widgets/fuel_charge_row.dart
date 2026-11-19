import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/fuel_charge.dart';

/// Una carga en la lista del mes. Tocarla abre la edición, donde están las
/// fotos y "Eliminar carga" (ya no hay un tacho de 20 dp en la fila).
class FuelChargeRow extends StatelessWidget {
  final FuelCharge charge;
  final VoidCallback onTap;

  const FuelChargeRow({super.key, required this.charge, required this.onTap});

  String? get _photosLabel {
    final hasReceipt = charge.receiptPhotoUrl != null;
    final hasDisplay = charge.displayPhotoUrl != null;
    if (hasReceipt && hasDisplay) return 'Ticket y surtidor';
    if (hasReceipt) return 'Ticket';
    if (hasDisplay) return 'Surtidor';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final notes = charge.notes?.trim() ?? '';
    final details = [
      '${AppFormats.pricePerLiter(charge.calculatedPricePerLiter)} por litro',
      if (charge.odometer != null) AppFormats.km(charge.odometer!),
    ].join(' · ');
    final photos = _photosLabel;
    final caption = AppText.caption.copyWith(color: c.textMuted);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Space.s4, vertical: Space.s3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DayTile(date: charge.date),
            const Gap(Space.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppFormats.liters(charge.liters),
                          style: AppText.label.tabular.copyWith(color: c.text),
                        ),
                      ),
                      Text(
                        AppFormats.money(charge.price),
                        style: AppText.label.tabular.copyWith(color: c.text),
                      ),
                    ],
                  ),
                  const Gap(Space.s1),
                  Text(details, style: caption.tabular),
                  if (notes.isNotEmpty)
                    Text(
                      notes,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: caption,
                    ),
                  if (photos != null) ...[
                    const Gap(Space.s1),
                    Row(
                      children: [
                        Icon(Icons.photo_camera_rounded,
                            size: Sizes.iconSm, color: c.textMuted),
                        const Gap(Space.s1),
                        Text(photos, style: caption),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  final DateTime date;

  const _DayTile({required this.date});

  static final _month = DateFormat('MMM', 'es_AR');

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: Space.s1),
      decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: Radii.smAll),
      child: Column(
        children: [
          Text('${date.day}', style: AppText.titleSm.tabular.copyWith(color: c.text)),
          Text(
            _month.format(date).replaceAll('.', ''),
            style: AppText.caption.copyWith(color: c.textMuted),
          ),
        ],
      ),
    );
  }
}
