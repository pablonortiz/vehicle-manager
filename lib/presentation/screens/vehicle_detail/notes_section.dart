part of '../vehicle_detail_screen.dart';

// Sección de notas
class _NotesSection extends ConsumerStatefulWidget {
  final List<VehicleNote> notes;
  final String vehicleId;

  const _NotesSection({
    required this.notes,
    required this.vehicleId,
  });

  @override
  ConsumerState<_NotesSection> createState() => _NotesSectionState();
}

class _NotesSectionState extends ConsumerState<_NotesSection> {
  // Borrado diferido: ocultas mientras corre el SnackBar de "Deshacer".
  final Set<String> _pendingDeleteIds = {};

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final notes = widget.notes
        .where((n) => !_pendingDeleteIds.contains(n.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionTitle(title: 'Notas'),
            IconButton(
              onPressed: () => _showNoteDialog(null),
              icon: const Icon(Icons.add, color: AppTheme.accentPrimary),
              tooltip: 'Agregar nota',
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (notes.isEmpty)
          EmptyState(
            icon: Icons.note_outlined,
            title: 'Sin notas',
            actionLabel: 'Agregar nota',
            onAction: () => _showNoteDialog(null),
          )
        else
          ...notes.map((n) => _NoteCard(
            note: n,
            dateFormat: dateFormat,
            onTap: () => _showNoteDialog(n),
            onDelete: () => _deleteNote(n),
          )),
      ],
    );
  }

  void _showNoteDialog(VehicleNote? note) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _NoteFormSheet(
        vehicleId: widget.vehicleId,
        note: note,
        onSaved: (message) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
          }
        },
      ),
    );
  }

  Future<void> _deleteNote(VehicleNote note) async {
    if (!await confirmDelete(context,
        title: 'Eliminar nota',
        message: '¿Eliminar esta nota y sus fotos?')) {
      return;
    }
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final noteRepo = ref.read(noteRepositoryProvider);
    setState(() => _pendingDeleteIds.add(note.id!));

    final controller = messenger.showSnackBar(SnackBar(
      content: const Text('Nota eliminada'),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(label: 'Deshacer', onPressed: () {}),
    ));
    final reason = await controller.closed;

    if (reason == SnackBarClosedReason.action) {
      if (mounted) setState(() => _pendingDeleteIds.remove(note.id));
      return;
    }
    try {
      await noteRepo.deleteNote(note.id!);
    } finally {
      if (mounted) setState(() => _pendingDeleteIds.remove(note.id));
    }
  }
}

// Contenido del modal de alta/edición de nota.
// StatefulWidget dedicado para que el TextEditingController se libere en dispose.
class _NoteFormSheet extends ConsumerStatefulWidget {
  final String vehicleId;
  final VehicleNote? note;
  final void Function(String message) onSaved;

  const _NoteFormSheet({
    required this.vehicleId,
    required this.note,
    required this.onSaved,
  });

  @override
  ConsumerState<_NoteFormSheet> createState() => _NoteFormSheetState();
}

