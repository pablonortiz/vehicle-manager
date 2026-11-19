part of '../vehicle_detail_screen.dart';

/// Mantenimientos: lista agrupada; tocar abre la edición, y eliminar (desde el
/// sheet) es reversible con "Deshacer", sin diálogo previo.
class _MaintenancesSection extends ConsumerStatefulWidget {
  final List<Maintenance> maintenances;
  final String vehicleId;

  const _MaintenancesSection({
    required this.maintenances,
    required this.vehicleId,
  });

  @override
  ConsumerState<_MaintenancesSection> createState() =>
      _MaintenancesSectionState();
}

class _MaintenancesSectionState extends ConsumerState<_MaintenancesSection> {
  // Borrado diferido: ocultos mientras corre el snackbar de "Deshacer".
  final Set<String> _pendingDeleteIds = {};

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final maintenances = widget.maintenances
        .where((maintenance) => !_pendingDeleteIds.contains(maintenance.id))
        .toList();
    final totalCost = maintenances.fold<double>(
        0, (sum, maintenance) => sum + (maintenance.cost ?? 0));
    final withoutCost =
        maintenances.where((maintenance) => (maintenance.cost ?? 0) == 0).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Mantenimientos',
          count: maintenances.isEmpty ? null : maintenances.length,
          actionLabel: 'Agregar',
          actionIcon: Icons.add_rounded,
          onAction: () => _openSheet(null),
        ),
        if (totalCost > 0)
          Text(
            withoutCost > 0
                ? 'Total ${AppFormats.money(totalCost)} · $withoutCost sin costo cargado'
                : 'Total ${AppFormats.money(totalCost)}',
            style: AppText.caption.tabular.copyWith(color: c.textMuted),
          ),
        const Gap(Space.s2),
        if (maintenances.isEmpty)
          const _EmptyLine('Todavía no hay mantenimientos.')
        else
          AppCard.list(
            children: [
              for (final maintenance in maintenances)
                _MaintenanceRow(
                  maintenance: maintenance,
                  onTap: () => _openSheet(maintenance),
                ),
            ],
          ),
      ],
    );
  }

  Future<void> _openSheet(Maintenance? maintenance) async {
    final outcome = await showAppSheet<_SheetOutcome>(
      context,
      enableDrag: false,
      builder: (_) => _MaintenanceFormSheet(
        vehicleId: widget.vehicleId,
        maintenance: maintenance,
      ),
    );
    if (!mounted) return;
    switch (outcome) {
      case _SheetOutcome.saved:
        AppSnack.success(context, 'Mantenimiento guardado');
      case _SheetOutcome.delete:
        await _deleteMaintenance(maintenance!);
      case null:
        break;
    }
  }

  Future<void> _deleteMaintenance(Maintenance maintenance) async {
    final repo = ref.read(maintenanceRepositoryProvider);
    setState(() => _pendingDeleteIds.add(maintenance.id!));
    final commit =
        await AppSnack.undoableDelete(context, 'Mantenimiento eliminado');
    if (!commit) {
      if (mounted) setState(() => _pendingDeleteIds.remove(maintenance.id));
      return;
    }
    try {
      await repo.deleteMaintenance(maintenance.id!);
    } finally {
      if (mounted) setState(() => _pendingDeleteIds.remove(maintenance.id));
    }
  }
}

class _MaintenanceRow extends StatelessWidget {
  final Maintenance maintenance;
  final VoidCallback onTap;

