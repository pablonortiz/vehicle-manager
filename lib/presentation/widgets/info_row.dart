import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';

/// Par label-valor dentro de una `AppCard.list`. El label ocupa el 38% (mínimo
/// 96) y el valor puede partirse en varias líneas, así resiste texto ampliado.
class InfoRow extends StatelessWidget {
  final String label;
  final String? value;

  /// Acompaña al valor: un `StatusPill`, por ejemplo.
  final Widget? trailing;

  const InfoRow({super.key, required this.label, this.value, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.s4,
        vertical: Space.s3,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelWidth = math.max(96.0, constraints.maxWidth * 0.38);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: labelWidth,
                child: Text(
                  label,
                  style: AppText.body.copyWith(color: c.textMuted),
                ),
              ),
              const Gap(Space.s3),
              Expanded(
                child: Wrap(
                  spacing: Space.s2,
                  runSpacing: Space.s1,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (value != null)
                      Text(
                        value!,
                        style: AppText.body.tabular.copyWith(
                          color: c.text,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ?trailing,
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
