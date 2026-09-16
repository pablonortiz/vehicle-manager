import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../core/theme/app_theme.dart';

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
  required String errorPrefix,
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

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  } catch (e) {
    if (dialogOpen && context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$errorPrefix: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }
}

void _showProgressDialog(BuildContext context, String title, String subtitle) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surface,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    ),
  );
}
