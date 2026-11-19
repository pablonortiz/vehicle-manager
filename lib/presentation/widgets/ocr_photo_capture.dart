import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_tone.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/thousands_formatter.dart';
import '../../data/services/ocr_service.dart';
import '../../data/services/cloudinary_service.dart';
import 'app_sheet.dart';
import 'app_snack.dart';
import 'app_tag.dart';
import 'ocr_photo_types.dart';
import 'ocr_image_viewer.dart';

// Re-export para que los consumidores (p.ej. fuel_charge_form_sheet) sigan
// importando solo ocr_photo_capture.dart.
export 'ocr_photo_types.dart';

/// Foto de un ticket o de un surtidor: al cargarla se lee con OCR y se sube.
/// Tocar la foto la abre; "Quitar foto" la saca.
class OcrPhotoCapture extends StatefulWidget {
  final OcrPhotoType type;
  final String? initialPhotoUrl;
  final bool initialIsPdf;
  final String? initialFileName;
  final ValueChanged<OcrPhotoResult> onPhotoResult;

  const OcrPhotoCapture({
    super.key,
    required this.type,
    this.initialPhotoUrl,
    this.initialIsPdf = false,
    this.initialFileName,
    required this.onPhotoResult,
  });

  @override
  State<OcrPhotoCapture> createState() => _OcrPhotoCaptureState();
}

class _OcrPhotoCaptureState extends State<OcrPhotoCapture> {
  String? _photoUrl;
  String? _ocrText;
  bool _isProcessing = false;
  bool _ocrDetected = false;
  bool _isPdf = false;
  String? _fileName;

  bool get _isReceipt => widget.type == OcrPhotoType.receipt;
  String get _label => _isReceipt ? 'Ticket' : 'Surtidor';
  String get _ofLabel => _isReceipt ? 'del ticket' : 'del surtidor';

