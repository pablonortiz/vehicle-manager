import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import 'app_snack.dart';

/// Flujo común de exportar un PDF: diálogo de progreso → generar → cerrar el
/// diálogo → compartir → feedback. El diálogo se cierra una sola vez (flag
/// dialogOpen) para que un fallo al compartir no saque la pantalla de la pila.
/// Diálogo y cierre van sobre el navigator raíz: desde una pantalla del shell
/// (con bottom bar) el navigator más cercano no es el que abrió el diálogo.
Future<void> runPdfExport(
  BuildContext context, {
  required String progressTitle,
  required String progressSubtitle,
  required Future<Uint8List> Function() generate,
  required String fileName,
  required String successMessage,
  required String errorMessage,
}) async {
  _showProgressDialog(context, progressTitle, progressSubtitle);

  var dialogOpen = true;
  try {
    final pdfBytes = await generate();

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      dialogOpen = false;
    }

    await Printing.sharePdf(bytes: pdfBytes, filename: '$fileName.pdf');

    if (context.mounted) AppSnack.success(context, successMessage);
  } catch (_) {
    if (dialogOpen && context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    if (context.mounted) AppSnack.error(context, errorMessage);
  }
}

void _showProgressDialog(BuildContext context, String title, String subtitle) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (dialogContext) {
      final c = dialogContext.colors;
      return PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const Gap(Space.s5),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.titleSm.copyWith(color: c.text)),
                    const Gap(Space.s1),
                    Text(subtitle,
                        style: AppText.caption.copyWith(color: c.textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
