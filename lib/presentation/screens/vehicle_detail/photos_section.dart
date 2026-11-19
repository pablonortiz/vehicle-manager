part of '../vehicle_detail_screen.dart';

/// Fotos del vehículo: tira horizontal; tocar abre el visor con "Establecer
/// como principal" y "Eliminar" a la vista (el long-press queda de atajo).
class _PhotosSection extends ConsumerStatefulWidget {
  final List<VehiclePhoto> photos;
  final String vehicleId;

  const _PhotosSection({required this.photos, required this.vehicleId});

  @override
  ConsumerState<_PhotosSection> createState() => _PhotosSectionState();
}

class _PhotosSectionState extends ConsumerState<_PhotosSection> {
  bool _isUploading = false;
  int _uploadProgress = 0;
  int _uploadTotal = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Fotos',
          count: widget.photos.isEmpty ? null : widget.photos.length,
          actionLabel: 'Agregar',
          actionIcon: Icons.add_a_photo_rounded,
          onAction: _isUploading ? null : _addPhoto,
        ),
        const Gap(Space.s2),
        if (_isUploading) ...[
          const LinearProgressIndicator(),
          const Gap(Space.s1),
          Text(
            'Subiendo $_uploadProgress de $_uploadTotal…',
            style: AppText.caption.copyWith(color: c.textMuted),
          ),
          const Gap(Space.s2),
        ],
        if (widget.photos.isEmpty && !_isUploading)
          const _EmptyLine('Todavía no hay fotos.')
        else
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.photos.length,
              separatorBuilder: (_, _) => const Gap(Space.s3),
              itemBuilder: (context, index) {
                final photo = widget.photos[index];
                return _Thumbnail(
                  url: photo.cloudinaryUrl,
                  isPdf: photo.isPdf,
                  size: 104,
                  highlighted: photo.isPrimary,
                  semanticLabel: photo.isPrimary
                      ? 'Foto principal ${index + 1}'
                      : 'Foto ${index + 1}',
                  badge: photo.isPrimary
                      ? const AppTag('Principal', tone: Tone.info)
                      : null,
                  onTap: () => _viewPhoto(photo),
                  onLongPress: () => _showPhotoOptions(photo),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _addPhoto() async {
    final source = await _pickUploadSource(context, title: 'Agregar foto');
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
        AppSnack.error(context, 'No se pudo subir la foto. Revisá la conexión.');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  List<_ViewerAction> _actionsFor(VehiclePhoto photo) => [
        if (!photo.isPrimary)
          _ViewerAction(
            label: 'Establecer como principal',
            icon: Icons.star_rounded,
            onSelected: () => _setPrimary(photo),
          ),
        _ViewerAction(
          label: 'Eliminar',
          icon: Icons.delete_rounded,
          destructive: true,
          onSelected: () => _deletePhoto(photo),
        ),
      ];

  void _viewPhoto(VehiclePhoto photo) {
    _openAttachment(
      context,
      url: photo.cloudinaryUrl,
      isPdf: photo.isPdf,
      fileName: photo.fileName,
      actions: _actionsFor(photo),
    );
  }

  /// Atajo de long-press: las mismas acciones que en el visor.
  Future<void> _showPhotoOptions(VehiclePhoto photo) async {
    final actions = _actionsFor(photo);
    final chosen = await showAppOptionsSheet<_ViewerAction>(
      context,
      title: 'Foto',
      options: [
        for (final action in actions)
          AppSheetOption(
            value: action,
            icon: action.icon,
            label: action.label,
            tone: action.destructive ? Tone.danger : Tone.info,
          ),
      ],
    );
    chosen?.onSelected();
  }

  Future<void> _setPrimary(VehiclePhoto photo) async {
    try {
      await ref
          .read(photoRepositoryProvider)
          .setPrimaryPhoto(photo.id!, widget.vehicleId);
      ref.invalidate(photosByVehicleProvider(widget.vehicleId));
    } catch (_) {
      if (mounted) AppSnack.error(context, 'No se pudo cambiar la foto principal');
    }
  }

  /// Irreversible: la foto se borra también de la nube.
  Future<void> _deletePhoto(VehiclePhoto photo) async {
    if (!await confirmDestructive(
      context,
      title: '¿Eliminar esta foto?',
      message: 'Se borra del vehículo y de la nube. No se puede deshacer.',
    )) {
      return;
    }
    if (!mounted) return;
    try {
      await ref.read(photoRepositoryProvider).deletePhoto(photo.id!);
      ref.invalidate(photosByVehicleProvider(widget.vehicleId));
      if (mounted) AppSnack.success(context, 'Foto eliminada');
    } catch (_) {
      if (mounted) AppSnack.error(context, 'No se pudo eliminar la foto');
    }
  }
}
