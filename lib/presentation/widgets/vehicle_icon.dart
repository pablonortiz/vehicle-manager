import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/constants/vehicle_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
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

// Widget para seleccionar tipo de vehículo
class VehicleTypeSelector extends StatelessWidget {
  final VehicleType? selectedType;
  final ValueChanged<VehicleType> onSelected;
  final Color vehicleColor;

  const VehicleTypeSelector({
    super.key,
    this.selectedType,
    required this.onSelected,
    this.vehicleColor = AppTheme.accentPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: VehicleType.values.map((type) {
        final isSelected = type == selectedType;
        return GestureDetector(
          onTap: () => onSelected(type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected 
                  ? vehicleColor.withValues(alpha: 0.2)
                  : AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? vehicleColor : AppTheme.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  type.iconAsset,
                  width: 36,
                  height: 36,
                  colorFilter: ColorFilter.mode(
                    isSelected ? vehicleColor : AppTheme.textSecondary,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  type.label,
                  style: TextStyle(
                    color: isSelected 
                        ? AppTheme.textPrimary 
                        : AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// Widget para seleccionar color del vehículo
class VehicleColorSelector extends StatelessWidget {
  final Color? selectedColor;
  final ValueChanged<Color> onSelected;

  const VehicleColorSelector({
    super.key,
    this.selectedColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: VehicleColors.options.map((option) {
        final isSelected = option.color.value == selectedColor?.value;
        return GestureDetector(
          onTap: () => onSelected(option.color),
          child: Tooltip(
            message: option.name,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: option.color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected 
                      ? AppTheme.accentPrimary 
                      : option.color == const Color(0xFFFFFFFF)
                          ? AppTheme.border
                          : Colors.transparent,
                  width: isSelected ? 3 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: option.color.withValues(alpha: 0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      color: option.color.computeLuminance() > 0.5
                          ? Colors.black
                          : Colors.white,
                      size: 20,
                    )
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}
