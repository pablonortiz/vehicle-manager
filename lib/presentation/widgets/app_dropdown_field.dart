import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import 'app_text_field.dart';

/// Campo desplegable con el label arriba, como `AppTextField`. Para cinco
/// opciones o más; con menos, todas a la vista.
class AppDropdownField<T> extends StatelessWidget {
  final String label;
  final bool required;
  final T initialValue;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T> onChanged;
  final IconData? icon;

  const AppDropdownField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.items,
    required this.onChanged,
    this.required = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldLabel(label, required: required),
        const Gap(Space.s2),
        DropdownButtonFormField<T>(
          initialValue: initialValue,
          items: items,
          isExpanded: true,
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
          style: AppText.bodyLg.copyWith(color: c.text),
          dropdownColor: c.surfaceRaised,
          borderRadius: Radii.mdAll,
          icon: const Icon(Icons.expand_more_rounded),
          decoration: InputDecoration(
            prefixIcon: icon == null ? null : Icon(icon, size: Sizes.iconMd),
          ),
        ),
      ],
    );
  }
}
