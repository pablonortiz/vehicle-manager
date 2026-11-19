import 'package:flutter/material.dart';

import '../../core/constants/provinces.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_tone.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/vehicle.dart';
import 'highlight_text.dart';
import 'plate_text.dart';
import 'status_styles.dart';
import 'vehicle_icon.dart';

/// Fila de vehículo: avatar, marca y modelo, patente, ubicación y responsable,
/// y la alerta de vencimiento si corresponde. La misma fila en la lista, la
/// búsqueda, vencimientos, seguro de flota y gastos; cada contexto solo
/// cambia el [trailing] (pill, checkbox, monto), que va junto al título.
class VehicleListTile extends StatelessWidget {
  final Vehicle vehicle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showExpiryAlert;
  final EdgeInsetsGeometry contentPadding;

  /// Término buscado: se resalta en el nombre, la ubicación y el responsable.
  final String? highlight;

  const VehicleListTile({
    super.key,
    required this.vehicle,
    this.trailing,
    this.onTap,
    this.showExpiryAlert = true,
    this.contentPadding = cardPadding,
    this.highlight,
  });

  /// Dentro de una `AppCard.list`.
  static const cardPadding = EdgeInsets.symmetric(
    horizontal: Space.s4,
    vertical: Space.s3,
  );

  /// Dentro de un sheet, que ya tiene su margen lateral.
  static const inSheetPadding = EdgeInsets.symmetric(vertical: Space.s3);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final meta = AppText.caption.copyWith(color: c.textMuted);
    final province = ArgentinaProvinces.getById(vehicle.provinceId);
    final location = [
      vehicle.city,
      province.abbreviation,
    ].where((part) => part.trim().isNotEmpty).join(', ');

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: contentPadding,
          child: Row(
            children: [
              VehicleIcon(type: vehicle.type, paint: vehicle.color),
              const Gap(Space.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: HighlightText(
                            vehicle.displayName,
                            query: highlight,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.titleSm.copyWith(color: c.text),
                          ),
                        ),
                        if (trailing != null) ...[
                          const Gap(Space.s2),
                          trailing!,
                        ],
                      ],
                    ),
                    const Gap(Space.s1),
                    Wrap(
                      spacing: Space.s2,
                      runSpacing: Space.s1,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        PlateText(vehicle.plate),
                        if (location.isNotEmpty)
                          HighlightText(
                            location,
                            query: highlight,
                            style: meta,
                          ),
                        if (vehicle.responsibleName.trim().isNotEmpty)
                          HighlightText(
                            vehicle.responsibleName,
                            query: highlight,
                            style: meta,
                          ),
                      ],
                    ),
                    if (showExpiryAlert) _ExpiryAlert(vehicle: vehicle),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Seguro venció hace 52 días · VTV vence en 12 días": `danger` + `error`
/// si algo venció, `warning` + `schedule` si solo está por vencer.
class _ExpiryAlert extends StatelessWidget {
  final Vehicle vehicle;

  const _ExpiryAlert({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final documents = vehicle.expiringDocuments;
    if (documents.isEmpty) return const SizedBox.shrink();

    final mostUrgent = documents.first.status;
    final color = mostUrgent.tone.foreground(context.colors);
    final text = documents
        .map((doc) => '${doc.label} ${doc.status.phrase}')
        .join(' · ');

    return Padding(
      padding: const EdgeInsets.only(top: Space.s1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(mostUrgent.icon, size: Sizes.iconSm, color: color),
          const Gap(Space.s1),
          Expanded(
            child: Text(
              text,
              style: AppText.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
