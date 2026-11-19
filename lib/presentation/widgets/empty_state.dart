import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_tone.dart';
import '../../core/theme/app_typography.dart';

/// Bloque centrado para una lista sin datos o que no pudo cargarse: tile de
/// ícono, título, una línea de ayuda y una acción.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Crear lo que falta es primario; limpiar filtros o reintentar, secundario.
  final bool primaryAction;
  final Tone tone;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.primaryAction = true,
    this.tone = Tone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = actionLabel;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.s6,
        vertical: Space.s8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: tone.background(c),
              borderRadius: Radii.lgAll,
            ),
            child: Icon(icon, size: Sizes.iconLg, color: tone.foreground(c)),
          ),
          const Gap(Space.s4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppText.titleSm.copyWith(color: c.text),
          ),
          if (message != null) ...[
            const Gap(Space.s2),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                message!,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: c.textMuted),
              ),
            ),
          ],
          if (label != null && onAction != null) ...[
            const Gap(Space.s4),
            primaryAction
                ? FilledButton(onPressed: onAction, child: Text(label))
                : OutlinedButton(onPressed: onAction, child: Text(label)),
          ],
        ],
      ),
    );
  }
}
