import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_tone.dart';
import '../../core/theme/app_typography.dart';

/// Etiqueta de una palabra para un atributo (Principal, OCR, PDF, provincia).
class AppTag extends StatelessWidget {
  final String label;
  final Tone tone;

  const AppTag(this.label, {super.key, this.tone = Tone.neutral});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tone.background(c),
        borderRadius: Radii.smAll,
      ),
      child: Text(
        label,
        maxLines: 1,
        style: AppText.overline.copyWith(
          color: tone == Tone.neutral ? c.textMuted : tone.foreground(c),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Contador numérico redondo, con cifras tabulares.
class CountBadge extends StatelessWidget {
  final int count;

  const CountBadge(this.count, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: Space.s2),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: Radii.fullAll,
      ),
      // widthFactor 1: centra dentro del mínimo sin estirarse.
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          '$count',
          style: AppText.caption.tabular.copyWith(
            color: c.text,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
