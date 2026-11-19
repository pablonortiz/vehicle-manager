import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';

/// Título de sección en `title-sm`, con contador opcional y una acción de
/// texto con verbo a la derecha ("Agregar", "Ver todas").
class SectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const SectionHeader(
    this.title, {
    super.key,
    this.count,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = actionLabel;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: Sizes.touchMin),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text.rich(
                TextSpan(
                  text: title,
                  children: [
                    if (count != null)
                      TextSpan(
                        text: '  $count',
                        style: TextStyle(
                          color: c.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                style: AppText.titleSm.copyWith(color: c.text),
              ),
            ),
          ),
          if (label != null)
            actionIcon == null
                ? TextButton(onPressed: onAction, child: Text(label))
                : TextButton.icon(
                    onPressed: onAction,
                    icon: Icon(actionIcon),
                    label: Text(label),
                  ),
        ],
      ),
    );
  }
}
