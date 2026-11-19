import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/text_normalizer.dart';

/// Texto con la primera coincidencia de [query] resaltada (sin distinguir
/// mayúsculas ni acentos). Usa `Text.rich`, que respeta el tamaño de texto
/// del sistema.
class HighlightText extends StatelessWidget {
  final String text;
  final String? query;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  const HighlightText(
    this.text, {
    super.key,
    this.query,
    this.style,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final needle = _fold(query?.trim() ?? '');
    final start = needle.isEmpty ? -1 : _fold(text).indexOf(needle);
    if (start == -1) {
      return Text(text, style: style, maxLines: maxLines, overflow: overflow);
    }
    final end = start + needle.length;
    final c = context.colors;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text.substring(0, start)),
          TextSpan(
            text: text.substring(start, end),
            style: TextStyle(
              backgroundColor: c.accentSoft,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: text.substring(end)),
        ],
      ),
      style: style,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  /// Minúsculas y sin acentos, carácter por carácter: los índices coinciden
  /// con los del texto original.
  static String _fold(String value) =>
      value.split('').map(TextNormalizer.normalizeChar).join();
}