  const _MaintenanceRow({required this.maintenance, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cost = maintenance.cost;
    final attachments = maintenance.invoices.length;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Space.s4, vertical: Space.s3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.catMaintenanceSoft,
                borderRadius: Radii.smAll,
              ),
              child: Icon(Icons.build_rounded,
                  size: Sizes.iconMd, color: c.catMaintenance),
            ),
            const Gap(Space.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppFormats.date(maintenance.date),
                          style: AppText.label.copyWith(color: c.text),
                        ),
                      ),
                      Text(
                        cost != null && cost > 0
                            ? AppFormats.money(cost)
                            : 'Sin costo',
                        style: AppText.label.tabular.copyWith(
                          color: cost != null && cost > 0 ? c.text : c.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const Gap(Space.s1),
                  Text(
                    maintenance.detail,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body.copyWith(color: c.text),
                  ),
                  if (attachments > 0) ...[
                    const Gap(Space.s1),
                    Row(
                      children: [
                        Icon(Icons.attach_file_rounded,
                            size: Sizes.iconSm, color: c.textMuted),
                        const Gap(Space.s1),
                        Text(
                          attachments == 1 ? '1 adjunto' : '$attachments adjuntos',
                          style: AppText.caption.copyWith(color: c.textMuted),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Alta y edición de un mantenimiento. StatefulWidget propio para liberar los
/// controllers en dispose.
class _MaintenanceFormSheet extends ConsumerStatefulWidget {
  final String vehicleId;
  final Maintenance? maintenance;

  const _MaintenanceFormSheet({required this.vehicleId, required this.maintenance});

  @override
  ConsumerState<_MaintenanceFormSheet> createState() =>
      _MaintenanceFormSheetState();
}

class _MaintenanceFormSheetState extends ConsumerState<_MaintenanceFormSheet> {
  final _formKey = GlobalKey<AppFormState>();
  late final TextEditingController _detailController;
  late final TextEditingController _costController;
  late final String _initialCost;
  DateTime? _selectedDate;
  String? _dateError;
  late List<MaintenanceInvoice> _existingInvoices;
  final List<PlatformFile> _pendingFiles = [];
  bool _isSaving = false;
  bool _isSelectingFiles = false;

  bool get _isEditing => widget.maintenance != null;

  /// Comparado contra lo guardado: tocar un campo sin cambiarlo no cuenta.
  bool get _isDirty {
    final original = widget.maintenance;
    return _detailController.text.trim() != (original?.detail ?? '').trim() ||
        _costController.text != _initialCost ||
        !DateUtils.isSameDay(_selectedDate, original?.date) ||
        _pendingFiles.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    final maintenance = widget.maintenance;
    _detailController = TextEditingController(text: maintenance?.detail ?? '');
    _initialCost = maintenance?.cost != null
        ? formatWithDots(maintenance!.cost!.toStringAsFixed(0))
        : '';
    _costController = TextEditingController(text: _initialCost);
    _selectedDate = maintenance?.date;
    _existingInvoices = List.from(maintenance?.invoices ?? []);
  }

  @override
  void dispose() {
    _detailController.dispose();
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: _isEditing ? 'Editar mantenimiento' : 'Nuevo mantenimiento',
      hasUnsavedChanges: _isDirty && !_isSaving,
      footer: SizedBox(
        width: double.infinity,
        height: Sizes.controlH,
        child: FilledButton(
          onPressed: _isSaving ? null : _save,
          child: Text(_isSaving ? 'Guardando…' : 'Guardar mantenimiento'),
        ),
      ),
      child: AppForm(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDateField(
              label: 'Fecha',
              required: true,
              value: _selectedDate,
              lastDate: DateTime.now().add(const Duration(days: 365)),
              errorText: _dateError,
              onChanged: (date) => setState(() {
                _selectedDate = date;
                _dateError = null;
              }),
            ),
            const Gap(Space.s4),
            AppTextField(
              label: 'Detalle',
              required: true,
              controller: _detailController,
              hint: 'Qué se hizo, en qué taller, a cuántos km',
              maxLines: 4,
              minLines: 3,
              enabled: !_isSaving,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Contá qué se hizo'
                  : null,
            ),
            const Gap(Space.s4),
            AppTextField(
              label: 'Costo',
              controller: _costController,
              hint: 'Opcional',
              prefixText: r'$ ',
              keyboardType: TextInputType.number,
              enabled: !_isSaving,
              inputFormatters: [ThousandsSeparatorFormatter()],
              onChanged: (_) => setState(() {}),
            ),
            const Gap(Space.s4),
            _AttachmentsField(
              emptyHint: 'Facturas o fotos del trabajo, en PDF o imagen.',
              isBusy: _isSaving || _isSelectingFiles,
              onAdd: _pickFiles,
              attachments: [
                for (final invoice in _existingInvoices)
                  _AttachmentChip(
                    label: invoice.fileName ?? 'Archivo',
                    isPdf: invoice.isPdf,
                    onOpen: () => _openAttachment(
                      context,
                      url: invoice.cloudinaryUrl,
                      isPdf: invoice.isPdf,
                      fileName: invoice.fileName,
                    ),
                    onRemove: () => _deleteInvoice(invoice),
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
                  label: const Text('Eliminar mantenimiento'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickFiles() async {
    setState(() => _isSelectingFiles = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
        allowMultiple: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() => _pendingFiles.addAll(result.files));
      }
    } finally {
      if (mounted) setState(() => _isSelectingFiles = false);
    }
  }

  /// Irreversible: el archivo se borra también de la nube.
  Future<void> _deleteInvoice(MaintenanceInvoice invoice) async {
    if (!await confirmDestructive(
      context,
      title: '¿Eliminar este adjunto?',
      message: 'Se borra del mantenimiento y de la nube. No se puede deshacer.',
    )) {
      return;
    }
    if (!mounted) return;
    await ref.read(maintenanceRepositoryProvider).deleteInvoice(invoice.id!);
    if (!mounted) return;
    setState(() => _existingInvoices.remove(invoice));
    ref.invalidate(maintenancesByVehicleProvider(widget.vehicleId));
  }

  Future<void> _save() async {
    final formValid = _formKey.currentState?.validateAndReveal() ?? false;
    if (_selectedDate == null) {
      setState(() => _dateError = 'Elegí la fecha del mantenimiento');
    }
    if (!formValid || _selectedDate == null) return;

    setState(() => _isSaving = true);
    try {
      final maintenanceRepo = ref.read(maintenanceRepositoryProvider);
      final cost = _costController.text.trim().isEmpty
          ? null
          : double.tryParse(_costController.text.replaceAll('.', ''));
      final String maintenanceId;

      if (_isEditing) {
        await maintenanceRepo.updateMaintenance(
          widget.maintenance!.copyWith(
            date: _selectedDate,
            detail: _detailController.text.trim(),
            cost: cost,
          ),
        );
        maintenanceId = widget.maintenance!.id!;
      } else {
        maintenanceId = await maintenanceRepo.insertMaintenance(Maintenance(
          vehicleId: widget.vehicleId,
          date: _selectedDate!,
          detail: _detailController.text.trim(),
          cost: cost,
        ));
      }

      await _uploadPendingFiles(maintenanceId);

      ref.invalidate(maintenancesByVehicleProvider(widget.vehicleId));
      if (mounted) Navigator.pop(context, _SheetOutcome.saved);
    } catch (_) {
      if (mounted) {
        AppSnack.error(
            context, 'No se pudo guardar el mantenimiento. Revisá la conexión.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _uploadPendingFiles(String maintenanceId) async {
    final maintenanceRepo = ref.read(maintenanceRepositoryProvider);
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
        await maintenanceRepo.insertInvoice(MaintenanceInvoice(
          maintenanceId: maintenanceId,
          cloudinaryUrl: result.url,
          cloudinaryPublicId: result.publicId,
          fileType: result.isPdf ? InvoiceFileType.pdf : InvoiceFileType.image,
          fileName: result.fileName,
        ));
      }
    }
  }
}
