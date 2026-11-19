part of '../vehicle_detail_screen.dart';

/// Ícono, nombre, patente y estado: lo primero que se lee del vehículo.
class _DetailHeader extends StatelessWidget {
  final Vehicle vehicle;

  const _DetailHeader({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final meta = [
      vehicle.type.label,
      if (vehicle.year > 0) '${vehicle.year}',
      vehicle.fuelType.label,
    ].join(' · ');
    return Row(
      children: [
        VehicleIcon(type: vehicle.type, paint: vehicle.color, large: true),
        const Gap(Space.s4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vehicle.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.titleLg.copyWith(color: c.text),
              ),
              const Gap(Space.s2),
              Wrap(
                spacing: Space.s2,
                runSpacing: Space.s2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PlateText(vehicle.plate, large: true),
                  StatusPill.vehicle(vehicle.status),
                ],
              ),
              const Gap(Space.s2),
              Text(meta, style: AppText.caption.copyWith(color: c.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

/// VTV y seguro con su estado: el mismo pill que en Inicio y en las filas.
class _ExpiryCard extends StatelessWidget {
  final Vehicle vehicle;

  const _ExpiryCard({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final vtv = vehicle.vtvExpiry;
    final insurance = vehicle.insuranceExpiry;
    final company = vehicle.insuranceCompany?.trim();
    final insuranceText = [
      if (company != null && company.isNotEmpty) company,
      if (insurance != null) 'vence el ${AppFormats.date(insurance)}',
    ].join(', ');
    return AppCard.list(
      children: [
        InfoRow(
          label: 'VTV',
          value: vtv == null ? null : AppFormats.date(vtv),
          trailing: StatusPill.expiry(vtv),
        ),
        InfoRow(
          label: 'Seguro',
          value: insuranceText.isEmpty ? null : insuranceText,
          trailing: StatusPill.expiry(insurance),
        ),
      ],
    );
  }
}

/// Responsable y contacto. Sin un teléfono real no se ofrecen Llamar ni
/// WhatsApp (había placeholders como "000000").
class _ResponsibleCard extends StatelessWidget {
  final Vehicle vehicle;

  const _ResponsibleCard({required this.vehicle});

  static bool _isRealPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 6 && !RegExp(r'^0+$').hasMatch(digits);
  }

  Future<void> _call(BuildContext context) async {
    if (!await ContactLauncher.callPhone(vehicle.responsiblePhone) &&
        context.mounted) {
      AppSnack.error(context, 'No se pudo iniciar la llamada');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasPhone = _isRealPhone(vehicle.responsiblePhone);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            vehicle.responsibleName,
            style: AppText.titleSm.copyWith(color: c.text),
          ),
          const Gap(Space.s1),
          Text(
            hasPhone ? vehicle.responsiblePhone : 'Sin teléfono cargado',
            style: AppText.body.tabular.copyWith(color: c.textMuted),
          ),
          if (hasPhone) ...[
            const Gap(Space.s4),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _call(context),
                    icon: const Icon(Icons.call_rounded),
                    label: const Text('Llamar'),
                  ),
                ),
                const Gap(Space.s3),
                Expanded(
                  child: FilledButton.icon(
                    style: AppButtonStyles.whatsapp(context),
                    onPressed: () =>
                        ContactLauncher.openWhatsApp(vehicle.responsiblePhone),
                    icon: const Icon(Icons.chat_rounded),
                    label: const Text('WhatsApp'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Ubicación y datos técnicos en una sola lista agrupada.
class _DataCard extends StatelessWidget {
  final Vehicle vehicle;

  const _DataCard({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final province = ArgentinaProvinces.getById(vehicle.provinceId);
    final location = [vehicle.lugar, vehicle.city, province.name]
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .join(', ');
    return AppCard.list(
      children: [
        InfoRow(label: 'Ubicación', value: location),
        InfoRow(
          label: 'Kilometraje',
          value: vehicle.km > 0 ? AppFormats.km(vehicle.km) : 'Sin cargar',
        ),
        InfoRow(label: 'Combustible', value: vehicle.fuelType.label),
        InfoRow(
          label: 'Año',
          value: vehicle.year > 0 ? '${vehicle.year}' : 'Sin cargar',
        ),
      ],
    );
  }
}

/// Sección que carga aparte: cargando ocupa poco, y si falla muestra el
/// error con "Reintentar" en vez de esconder la sección.
class _AsyncSection<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final String title;
  final String errorMessage;
  final VoidCallback onRetry;
  final Widget Function(T data) builder;

  const _AsyncSection({
    required this.value,
    required this.title,
    required this.errorMessage,
    required this.onRetry,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title),
          const Gap(Space.s2),
          const LinearProgressIndicator(),
        ],
      ),
      error: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title),
          const Gap(Space.s2),
          AppNotice.error(message: errorMessage, onRetry: onRetry),
        ],
      ),
    );
  }
}

/// Vacío compacto de una sección del detalle: la acción de agregar ya está en
/// el encabezado, así que no se repite.
class _EmptyLine extends StatelessWidget {
  final String text;

  const _EmptyLine(this.text);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Text(text, style: AppText.body.copyWith(color: context.colors.textMuted)),
    );
  }
}

/// Miniatura de foto o PDF, con ripple y anuncio para lectores de pantalla.
class _Thumbnail extends StatelessWidget {
  final String url;
  final bool isPdf;
  final double size;
  final String semanticLabel;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool highlighted;
  final Widget? badge;

  const _Thumbnail({
    required this.url,
    required this.isPdf,
    required this.size,
    required this.semanticLabel,
    required this.onTap,
    this.onLongPress,
    this.highlighted = false,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // excludeSemantics descarta también la acción del InkWell: el tap va
    // declarado acá para que TalkBack lo pueda activar.
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Material(
        color: c.surfaceRaised,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.smAll,
          side: highlighted
              ? BorderSide(color: c.accent, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: SizedBox.square(
            dimension: size,
            child: Stack(
              fit: StackFit.expand,
              children: [
                isPdf
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.picture_as_pdf_rounded,
                                color: c.textMuted, size: Sizes.iconLg),
                            const Gap(Space.s1),
                            const AppTag('PDF'),
                          ],
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        errorWidget: (_, _, _) => Icon(
                          Icons.broken_image_rounded,
                          color: c.textMuted,
                        ),
                      ),
                if (badge != null)
                  Positioned(top: Space.s1, left: Space.s1, child: badge!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lo que devuelve un sheet de edición al cerrarse.
enum _SheetOutcome { saved, delete }

/// Un adjunto en el formulario de un mantenimiento o una nota: guardado (se
/// abre al tocarlo) o pendiente de subir (se sube al guardar).
class _AttachmentChip {
  final String label;
  final bool isPdf;
  final bool pending;
  final VoidCallback? onOpen;
  final VoidCallback onRemove;

  const _AttachmentChip({
    required this.label,
    required this.isPdf,
    required this.onRemove,
    this.pending = false,
    this.onOpen,
  });
}

class _AttachmentsField extends StatelessWidget {
  final List<_AttachmentChip> attachments;
  final String emptyHint;
  final bool isBusy;
  final VoidCallback onAdd;

  const _AttachmentsField({
    required this.attachments,
    required this.emptyHint,
    required this.isBusy,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: FieldLabel('Adjuntos')),
            TextButton.icon(
              onPressed: isBusy ? null : onAdd,
              icon: const Icon(Icons.attach_file_rounded),
              label: const Text('Adjuntar'),
            ),
          ],
        ),
        if (attachments.isEmpty)
          Text(emptyHint, style: AppText.caption.copyWith(color: c.textMuted))
        else
          Wrap(
            spacing: Space.s2,
            runSpacing: Space.s2,
            children: [
              for (final attachment in attachments)
                InputChip(
                  avatar: Icon(attachment.pending
                      ? Icons.schedule_rounded
                      : attachment.isPdf
                          ? Icons.picture_as_pdf_rounded
                          : Icons.image_rounded),
                  label: Text(attachment.label, overflow: TextOverflow.ellipsis),
                  tooltip: attachment.pending ? 'Se sube al guardar' : null,
                  onPressed: attachment.onOpen,
                  deleteButtonTooltipMessage:
                      attachment.pending ? 'Quitar' : 'Eliminar adjunto',
                  onDeleted: isBusy ? null : attachment.onRemove,
                ),
            ],
          ),
      ],
    );
  }
}