class _NoteFormSheetState extends ConsumerState<_NoteFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _detailController;
  late List<NotePhoto> _existingPhotos;
  final List<XFile> _pendingPhotos = [];
  final List<PlatformFile> _pendingFiles = [];
  bool _isSaving = false;
  bool _isSelectingPhotos = false;
  bool _hasChanges = false;

  bool get _isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    _detailController = TextEditingController(text: widget.note?.detail ?? '');
    _existingPhotos = List.from(widget.note?.photos ?? []);
    _detailController.addListener(_markDirty);
  }

  void _markDirty() {
    if (!_hasChanges) _hasChanges = true;
  }

  Future<void> _attemptClose() async {
    final dirty =
        _hasChanges || _pendingPhotos.isNotEmpty || _pendingFiles.isNotEmpty;
    if (dirty) {
      final discard = await confirmDiscard(context);
      if (!discard) return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEditing ? 'Editar Nota' : 'Nueva Nota',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    onPressed: _isSaving ? null : _attemptClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _detailController,
                  maxLines: 4,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(
                    labelText: 'Detalle *',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Completá el detalle' : null,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Fotos',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  _isSelectingPhotos
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton.icon(
                          onPressed: _isSaving ? null : _pickPhotos,
                          icon: const Icon(Icons.add_photo_alternate, size: 18),
                          label: const Text('Agregar'),
                        ),
                ],
              ),
              // Fotos existentes (solo en edición)
              if (_existingPhotos.isNotEmpty)
                _AttachmentStrip(
                  title: 'Archivos guardados:',
                  titleColor: AppTheme.textSecondary,
                  itemCount: _existingPhotos.length,
                  onRemove: _isSaving
                      ? null
                      : (index) async {
                          final photo = _existingPhotos[index];
                          if (!await confirmDelete(context,
                              title: 'Eliminar foto',
                              message: '¿Eliminar esta foto de la nota? No se puede deshacer.')) {
                            return;
                          }
                          if (!mounted) return;
                          final noteRepo = ref.read(noteRepositoryProvider);
                          await noteRepo.deletePhoto(photo.id!);
                          if (!mounted) return;
                          setState(() {
                            _existingPhotos.remove(photo);
                          });
                          ref.invalidate(notesByVehicleProvider(widget.vehicleId));
                        },
                  thumbnailBuilder: (index) {
                    final photo = _existingPhotos[index];
                    return GestureDetector(
                      onTap: () {
                        if (photo.isPdf) {
                          _showPdfPreview(context, photo.cloudinaryUrl, photo.fileName);
                        } else {
                          _showFullScreenImage(context, photo.cloudinaryUrl);
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 80,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: photo.isPdf
                              ? _buildPdfThumbnailSmall(photo.fileName)
                              : CachedNetworkImage(
                                  imageUrl: photo.cloudinaryUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (_, _) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                ),
                        ),
                      ),
                    );
                  },
                ),
              // Fotos pendientes de subir
              if (_pendingPhotos.isNotEmpty)
                _AttachmentStrip(
                  title: 'Pendientes de subir:',
                  titleColor: AppTheme.warning,
                  itemCount: _pendingPhotos.length,
                  onRemove: _isSaving
                      ? null
                      : (index) {
                          setState(() {
                            _pendingPhotos.removeAt(index);
                          });
                        },
                  thumbnailBuilder: (index) {
                    final photo = _pendingPhotos[index];
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.warning),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(photo.path),
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              // Archivos pendientes (PDFs/imágenes del file picker)
              if (_pendingFiles.isNotEmpty)
                _AttachmentStrip(
                  title: 'Archivos pendientes:',
                  titleColor: AppTheme.warning,
                  itemCount: _pendingFiles.length,
                  onRemove: _isSaving
                      ? null
                      : (index) {
                          setState(() {
                            _pendingFiles.removeAt(index);
                          });
                        },
                  thumbnailBuilder: (index) {
                    final file = _pendingFiles[index];
                    final isFilePdf = file.extension?.toLowerCase() == 'pdf';
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.warning),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: isFilePdf
                            ? _buildPdfThumbnailSmall(file.name)
                            : Image.file(File(file.path!), fit: BoxFit.cover),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                            SizedBox(width: 12),
                            Text('Guardando...'),
                          ],
                        )
                      : Text(_isEditing ? 'Guardar' : 'Agregar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickPhotos() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galería (múltiples)'),
              onTap: () => Navigator.pop(sheetCtx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('Archivo (PDF/Imagen)'),
              onTap: () => Navigator.pop(sheetCtx, 'file'),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    setState(() => _isSelectingPhotos = true);
    try {
      if (source == 'gallery') {
        final picker = ImagePicker();
        final images = await picker.pickMultiImage(imageQuality: 80);
        if (images.isNotEmpty) {
          setState(() {
            _pendingPhotos.addAll(images);
          });
        }
      } else if (source == 'file') {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
          allowMultiple: true,
        );
        if (result != null && result.files.isNotEmpty) {
          setState(() {
            _pendingFiles.addAll(result.files.where((f) => f.path != null));
          });
        }
      }
    } finally {
      if (mounted) setState(() => _isSelectingPhotos = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    try {
      final noteRepo = ref.read(noteRepositoryProvider);
      String noteId;

      if (_isEditing) {
        await noteRepo.updateNote(
          widget.note!.copyWith(detail: _detailController.text),
        );
        noteId = widget.note!.id!;
      } else {
        noteId = await noteRepo.insertNote(VehicleNote(
          vehicleId: widget.vehicleId,
          detail: _detailController.text,
        ));
      }

      // Subir fotos pendientes
      if (_pendingPhotos.isNotEmpty) {
        final cloudinary = CloudinaryService.instance;
        for (final photo in _pendingPhotos) {
          final result = await cloudinary.uploadFile(File(photo.path));
          if (result != null) {
            await noteRepo.insertPhoto(NotePhoto(
              noteId: noteId,
              cloudinaryUrl: result.url,
              cloudinaryPublicId: result.publicId,
            ));
          }
        }
      }

      // Subir archivos pendientes (PDF/imágenes del file picker)
      if (_pendingFiles.isNotEmpty) {
        final cloudinary = CloudinaryService.instance;
        for (final file in _pendingFiles) {
          if (file.path == null) continue;
          final isPdf = file.extension?.toLowerCase() == 'pdf';
          final result = await cloudinary.uploadFile(
            File(file.path!),
            isPdf: isPdf,
            fileName: file.name,
          );
          if (result != null) {
            await noteRepo.insertPhoto(NotePhoto(
              noteId: noteId,
              cloudinaryUrl: result.url,
              cloudinaryPublicId: result.publicId,
              isPdf: result.isPdf,
              fileName: result.fileName,
            ));
          }
        }
      }

      ref.invalidate(notesByVehicleProvider(widget.vehicleId));
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved(_isEditing ? 'Nota actualizada' : 'Nota agregada');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No se pudo guardar la nota'),
              backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _NoteCard extends StatelessWidget {
  final VehicleNote note;
  final DateFormat dateFormat;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NoteCard({
    required this.note,
    required this.dateFormat,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.note, color: AppTheme.warning, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateFormat.format(note.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      if (note.photos.isNotEmpty)
                        Text(
                          '${note.photos.length} adjunto(s)',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.accentPrimary,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline,
                      color: AppTheme.error, size: 20),
                  tooltip: 'Eliminar nota',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              note.detail,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (note.photos.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: note.photos.length,
                  itemBuilder: (context, index) {
                    final photo = note.photos[index];
                    return GestureDetector(
                      onTap: () {
                        if (photo.isPdf) {
                          _showPdfPreview(context, photo.cloudinaryUrl, photo.fileName);
                        } else {
                          _showFullScreenImage(context, photo.cloudinaryUrl);
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 60,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: photo.isPdf
                              ? _buildPdfThumbnailSmall(photo.fileName)
                              : CachedNetworkImage(
                                  imageUrl: photo.cloudinaryUrl,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
      ),
    );
  }
}

// Tira horizontal de thumbnails de adjuntos con botón de borrado opcional.
// Comparte el esqueleto de las tres listas del formulario de nota (guardados /
// pendientes / archivos); el contenido del thumbnail y la acción de borrado se
// pasan por callback. onRemove == null oculta el botón (caso _isSaving).
class _AttachmentStrip extends StatelessWidget {
  final String title;
  final Color titleColor;
  final int itemCount;
  final Widget Function(int index) thumbnailBuilder;
  final void Function(int index)? onRemove;

  const _AttachmentStrip({
    required this.title,
    required this.titleColor,
    required this.itemCount,
    required this.thumbnailBuilder,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(title, style: TextStyle(fontSize: 12, color: titleColor)),
        const SizedBox(height: 4),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: itemCount,
            itemBuilder: (ctx, index) {
              return Stack(
                children: [
                  thumbnailBuilder(index),
                  if (onRemove != null)
                    Positioned(
                      top: 2,
                      right: 10,
                      child: GestureDetector(
                        onTap: () => onRemove!(index),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: AppTheme.error,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