  @override
  void initState() {
    super.initState();
    _photoUrl = widget.initialPhotoUrl;
    _isPdf = widget.initialIsPdf;
    _fileName = widget.initialFileName;
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 112,
      child: Material(
        color: c.surfaceRaised,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.mdAll,
          side: BorderSide(
            color: _ocrDetected ? c.success : c.border,
            width: _ocrDetected ? 2 : 1,
          ),
        ),
        child: _isProcessing
            ? const Center(child: CircularProgressIndicator())
            : _photoUrl != null
                ? _buildPhotoPreview(c)
                : _buildCaptureButton(c),
      ),
    );
  }

  Widget _buildCaptureButton(AppColors c) {
    return Semantics(
      button: true,
      label: 'Agregar foto $_ofLabel',
      excludeSemantics: true,
      onTap: _showPickerOptions,
      child: InkWell(
        onTap: _showPickerOptions,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isReceipt
                  ? Icons.receipt_long_rounded
                  : Icons.local_gas_station_rounded,
              color: c.accent,
              size: Sizes.iconLg,
            ),
            const Gap(Space.s1),
            Text(_label, style: AppText.label.copyWith(color: c.text)),
            Text('Agregar foto', style: AppText.caption.copyWith(color: c.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoPreview(AppColors c) {
    final open = _isPdf ? _showPdfPreviewDialog : _showFullScreenImage;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_isPdf)
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.picture_as_pdf_rounded,
                  color: c.textMuted, size: Sizes.iconLg),
              const Gap(Space.s1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.s2),
                child: Text(
                  _fileName ?? 'PDF',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(color: c.textMuted),
                ),
              ),
            ],
          )
        else
          CachedNetworkImage(
            imageUrl: _photoUrl!,
            fit: BoxFit.cover,
            placeholder: (_, _) =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            errorWidget: (_, _, _) =>
                Icon(Icons.broken_image_rounded, color: c.textMuted),
          ),
        Semantics(
          button: true,
          label: 'Ver foto $_ofLabel',
          excludeSemantics: true,
          onTap: open,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(onTap: open),
          ),
        ),
        Positioned(
          top: Space.s1,
          right: Space.s1,
          child: IconButton.filledTonal(
            tooltip: 'Quitar foto',
            onPressed: _removePhoto,
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        if (_ocrDetected)
          const Positioned(
            left: Space.s2,
            bottom: Space.s2,
            child: AppTag('Leído', tone: Tone.success),
          ),
      ],
    );
  }

  void _showPdfPreviewDialog() {
    if (_photoUrl == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => OcrPdfPreviewPage(url: _photoUrl!, fileName: _fileName),
      ),
    );
  }

  void _showFullScreenImage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => OcrFullScreenViewer(
          imageUrl: _photoUrl!,
          ocrText: _ocrText,
          type: widget.type,
        ),
      ),
    );
  }

  Future<void> _showPickerOptions() async {
    final source = await showAppOptionsSheet<String>(
      context,
      title: 'Foto $_ofLabel',
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
        ),
        AppSheetOption(
          value: 'file',
          icon: Icons.attach_file_rounded,
          label: 'Archivo',
          description: 'PDF o imagen, sin lectura automática',
        ),
      ],
    );
    switch (source) {
      case 'camera':
        await _capturePhoto(ImageSource.camera);
      case 'gallery':
        await _capturePhoto(ImageSource.gallery);
      case 'file':
        await _pickFile();
    }
  }

  Future<void> _capturePhoto(ImageSource source) async {
    setState(() => _isProcessing = true);

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        _safeSetState(() => _isProcessing = false);
        return;
      }

      final file = File(pickedFile.path);

      FuelOcrResult ocrResult;
      CloudinaryUploadResult? uploadResult;
      try {
        // Perform OCR
        final ocrService = OcrService.instance;
        ocrResult = widget.type == OcrPhotoType.receipt
            ? await ocrService.extractFromReceipt(file)
            : await ocrService.extractFromPumpDisplay(file);

        // Upload to Cloudinary
        final cloudinary = CloudinaryService.instance;
        uploadResult = await cloudinary.uploadFile(file);
      } finally {
        // Clean up the temp file created by image_picker after uploading.
        try {
          await file.delete();
        } catch (_) {
          // File may already be gone; ignore.
        }
      }

      if (uploadResult != null) {
        final upload = uploadResult;
        _safeSetState(() {
          _photoUrl = upload.url;
          _ocrText = ocrResult.fullText;
          _ocrDetected = ocrResult.success;
          _isProcessing = false;
        });

        widget.onPhotoResult(OcrPhotoResult(
          cloudinaryUrl: upload.url,
          cloudinaryPublicId: upload.publicId,
          extractedLiters: ocrResult.liters,
          extractedPrice: ocrResult.price,
          ocrDetected: ocrResult.success,
          ocrText: ocrResult.fullText,
        ));

        if (mounted) _reportOcr(ocrResult);
      } else {
        _safeSetState(() => _isProcessing = false);
        if (mounted) {
          AppSnack.error(context, 'No se pudo subir la foto. Revisá la conexión.');
        }
      }
    } catch (_) {
      _safeSetState(() => _isProcessing = false);
      if (mounted) {
        AppSnack.error(context, 'No se pudo subir la foto. Revisá la conexión.');
      }
    }
  }

  /// Cuenta qué se leyó; si no se encontró el valor, cómo ver el texto leído.
  void _reportOcr(FuelOcrResult ocrResult) {
    if (ocrResult.success) {
      final detected = [
        if (ocrResult.liters != null) 'litros ${formatLitersAr(ocrResult.liters!)}',
        if (ocrResult.price != null)
          'precio \$ ${formatWithDots(ocrResult.price!.toStringAsFixed(0))}',
      ].join(' · ');
      AppSnack.success(context, 'Se leyó $detected');
    } else if (ocrResult.fullText?.isNotEmpty ?? false) {
      AppSnack.info(
          context, 'No se encontró el valor. Tocá la foto para ver lo que se leyó.');
    }
  }

  Future<void> _pickFile() async {
    setState(() => _isProcessing = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      );

      if (result == null || result.files.isEmpty || result.files.first.path == null) {
        _safeSetState(() => _isProcessing = false);
        return;
      }

      final file = result.files.first;
      final isPdf = file.extension?.toLowerCase() == 'pdf';
      final localFile = File(file.path!);

      CloudinaryUploadResult? uploadResult;
      try {
        final cloudinary = CloudinaryService.instance;
        uploadResult = await cloudinary.uploadFile(
          localFile,
          isPdf: isPdf,
          fileName: file.name,
        );
      } finally {
        // Clean up the temp file copied by file_picker after uploading.
        try {
          await localFile.delete();
        } catch (_) {
          // File may already be gone; ignore.
        }
      }

      if (uploadResult != null) {
        final upload = uploadResult;
        _safeSetState(() {
          _photoUrl = upload.url;
          _isPdf = upload.isPdf;
          _fileName = upload.fileName;
          _ocrText = null;
          _ocrDetected = false;
          _isProcessing = false;
        });

        widget.onPhotoResult(OcrPhotoResult(
          cloudinaryUrl: upload.url,
          cloudinaryPublicId: upload.publicId,
          isPdf: upload.isPdf,
          fileName: upload.fileName,
        ));
      } else {
        _safeSetState(() => _isProcessing = false);
        if (mounted) {
          AppSnack.error(context, 'No se pudo subir el archivo. Revisá la conexión.');
        }
      }
    } catch (_) {
      _safeSetState(() => _isProcessing = false);
      if (mounted) {
        AppSnack.error(context, 'No se pudo subir el archivo. Revisá la conexión.');
      }
    }
  }

  void _removePhoto() {
    setState(() {
      _photoUrl = null;
      _ocrText = null;
      _ocrDetected = false;
      _isPdf = false;
      _fileName = null;
    });

    widget.onPhotoResult(OcrPhotoResult());
  }
}

/// Full screen image viewer with OCR text display
