part of '../vehicle_detail_screen.dart';

/// Notas del vehículo: tocar abre la edición, y eliminar (desde el sheet) es
/// reversible con "Deshacer", sin diálogo previo.
class _NotesSection extends ConsumerStatefulWidget {
  final List<VehicleNote> notes;
  final String vehicleId;

  const _NotesSection({required this.notes, required this.vehicleId});

  @override
  ConsumerState<_NotesSection> createState() => _NotesSectionState();
}

class _NotesSectionState extends ConsumerState<_NotesSection> {
  // Borrado diferido: ocultas mientras corre el snackbar de "Deshacer".
  final Set<String> _pendingDeleteIds = {};

  @override
  Widget build(BuildContext context) {
    final notes = widget.notes
        .where((note) => !_pendingDeleteIds.contains(note.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Notas',
          count: notes.isEmpty ? null : notes.length,
          actionLabel: 'Agregar',
          actionIcon: Icons.add_rounded,
          onAction: () => _openSheet(null),
        ),
        const Gap(Space.s2),
        if (notes.isEmpty)
          const _EmptyLine('Todavía no hay notas.')
        else
          AppCard.list(
            children: [
              for (final note in notes)
                _NoteRow(note: note, onTap: () => _openSheet(note)),
            ],
          ),
      ],
    );
  }

  Future<void> _openSheet(VehicleNote? note) async {
    final outcome = await showAppSheet<_SheetOutcome>(
      context,
      enableDrag: false,
      builder: (_) => _NoteFormSheet(vehicleId: widget.vehicleId, note: note),
    );
    if (!mounted) return;
    switch (outcome) {
      case _SheetOutcome.saved:
        AppSnack.success(context, 'Nota guardada');
      case _SheetOutcome.delete:
        await _deleteNote(note!);
      case null:
        break;
    }
  }

  Future<void> _deleteNote(VehicleNote note) async {
    final repo = ref.read(noteRepositoryProvider);
    setState(() => _pendingDeleteIds.add(note.id!));
    final commit = await AppSnack.undoableDelete(context, 'Nota eliminada');
    if (!commit) {
      if (mounted) setState(() => _pendingDeleteIds.remove(note.id));
      return;
    }
    try {
      await repo.deleteNote(note.id!);
    } finally {
      if (mounted) setState(() => _pendingDeleteIds.remove(note.id));
    }
  }
}

class _NoteRow extends StatelessWidget {
  final VehicleNote note;
  final VoidCallback onTap;

