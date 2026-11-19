import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/plate_format.dart';

/// Patente monoespaciada, en mayúsculas y con el espacio del formato, sobre
/// `surface-raised`. Es el identificador principal del vehículo.
class PlateText extends StatelessWidget {
  final String plate;
  final bool large;

  const PlateText(this.plate, {super.key, this.large = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (plate.trim().isEmpty) {
      return Text(
        'Sin patente',
        style: AppText.caption.copyWith(color: c.textMuted),
      );
    }
    // Sin `alignment`: un Container alineado se estira a todo el ancho
    // disponible (en un Wrap ocuparía la fila entera).
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? Space.s3 : Space.s2,
        vertical: large ? 4 : 2,
      ),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: Radii.smAll,
        border: Border.all(color: c.border),
      ),
      child: Text(
        formatPlate(plate),
        maxLines: 1,
        softWrap: false,
        style: (large ? AppText.plateLg : AppText.plate).copyWith(
          color: c.text,
        ),
      ),
    );
  }
}
