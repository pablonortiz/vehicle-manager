import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/constants/vehicle_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// Ícono del tipo de vehículo en `text` sobre `surface-raised`, con la muestra
/// del color físico en la esquina. Nunca se tiñe con el color del vehículo y
/// no lleva el estado: eso lo comunica el `StatusPill`.
class VehicleIcon extends StatelessWidget {
  final VehicleType type;
  final Color paint;

  /// 72 en la cabecera del detalle; 48 en filas.
  final bool large;

  const VehicleIcon({
    super.key,
    required this.type,
    required this.paint,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final size = large ? 72.0 : 48.0;
    final glyph = large ? 44.0 : 30.0;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.surfaceRaised,
              borderRadius: large ? Radii.lgAll : Radii.mdAll,
            ),
            child: SvgPicture.asset(
              type.iconAsset,
              width: glyph,
              height: glyph,
              semanticsLabel: type.label,
              colorFilter: ColorFilter.mode(c.text, BlendMode.srcIn),
            ),
          ),
          Positioned(right: -5, bottom: -5, child: PaintSwatch(paint)),
        ],
      ),
    );
  }
}

/// Muestra circular del color físico con anillo `surface` + `border-strong`,
/// para que Blanco y Negro se distingan en los dos temas.
class PaintSwatch extends StatelessWidget {
  final Color color;
  final double size;

  const PaintSwatch(this.color, {super.key, this.size = 14});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size + 6,
      height: size + 6,
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(color: c.borderStrong, shape: BoxShape.circle),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
