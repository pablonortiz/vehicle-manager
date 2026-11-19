part of '../vehicle_detail_screen.dart';

/// Papeles del vehículo (cédulas, título y VTV): una lista agrupada con una
/// fila por tipo, en vez de una card grande por tipo aunque esté vacío.
class _DocumentPhotosSection extends ConsumerStatefulWidget {
  final List<DocumentPhoto> photos;
  final String vehicleId;

  const _DocumentPhotosSection({required this.photos, required this.vehicleId});

  @override
  ConsumerState<_DocumentPhotosSection> createState() =>
      _DocumentPhotosSectionState();
}

class _DocumentPhotosSectionState
    extends ConsumerState<_DocumentPhotosSection> {
  DocumentType? _uploadingType;

  @override
  Widget build(BuildContext context) {
    // Agrupar por tipo en una sola pasada.
    final photosByType = <DocumentType, List<DocumentPhoto>>{};
    for (final photo in widget.photos) {
      (photosByType[photo.documentType] ??= []).add(photo);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Papeles'),
        const Gap(Space.s2),
        AppCard.list(
          children: [
            for (final type in DocumentType.values)
              _DocumentRow(
                type: type,
                photos: photosByType[type] ?? const [],
                isUploading: _uploadingType == type,
                onAdd: _uploadingType == null ? () => _addPhoto(type) : null,
                onOpen: _viewPhoto,
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _addPhoto(DocumentType type) async {
    final source = await _pickUploadSource(context, title: 'Agregar ${type.label}');
    if (source == null) return;

    setState(() => _uploadingType = type);
    try {
      final cloudinary = CloudinaryService.instance;
      final docPhotoRepo = ref.read(documentPhotoRepositoryProvider);

      final results = await cloudinary.pickAndUpload(source);
      for (final result in results) {
        await docPhotoRepo.insertPhoto(DocumentPhoto(
          vehicleId: widget.vehicleId,
          documentType: type,
          cloudinaryUrl: result.url,
          cloudinaryPublicId: result.publicId,
          isPdf: result.isPdf,
          fileName: result.fileName,
        ));
      }
      ref.invalidate(documentPhotosByVehicleProvider(widget.vehicleId));
    } catch (_) {
      if (mounted) {
        AppSnack.error(context, 'No se pudo subir el papel. Revisá la conexión.');
      }
    } finally {
      if (mounted) setState(() => _uploadingType = null);
    }
  }

  void _viewPhoto(DocumentPhoto photo) {
    _openAttachment(
      context,
      url: photo.cloudinaryUrl,
      isPdf: photo.isPdf,
      fileName: photo.fileName,
      actions: [
        _ViewerAction(
          label: 'Eliminar',
          icon: Icons.delete_rounded,
          destructive: true,
          onSelected: () => _deletePhoto(photo),
        ),
      ],
    );
  }

  /// Irreversible: el archivo se borra también de la nube.
  Future<void> _deletePhoto(DocumentPhoto photo) async {
    if (!await confirmDestructive(
      context,
      title: '¿Eliminar este papel?',
      message: 'Se borra del vehículo y de la nube. No se puede deshacer.',
    )) {
      return;
    }
    if (!mounted) return;
    try {
      await ref.read(documentPhotoRepositoryProvider).deletePhoto(photo.id!);
      ref.invalidate(documentPhotosByVehicleProvider(widget.vehicleId));
      if (mounted) AppSnack.success(context, 'Papel eliminado');
    } catch (_) {
      if (mounted) AppSnack.error(context, 'No se pudo eliminar el papel');
    }
  }
}

class _DocumentRow extends StatelessWidget {
  final DocumentType type;
  final List<DocumentPhoto> photos;
  final bool isUploading;
  final VoidCallback? onAdd;
  final ValueChanged<DocumentPhoto> onOpen;

  const _DocumentRow({
    required this.type,
    required this.photos,
    required this.isUploading,
    required this.onAdd,
    required this.onOpen,
  });

  IconData get _icon => switch (type) {
        DocumentType.titulo => Icons.description_rounded,
        DocumentType.vtv => Icons.verified_rounded,
        _ => Icons.badge_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(
          left: Space.s4, right: Space.s1, top: Space.s1, bottom: Space.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icon, size: Sizes.iconMd, color: c.textMuted),
              const Gap(Space.s3),
              Expanded(
                child: Text(type.label, style: AppText.label.copyWith(color: c.text)),
              ),
              if (photos.isNotEmpty) CountBadge(photos.length),
              isUploading
                  ? const Padding(
                      padding: EdgeInsets.all(Space.s3),
                      child: SizedBox.square(
                        dimension: Sizes.iconLg,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Agregar ${type.label}',
                      onPressed: onAdd,
                      icon: const Icon(Icons.add_a_photo_rounded),
                    ),
            ],
          ),
          Padding(
            // Alineado con el nombre, no con el ícono.
            padding: const EdgeInsets.only(left: Sizes.iconMd + Space.s3),
            child: photos.isEmpty
                ? Text('Sin cargar',
                    style: AppText.caption.copyWith(color: c.textMuted))
                : SizedBox(
                    height: 64,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: photos.length,
                      separatorBuilder: (_, _) => const Gap(Space.s2),
                      itemBuilder: (context, index) => _Thumbnail(
                        url: photos[index].cloudinaryUrl,
                        isPdf: photos[index].isPdf,
                        size: 64,
                        semanticLabel: '${type.label}, archivo ${index + 1}',
                        onTap: () => onOpen(photos[index]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
