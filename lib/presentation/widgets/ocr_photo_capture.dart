import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/ocr_service.dart';
import '../../data/services/cloudinary_service.dart';

enum OcrPhotoType { receipt, display }

class OcrPhotoResult {
  final String? cloudinaryUrl;
  final String? cloudinaryPublicId;
  final double? extractedValue;
  final bool ocrDetected;
  final String? ocrText; // Full OCR text for debugging

  OcrPhotoResult({
    this.cloudinaryUrl,
    this.cloudinaryPublicId,
    this.extractedValue,
    this.ocrDetected = false,
    this.ocrText,
  });
}

class OcrPhotoCapture extends StatefulWidget {
  final OcrPhotoType type;
  final String? initialPhotoUrl;
  final double? initialValue;
  final bool showOcrIndicator;
  final ValueChanged<OcrPhotoResult> onPhotoResult;

  const OcrPhotoCapture({
    super.key,
    required this.type,
    this.initialPhotoUrl,
    this.initialValue,
    this.showOcrIndicator = false,
    required this.onPhotoResult,
  });

  @override
  State<OcrPhotoCapture> createState() => _OcrPhotoCaptureState();
}

class _OcrPhotoCaptureState extends State<OcrPhotoCapture> {
  String? _photoUrl;
  String? _publicId;
  String? _localFilePath; // Keep local file for potential re-OCR
  String? _ocrText; // Full OCR text
  bool _isProcessing = false;
  bool _ocrDetected = false;

  @override
  void initState() {
    super.initState();
    _photoUrl = widget.initialPhotoUrl;
    _ocrDetected = widget.showOcrIndicator;
  }

  @override
  Widget build(BuildContext context) {
    final isReceipt = widget.type == OcrPhotoType.receipt;
    final label = isReceipt ? 'Ticket' : 'Surtidor';
    final icon = isReceipt ? Icons.receipt_long : Icons.local_gas_station;

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _ocrDetected ? AppTheme.success : AppTheme.border,
          width: _ocrDetected ? 2 : 1,
        ),
      ),
      child: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : _photoUrl != null
              ? _buildPhotoPreview()
              : _buildCaptureButton(icon, label),
    );
  }

  Widget _buildCaptureButton(IconData icon, String label) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showPickerOptions,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.accentPrimary, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accentPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'OCR',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accentPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoPreview() {
    return Stack(
      children: [
        // Tappable image to view fullscreen
        GestureDetector(
          onTap: _showFullScreenImage,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: CachedNetworkImage(
              imageUrl: _photoUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              placeholder: (_, __) => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ),
        // Expand icon overlay
        Positioned(
          bottom: 4,
          right: 4,
          child: GestureDetector(
            onTap: _showFullScreenImage,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.zoom_in,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
        // Remove button
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: _removePhoto,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppTheme.error,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
        if (_ocrDetected)
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.success,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, size: 10, color: Colors.white),
                  SizedBox(width: 2),
                  Text(
                    'OCR',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _showFullScreenImage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenImageViewer(
          imageUrl: _photoUrl!,
          ocrText: _ocrText,
          type: widget.type,
        ),
      ),
    );
  }

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Cámara'),
              onTap: () {
                Navigator.pop(ctx);
                _capturePhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galería'),
              onTap: () {
                Navigator.pop(ctx);
                _capturePhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
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
        setState(() => _isProcessing = false);
        return;
      }

      final file = File(pickedFile.path);
      _localFilePath = pickedFile.path;

      // Perform OCR
      final ocrService = OcrService.instance;
      final ocrResult = widget.type == OcrPhotoType.receipt
          ? await ocrService.extractPrice(file)
          : await ocrService.extractLiters(file);

      // Upload to Cloudinary
      final cloudinary = CloudinaryService.instance;
      final uploadResult = await cloudinary.uploadFile(file);

      if (uploadResult != null) {
        setState(() {
          _photoUrl = uploadResult.url;
          _publicId = uploadResult.publicId;
          _ocrText = ocrResult.fullText;
          _ocrDetected = ocrResult.success;
          _isProcessing = false;
        });

        widget.onPhotoResult(OcrPhotoResult(
          cloudinaryUrl: uploadResult.url,
          cloudinaryPublicId: uploadResult.publicId,
          extractedValue: ocrResult.value,
          ocrDetected: ocrResult.success,
          ocrText: ocrResult.fullText,
        ));

        // Show snackbar with OCR result info
        if (mounted) {
          if (ocrResult.success) {
            final valueType = widget.type == OcrPhotoType.receipt ? 'precio' : 'litros';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('OCR detectó $valueType: ${ocrResult.rawText}'),
                backgroundColor: AppTheme.success,
                duration: const Duration(seconds: 2),
              ),
            );
          } else if (ocrResult.fullText != null && ocrResult.fullText!.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('OCR no encontró el valor. Toca la imagen para ver más detalles.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        setState(() => _isProcessing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al subir la foto')),
          );
        }
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _removePhoto() {
    setState(() {
      _photoUrl = null;
      _publicId = null;
      _localFilePath = null;
      _ocrText = null;
      _ocrDetected = false;
    });

    widget.onPhotoResult(OcrPhotoResult());
  }
}

/// Full screen image viewer with OCR text display
class _FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String? ocrText;
  final OcrPhotoType type;

  const _FullScreenImageViewer({
    required this.imageUrl,
    this.ocrText,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final isReceipt = type == OcrPhotoType.receipt;
    final title = isReceipt ? 'Ticket' : 'Surtidor';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
        actions: [
          if (ocrText != null && ocrText!.isNotEmpty)
            IconButton(
              onPressed: () => _showOcrText(context),
              icon: const Icon(Icons.text_snippet),
              tooltip: 'Ver texto OCR',
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.error,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            // Bottom hint
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.black.withOpacity(0.8),
              child: Text(
                isReceipt
                    ? 'Pellizca para zoom. Busca el precio total en el ticket.'
                    : 'Pellizca para zoom. Busca los litros en el display.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOcrText(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppTheme.border),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Texto detectado por OCR',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  ocrText ?? 'No se detectó texto',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppTheme.border),
                ),
              ),
              child: Text(
                type == OcrPhotoType.receipt
                    ? 'Busca palabras como "Total", "Importe" o valores con "\$"'
                    : 'Busca valores como "45.50 L" o "Litros: 45.50"',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
