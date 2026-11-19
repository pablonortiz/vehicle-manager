part of '../vehicle_detail_screen.dart';

// Sección de fotos
class _PhotosSection extends ConsumerStatefulWidget {
  final List<VehiclePhoto> photos;
  final String vehicleId;

  const _PhotosSection({
    required this.photos,
    required this.vehicleId,
  });

  @override
  ConsumerState<_PhotosSection> createState() => _PhotosSectionState();
}

class _PhotosSectionState extends ConsumerState<_PhotosSection> {
  bool _isUploading = false;
  bool _isProcessing = false;
  int _uploadProgress = 0;
  int _uploadTotal = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionTitle(title: 'Fotos'),
            _isUploading
                ? Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$_uploadProgress/$_uploadTotal',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : IconButton(
                    onPressed: _addPhoto,
                    icon: const Icon(Icons.add_a_photo, color: AppTheme.accentPrimary),
                    tooltip: 'Agregar foto',
                  ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.photos.isEmpty && !_isUploading)
          EmptyState(
            icon: Icons.photo_library_outlined,
            title: 'Sin fotos',
            actionLabel: 'Agregar foto',
            onAction: _addPhoto,
          )
        else
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.photos.length + (_isUploading ? 1 : 0),
              itemBuilder: (context, index) {
                // Mostrar placeholder de carga al final
                if (_isUploading && index == widget.photos.length) {
                  return Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 120,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final photo = widget.photos[index];
                return GestureDetector(
                  onTap: () => _viewPhoto(photo),
                  onLongPress: () => _showPhotoOptions(photo),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: photo.isPrimary
                          ? Border.all(color: AppTheme.accentPrimary, width: 2)
                          : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (photo.isPdf)
                            _buildPdfThumbnail(photo.fileName)
                          else
                            CachedNetworkImage(
                              imageUrl: photo.cloudinaryUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              errorWidget: (_, _, _) => const Icon(Icons.error),
                            ),
                          if (photo.isPrimary)
                            Positioned(
                              top: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentPrimary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Principal',
                                  style: TextStyle(fontSize: 10, color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Cámara'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galería (múltiples)'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('Archivo (PDF/Imagen)'),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _uploadTotal = 1;
    });

    try {
      final cloudinary = CloudinaryService.instance;
      final photoRepo = ref.read(photoRepositoryProvider);

      final results = await cloudinary.pickAndUpload(source);
      if (!mounted) return;
      setState(() => _uploadTotal = results.length);

      for (int i = 0; i < results.length; i++) {
        final result = results[i];
        await photoRepo.insertPhoto(VehiclePhoto(
          vehicleId: widget.vehicleId,
          cloudinaryUrl: result.url,
          cloudinaryPublicId: result.publicId,
          isPdf: result.isPdf,
          fileName: result.fileName,
        ));
        if (!mounted) return;
        setState(() => _uploadProgress = i + 1);
      }

      ref.invalidate(photosByVehicleProvider(widget.vehicleId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No se pudo subir la foto'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _viewPhoto(VehiclePhoto photo) {
    if (photo.isPdf) {
      _showPdfPreview(context, photo.cloudinaryUrl, photo.fileName);
    } else {
      _showFullScreenImage(context, photo.cloudinaryUrl);
    }
  }

  void _showPhotoOptions(VehiclePhoto photo) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!photo.isPrimary)
              ListTile(
                leading: _isProcessing
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.star),
                title: const Text('Establecer como principal'),
                onTap: _isProcessing ? null : () async {
                  Navigator.pop(ctx);
                  setState(() => _isProcessing = true);
                  try {
                    final photoRepo = ref.read(photoRepositoryProvider);
                    await photoRepo.setPrimaryPhoto(photo.id!, widget.vehicleId);
                    ref.invalidate(photosByVehicleProvider(widget.vehicleId));
                  } finally {
                    if (mounted) setState(() => _isProcessing = false);
                  }
                },
              ),
            ListTile(
              leading: _isProcessing
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.delete, color: AppTheme.error),
              title: const Text('Eliminar', style: TextStyle(color: AppTheme.error)),
              onTap: _isProcessing ? null : () async {
                Navigator.pop(ctx);
                if (!await confirmDelete(context,
                    title: 'Eliminar foto',
                    message: '¿Eliminar esta foto? No se puede deshacer.')) {
                  return;
                }
                if (!mounted) return;
                setState(() => _isProcessing = true);
                try {
                  final photoRepo = ref.read(photoRepositoryProvider);
                  await photoRepo.deletePhoto(photo.id!);
                  ref.invalidate(photosByVehicleProvider(widget.vehicleId));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Foto eliminada')),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isProcessing = false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