  const _NoteRow({required this.note, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Space.s4, vertical: Space.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppFormats.dateTime(note.createdAt),
              style: AppText.caption.copyWith(color: c.textMuted),
            ),
            const Gap(Space.s1),
            Text(
              note.detail,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: AppText.body.copyWith(color: c.text),
            ),
            if (note.photos.isNotEmpty) ...[
              const Gap(Space.s2),
              SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: note.photos.length,
                  separatorBuilder: (_, _) => const Gap(Space.s2),
                  itemBuilder: (context, index) {
                    final photo = note.photos[index];
                    return _Thumbnail(
                      url: photo.cloudinaryUrl,
                      isPdf: photo.isPdf,
                      size: 56,
                      semanticLabel: 'Adjunto ${index + 1} de la nota',
                      onTap: () => _openAttachment(
                        context,
                        url: photo.cloudinaryUrl,
                        isPdf: photo.isPdf,
                        fileName: photo.fileName,
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Alta y edición de una nota con sus fotos y archivos.
class _NoteFormSheet extends ConsumerStatefulWidget {
  final String vehicleId;
  final VehicleNote? note;

  const _NoteFormSheet({required this.vehicleId, required this.note});

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
  bool _isSelectingFiles = false;

  bool get _isEditing => widget.note != null;

  /// Comparado contra lo guardado: tocar el campo sin cambiarlo no cuenta.
  bool get _isDirty =>
      _detailController.text.trim() != (widget.note?.detail ?? '').trim() ||
      _pendingPhotos.isNotEmpty ||
      _pendingFiles.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _detailController = TextEditingController(text: widget.note?.detail ?? '');
    _existingPhotos = List.from(widget.note?.photos ?? []);
  }

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: _isEditing ? 'Editar nota' : 'Nueva nota',
      hasUnsavedChanges: _isDirty && !_isSaving,
      footer: SizedBox(
        width: double.infinity,
        height: Sizes.controlH,
        child: FilledButton(
          onPressed: _isSaving ? null : _save,
          child: Text(_isSaving ? 'Guardando…' : 'Guardar nota'),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: 'Nota',
              required: true,
              controller: _detailController,
              hint: 'Qué pasó o qué hay que tener en cuenta',
              maxLines: 6,
              minLines: 3,
              enabled: !_isSaving,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Escribí la nota'
                  : null,
            ),
            const Gap(Space.s4),
            _AttachmentsField(
              emptyHint: 'Fotos o archivos, en PDF o imagen.',
              isBusy: _isSaving || _isSelectingFiles,
              onAdd: _pickAttachments,
              attachments: [
                for (final (index, photo) in _existingPhotos.indexed)
                  _AttachmentChip(
                    label: photo.fileName ?? 'Foto ${index + 1}',
                    isPdf: photo.isPdf,
                    onOpen: () => _openAttachment(
                      context,
                      url: photo.cloudinaryUrl,
                      isPdf: photo.isPdf,
                      fileName: photo.fileName,
                    ),
                    onRemove: () => _deleteSavedPhoto(photo),
                  ),
                for (final photo in _pendingPhotos)
                  _AttachmentChip(
                    label: photo.name,
                    isPdf: false,
                    pending: true,
                    onRemove: () => setState(() => _pendingPhotos.remove(photo)),
                  ),
                for (final file in _pendingFiles)
                  _AttachmentChip(
                    label: file.name,
                    isPdf: file.extension?.toLowerCase() == 'pdf',
                    pending: true,
                    onRemove: () => setState(() => _pendingFiles.remove(file)),
                  ),
              ],
            ),
            if (_isEditing) ...[
              const Gap(Space.s4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  style: AppButtonStyles.dangerText(context),
                  onPressed: _isSaving
                      ? null
                      : () => Navigator.pop(context, _SheetOutcome.delete),
                  icon: const Icon(Icons.delete_rounded),
                  label: const Text('Eliminar nota'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickAttachments() async {
    final source = await showAppOptionsSheet<String>(
      context,
      title: 'Adjuntar',
      options: const [
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
    if (source == null || !mounted) return;
    setState(() => _isSelectingFiles = true);
    try {
      if (source == 'gallery') {
        final images = await ImagePicker().pickMultiImage(imageQuality: 80);
        if (images.isNotEmpty) setState(() => _pendingPhotos.addAll(images));
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
          allowMultiple: true,
        );
        if (result != null && result.files.isNotEmpty) {
          setState(() => _pendingFiles
              .addAll(result.files.where((file) => file.path != null)));
        }
      }
    } finally {
      if (mounted) setState(() => _isSelectingFiles = false);
    }
  }

  /// Irreversible: el archivo se borra también de la nube.
  Future<void> _deleteSavedPhoto(NotePhoto photo) async {
    if (!await confirmDestructive(
      context,
      title: '¿Eliminar este adjunto?',
      message: 'Se borra de la nota y de la nube. No se puede deshacer.',
    )) {
      return;
    }
    if (!mounted) return;
    await ref.read(noteRepositoryProvider).deletePhoto(photo.id!);
    if (!mounted) return;
    setState(() => _existingPhotos.remove(photo));
    ref.invalidate(notesByVehicleProvider(widget.vehicleId));
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    try {
      final noteRepo = ref.read(noteRepositoryProvider);
      final detail = _detailController.text.trim();
      final String noteId;

      if (_isEditing) {
        await noteRepo.updateNote(widget.note!.copyWith(detail: detail));
        noteId = widget.note!.id!;
      } else {
        noteId = await noteRepo
            .insertNote(VehicleNote(vehicleId: widget.vehicleId, detail: detail));
      }

      await _uploadPending(noteId);

      ref.invalidate(notesByVehicleProvider(widget.vehicleId));
      if (mounted) Navigator.pop(context, _SheetOutcome.saved);
    } catch (_) {
      if (mounted) {
        AppSnack.error(context, 'No se pudo guardar la nota. Revisá la conexión.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _uploadPending(String noteId) async {
    final noteRepo = ref.read(noteRepositoryProvider);
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
    for (final file in _pendingFiles) {
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
}
