import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// Superficie única para agrupar contenido: `surface`, borde `border`,
/// `radius-lg` y sin sombra. Tocable con ripple; [attention] marca contenido
/// que pide una acción del usuario.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool attention;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.s4),
    this.margin,
    this.onTap,
    this.attention = false,
  });

  /// Lista agrupada: las filas traen su propio padding y van separadas por
  /// un divisor, en vez de una card por fila.
  AppCard.list({
    super.key,
    required List<Widget> children,
    this.margin,
    this.attention = false,
  }) : padding = EdgeInsets.zero,
       onTap = null,
       child = Column(
         mainAxisSize: MainAxisSize.min,
         children: [
           for (var i = 0; i < children.length; i++) ...[
             if (i > 0) const Divider(),
             children[i],
           ],
         ],
       );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final content = Padding(padding: padding, child: child);
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: SizedBox(
        width: double.infinity,
        child: Material(
          color: c.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: Radii.lgAll,
            side: BorderSide(color: attention ? c.warning : c.border),
          ),
          child: onTap == null
              ? content
              : Semantics(
                  button: true,
                  child: InkWell(onTap: onTap, child: content),
                ),
        ),
      ),
    );
  }
}
