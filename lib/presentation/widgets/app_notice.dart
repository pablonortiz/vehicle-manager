import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_tone.dart';
import '../../core/theme/app_typography.dart';

/// Aviso dentro del contenido: fondo `-soft`, ícono en el color semántico y
/// texto en `text`. También es el error de sección, con "Reintentar".
class AppNotice extends StatelessWidget {
  final String message;
  final String? title;
  final IconData? icon;
  final Tone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppNotice({
    super.key,
    required this.message,
    this.title,
    this.icon,
    this.tone = Tone.info,
    this.actionLabel,
    this.onAction,
  });

  /// Error de carga de una sección: nunca se oculta la sección.
  const AppNotice.error({
    super.key,
    required this.message,
    required VoidCallback onRetry,
  }) : title = null,
       icon = Icons.error_rounded,
       tone = Tone.danger,
       actionLabel = 'Reintentar',
       onAction = onRetry;

  IconData get _defaultIcon => switch (tone) {
    Tone.warning => Icons.warning_rounded,
    Tone.danger => Icons.error_rounded,
    Tone.success => Icons.check_circle_rounded,
    _ => Icons.info_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = actionLabel;
    return Container(
      padding: const EdgeInsets.all(Space.s3),
      decoration: BoxDecoration(
        color: tone.background(c),
        borderRadius: Radii.mdAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon ?? _defaultIcon,
            size: Sizes.iconMd,
            color: tone.foreground(c),
          ),
          const Gap(Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(title!, style: AppText.label.copyWith(color: c.text)),
                Text(message, style: AppText.body.copyWith(color: c.text)),
                if (label != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(onPressed: onAction, child: Text(label)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
