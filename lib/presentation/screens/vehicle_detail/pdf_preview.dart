part of '../vehicle_detail_screen.dart';

/// Acción visible en el visor de una foto: lo que antes era solo long-press.
class _ViewerAction {
  final String label;
  final IconData icon;
  final bool destructive;
  final VoidCallback onSelected;

  const _ViewerAction({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.destructive = false,
  });
}

/// Abre una foto a pantalla completa o un PDF en el visor, con sus acciones.
void _openAttachment(
  BuildContext context, {
  required String url,
  required bool isPdf,
  String? fileName,
  List<_ViewerAction> actions = const [],
}) {
  if (isPdf) {
    _showPdfPreview(context, url, fileName, actions: actions);
  } else {
    _showFullScreenImage(context, url, actions: actions);
  }
}

/// Origen de una foto o archivo nuevo: cámara, galería o archivo.
Future<String?> _pickUploadSource(BuildContext context, {required String title}) {
  return showAppOptionsSheet<String>(
    context,
    title: title,
    options: const [
      AppSheetOption(
        value: 'camera',
        icon: Icons.photo_camera_rounded,
        label: 'Cámara',
      ),
      AppSheetOption(
        value: 'gallery',
        icon: Icons.photo_library_rounded,
        label: 'Galería',
        description: 'Podés elegir varias',
      ),
      AppSheetOption(
        value: 'file',
        icon: Icons.attach_file_rounded,
        label: 'Archivo',
        description: 'PDF o imagen',
      ),
    ],
  );
}

void _showFullScreenImage(
  BuildContext context,
  String imageUrl, {
  List<_ViewerAction> actions = const [],
}) {
  showDialog<void>(
    context: context,
    barrierLabel: 'Cerrar',
    builder: (dialogContext) {
      final c = dialogContext.colors;
      return Dialog.fullscreen(
        backgroundColor: c.bg,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, _) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (_, _, _) => const Center(
                      child: EmptyState(
                        icon: Icons.broken_image_rounded,
                        title: 'No se pudo cargar la foto',
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(Space.s2),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    const Spacer(),
                    if (actions.isNotEmpty)
                      _ViewerMenu(
                        actions: actions,
                        filled: true,
                        onBeforeAction: () => Navigator.pop(dialogContext),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _ViewerMenu extends StatelessWidget {
  final List<_ViewerAction> actions;
  final VoidCallback onBeforeAction;

  /// Con fondo, para que se lea encima de la foto.
  final bool filled;

  const _ViewerMenu({
    required this.actions,
    required this.onBeforeAction,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PopupMenuButton<_ViewerAction>(
      tooltip: 'Más opciones',
      onSelected: (action) {
        onBeforeAction();
        action.onSelected();
      },
      itemBuilder: (_) => [
        for (final action in actions)
          PopupMenuItem(
            value: action,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(action.icon,
                  color: action.destructive ? c.danger : null),
              title: Text(
                action.label,
                style: action.destructive
                    ? AppText.body.copyWith(color: c.danger)
                    : null,
              ),
            ),
          ),
      ],
      icon: const Icon(Icons.more_vert_rounded),
      style: filled
          ? IconButton.styleFrom(backgroundColor: c.surfaceRaised)
          : null,
    );
  }
}

/// Visor de PDF a pantalla completa (PdfPreview del paquete printing).
void _showPdfPreview(
  BuildContext context,
  String url,
  String? fileName, {
  List<_ViewerAction> actions = const [],
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) =>
          _PdfPreviewPage(url: url, fileName: fileName, actions: actions),
    ),
  );
}

class _PdfPreviewPage extends StatelessWidget {
  final String url;
  final String? fileName;
  final List<_ViewerAction> actions;

  const _PdfPreviewPage({
    required this.url,
    this.fileName,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(fileName ?? 'PDF'),
        actions: [
          if (actions.isNotEmpty)
            _ViewerMenu(
              actions: actions,
              onBeforeAction: () => Navigator.pop(context),
            ),
          const Gap(Space.s1),
        ],
      ),
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
