import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';

/// Barra de una pantalla raíz (Inicio, Vehículos, Gastos, Ajustes): título en
/// `title-lg`, sin volver, con margen lateral `space-5`.
class RootAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  const RootAppBar({super.key, required this.title, this.actions, this.bottom});

  static const _toolbarHeight = 64.0;

  @override
  Size get preferredSize => Size.fromHeight(
      _toolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: _toolbarHeight,
      titleSpacing: Space.s5,
      title: Text(title, style: AppText.titleLg),
      actions: [...?actions, const Gap(Space.s2)],
      bottom: bottom,
    );
  }
}
