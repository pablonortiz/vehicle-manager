import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Chip de filtro con contador opcional; el estilo sale de `chipTheme` (36 de
/// alto dentro de un objetivo táctil de 48).
class AppFilterChip extends StatelessWidget {
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      onSelected: (_) => onTap(),
      label: Text.rich(
        TextSpan(
          text: label,
          children: [
            if (count != null)
              TextSpan(
                text: '  $count',
                style: TextStyle(
                  color: context.colors.textMuted,
                  fontWeight: FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
