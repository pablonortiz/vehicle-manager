import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_tone.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/confirm_dialog.dart';

/// Abre un sheet sobre el navigator raíz (tapa la barra inferior y el FAB).
/// Los sheets con formulario pasan `enableDrag: false`: arrastrar cierra sin
/// pasar por la confirmación de "Descartar cambios".
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: builder,
    isScrollControlled: true,
    useRootNavigator: true,
    useSafeArea: true,
    enableDrag: enableDrag,
  );
}

/// Marco común de todo sheet: handle, título y "Cerrar" arriba, contenido con
/// scroll y la acción primaria fija al pie, por encima del teclado.
class AppSheet extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? footer;

  /// Si hay cambios sin guardar, cerrar pide confirmación.
  final bool hasUnsavedChanges;

  const AppSheet({
    super.key,
    required this.title,
    required this.child,
    this.footer,
    this.hasUnsavedChanges = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // viewInsets sube el pie sobre el teclado; SafeArea lo separa de la barra
    // de gestos cuando el teclado está cerrado.
    final sheet = Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Gap(Space.s2),
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: c.borderStrong,
                  borderRadius: Radii.fullAll,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.s5,
                Space.s2,
                Space.s2,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: AppText.titleMd.copyWith(color: c.text),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  Space.s5,
                  Space.s2,
                  Space.s5,
                  Space.s5,
                ),
                child: child,
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.s5,
                  0,
                  Space.s5,
                  Space.s5,
                ),
                child: footer,
              ),
          ],
        ),
      ),
    );

    if (!hasUnsavedChanges) return sheet;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await confirmDiscard(context) && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: sheet,
    );
  }
}

/// Opción de un sheet de opciones: fila de 56 con tile de ícono.
class AppSheetOption<T> {
  final T value;
  final IconData icon;
  final String label;
  final String? description;
  final Tone tone;

  const AppSheetOption({
    required this.value,
    required this.icon,
    required this.label,
    this.description,
    this.tone = Tone.info,
  });
}

/// Sheet de opciones (origen de foto, exportar): devuelve la elegida o null.
Future<T?> showAppOptionsSheet<T>(
  BuildContext context, {
  required String title,
  required List<AppSheetOption<T>> options,
}) {
  return showAppSheet<T>(
    context,
    builder: (sheetContext) => AppSheet(
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [for (final option in options) _OptionRow(option: option)],
      ),
    ),
  );
}

class _OptionRow<T> extends StatelessWidget {
  final AppSheetOption<T> option;

  const _OptionRow({required this.option});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final description = option.description;
    return InkWell(
      borderRadius: Radii.mdAll,
      onTap: () => Navigator.pop(context, option.value),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.s2),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: option.tone.background(c),
                  borderRadius: Radii.smAll,
                ),
                child: Icon(
                  option.icon,
                  size: Sizes.iconMd,
                  color: option.tone.foreground(c),
                ),
              ),
              const Gap(Space.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: AppText.bodyLg.copyWith(color: c.text),
                    ),
                    if (description != null)
                      Text(
                        description,
                        style: AppText.caption.copyWith(color: c.textMuted),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
