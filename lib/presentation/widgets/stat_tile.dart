import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_tone.dart';
import '../../core/theme/app_typography.dart';
import 'app_card.dart';

/// Cifra en `display` con su rótulo arriba y una línea de contexto abajo; toda
/// la tile navega. Cargando o con error muestra "–", nunca "0".
class StatTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Tone tone;

  /// `null` mientras carga.
  final String? value;
  final String? hint;
  final bool failed;
  final VoidCallback? onTap;

  const StatTile({
    super.key,
    required this.label,
    required this.icon,
    this.tone = Tone.neutral,
    this.value,
    this.hint,
    this.failed = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final labelColor = tone == Tone.neutral ? c.textMuted : tone.foreground(c);
    final contextLine = failed ? 'No se pudo cargar' : hint;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: Sizes.iconSm, color: labelColor),
              const Gap(Space.s2),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(color: labelColor),
                ),
              ),
            ],
          ),
          const Gap(Space.s1),
          Text(
            failed ? '–' : value ?? '–',
            style: AppText.display.copyWith(color: c.text),
          ),
          if (contextLine != null) ...[
            const Gap(Space.s1),
            Text(
              contextLine,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(color: c.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
