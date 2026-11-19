import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_tone.dart';
import '../../core/theme/app_typography.dart';

/// Label de campo: siempre arriba, en `overline` y mayúsculas; " *" si es
/// obligatorio.
class FieldLabel extends StatelessWidget {
  final String text;
  final bool required;

  const FieldLabel(this.text, {super.key, this.required = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      '${text.toUpperCase()}${required ? ' *' : ''}',
      style: AppText.overline.copyWith(color: context.colors.textMuted),
    );
  }
}

/// Mensaje bajo un campo, con ícono: error en `danger`, dato leído por OCR en
/// `success`.
class FieldMessage extends StatelessWidget {
  final String text;
  final Tone tone;

  const FieldMessage(this.text, {super.key, this.tone = Tone.neutral});

  @override
  Widget build(BuildContext context) {
    final color = tone.foreground(context.colors);
    final icon = switch (tone) {
      Tone.danger => Icons.error_rounded,
      Tone.success => Icons.check_circle_rounded,
      _ => Icons.info_rounded,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: Sizes.iconSm, color: color),
        const Gap(Space.s1),
        Expanded(
          child: Text(text, style: AppText.caption.copyWith(color: color)),
        ),
      ],
    );
  }
}

/// Campo de formulario con el label arriba, relleno `surface-raised` y el
/// error con ícono. El validador dice qué falta, en voseo.
class AppTextField extends StatelessWidget {
  final String label;
  final bool required;
  final TextEditingController? controller;
  final String? initialValue;
  final String? hint;
  final IconData? icon;
  final String? prefixText;
  final String? suffixText;
  final Widget? suffix;
  final String? helper;
  final Tone helperTone;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final TextCapitalization textCapitalization;
  final int? maxLines;
  final int? minLines;
  final bool autofocus;
  final FocusNode? focusNode;
  final bool enabled;

  const AppTextField({
    super.key,
    required this.label,
    this.required = false,
    this.controller,
    this.initialValue,
    this.hint,
    this.icon,
    this.prefixText,
    this.suffixText,
    this.suffix,
    this.helper,
    this.helperTone = Tone.neutral,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.minLines,
    this.autofocus = false,
    this.focusNode,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldLabel(label, required: required),
        const Gap(Space.s2),
        TextFormField(
          controller: controller,
          initialValue: initialValue,
          focusNode: focusNode,
          autofocus: autofocus,
          enabled: enabled,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          minLines: minLines,
          onChanged: onChanged,
          validator: validator,
          style: AppText.bodyLg.copyWith(color: context.colors.text),
          errorBuilder: (context, error) =>
              FieldMessage(error, tone: Tone.danger),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon == null ? null : Icon(icon, size: Sizes.iconMd),
            prefixText: prefixText,
            suffixText: suffixText,
            suffixIcon: suffix,
            helper: helper == null
                ? null
                : FieldMessage(helper!, tone: helperTone),
          ),
        ),
      ],
    );
  }
}
