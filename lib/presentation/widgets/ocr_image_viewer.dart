import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_tone.dart';
import '../../core/theme/app_typography.dart';
import '../../data/services/pdf_service.dart';
import 'app_sheet.dart';
import 'empty_state.dart';
import 'ocr_photo_types.dart';

/// Foto del ticket o del surtidor a pantalla completa, con el texto que leyó
/// el OCR a mano para ver por qué no encontró un valor.
class OcrFullScreenViewer extends StatelessWidget {
  final String imageUrl;
  final String? ocrText;
  final OcrPhotoType type;

  const OcrFullScreenViewer({
    super.key,
    required this.imageUrl,
    this.ocrText,
    required this.type,
  });

  bool get _isReceipt => type == OcrPhotoType.receipt;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasText = ocrText?.isNotEmpty ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isReceipt ? 'Ticket' : 'Surtidor'),
        actions: [
          if (hasText)
            IconButton(
              tooltip: 'Ver texto leído',
              onPressed: () => _showOcrText(context),
              icon: const Icon(Icons.text_snippet_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, _) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (_, _, _) => const EmptyState(
                      icon: Icons.broken_image_rounded,
                      title: 'No se pudo cargar la foto',
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Space.s4),
              child: Text(
                _isReceipt
                    ? 'Pellizcá para hacer zoom. El total suele estar al pie del ticket.'
                    : 'Pellizcá para hacer zoom. Los litros y el importe están en el visor.',
                textAlign: TextAlign.center,
                style: AppText.caption.copyWith(color: c.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOcrText(BuildContext context) {
    showAppSheet<void>(
      context,
      builder: (sheetContext) {
        final c = sheetContext.colors;
        return AppSheet(
          title: 'Texto leído',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectableText(
                ocrText ?? '',
                style: AppText.body.copyWith(
                  color: c.text,
                  fontFamily: AppFonts.mono,
                ),
              ),
              const Gap(Space.s4),
              Text(
                _isReceipt
                    ? 'Buscá palabras como "Total" o "Importe", o valores con "\$".'
                    : 'Buscá los litros (por ejemplo "28,605") y el importe del visor.',
                style: AppText.caption.copyWith(color: c.textMuted),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Un PDF adjunto (factura) a pantalla completa.
class OcrPdfPreviewPage extends StatelessWidget {
  final String url;
  final String? fileName;

  const OcrPdfPreviewPage({super.key, required this.url, this.fileName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(fileName ?? 'PDF')),
      body: PdfPreview(
        build: (format) async {
          final bytes = await PdfService.downloadPdfBytes(url);
          if (bytes == null) throw Exception('No se pudo descargar el PDF');
          return bytes;
        },
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName: fileName,
        scrollViewDecoration: BoxDecoration(color: context.colors.bg),
        onError: (_, _) => const Center(
          child: EmptyState(
            icon: Icons.picture_as_pdf_rounded,
            title: 'No se pudo abrir el PDF',
            message: 'Revisá la conexión y probá de nuevo.',
            tone: Tone.danger,
          ),
        ),
      ),
    );
  }
}
