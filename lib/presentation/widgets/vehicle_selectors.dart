import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/constants/vehicle_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';

/// Tipo de vehículo: una fila de opciones con el ícono propio de cada tipo.
class VehicleTypeSelector extends StatelessWidget {
  final VehicleType selected;
  final ValueChanged<VehicleType> onSelected;

  const VehicleTypeSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (index, type) in VehicleType.values.indexed) ...[
          if (index > 0) const Gap(Space.s2),
          Expanded(
            child: _TypeOption(
              type: type,
              selected: type == selected,
              onTap: () => onSelected(type),
            ),
          ),
        ],
      ],
    );
  }
}

class _TypeOption extends StatelessWidget {
  final VehicleType type;
  final bool selected;
  final VoidCallback onTap;

  const _TypeOption({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? c.accentSoft : c.surfaceRaised,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.mdAll,
          side: BorderSide(
            color: selected ? c.accent : c.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                vertical: Space.s3, horizontal: Space.s1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  type.iconAsset,
                  width: 32,
                  height: 32,
                  excludeFromSemantics: true,
                  colorFilter: ColorFilter.mode(c.text, BlendMode.srcIn),
                ),
                const Gap(Space.s1),
                Text(
                  type.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.label.copyWith(
                    color: selected ? c.text : c.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Color físico: muestras tocables de 48 con el nombre en el tooltip y en el
/// lector de pantalla. El anillo distingue Blanco y Negro en los dos temas.
class PaintColorSelector extends StatelessWidget {
  final Color selected;
  final ValueChanged<Color> onSelected;

  const PaintColorSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final selectedArgb = selected.toARGB32();
    return Wrap(
      spacing: Space.s1,
      runSpacing: Space.s1,
      children: [
        for (final option in VehicleColors.options)
          _PaintOption(
            option: option,
            selected: option.color.toARGB32() == selectedArgb,
            onTap: () => onSelected(option.color),
          ),
      ],
    );
  }
}

class _PaintOption extends StatelessWidget {
  final VehicleColorOption option;
  final bool selected;
  final VoidCallback onTap;

  const _PaintOption({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // excludeSemantics descarta también la acción del InkResponse: el tap va
    // declarado acá para que TalkBack lo pueda activar.
    return Tooltip(
      message: option.name,
      child: Semantics(
        label: option.name,
        button: true,
        selected: selected,
        inMutuallyExclusiveGroup: true,
        excludeSemantics: true,
        onTap: onTap,
        child: InkResponse(
          onTap: onTap,
          radius: Sizes.touchMin / 2,
          child: SizedBox.square(
            dimension: Sizes.touchMin,
            child: Center(
              child: AnimatedContainer(
                duration: Motion.short,
                width: 40,
                height: 40,
                padding: EdgeInsets.all(selected ? 3 : 1),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? c.accent : c.borderStrong,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: option.color,
                    shape: BoxShape.circle,
                  ),
                  child: selected
                      ? Icon(
                          Icons.check_rounded,
                          size: Sizes.iconMd,
                          color: PaintColors.inkOn(option.color),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
