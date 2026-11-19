import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/config/supabase_config.dart';
import '../../core/constants/provinces.dart';
import '../../core/constants/vehicle_constants.dart';
import '../../core/theme/app_button_styles.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_tone.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/maintenance.dart';
import '../../domain/models/vehicle.dart';
import '../../domain/models/vehicle_note.dart';
import '../../domain/models/vehicle_photo.dart';
import '../../domain/models/document_photo.dart';
import '../../domain/models/fuel_charge.dart';
import '../../data/repositories/document_photo_repository.dart';
import '../../data/services/cloudinary_service.dart';
import '../../data/services/sync_service.dart';
import 'package:printing/printing.dart';
import '../../data/services/pdf_service.dart';
import '../providers/vehicle_provider.dart';
import '../providers/fuel_charge_provider.dart';
import '../widgets/app_notice.dart';
import '../widgets/app_sheet.dart';
import '../widgets/app_snack.dart';
import '../widgets/app_tag.dart';
import '../widgets/info_row.dart';
import '../widgets/plate_text.dart';
import '../widgets/section_header.dart';
import '../widgets/status_pill.dart';
import '../widgets/vehicle_icon.dart';
import '../../core/utils/contact_launcher.dart';
import '../../core/utils/confirm_dialog.dart';
import '../../core/utils/thousands_formatter.dart';
import '../widgets/error_retry_view.dart';
import '../widgets/empty_state.dart';
import '../widgets/app_card.dart';
import '../widgets/app_date_field.dart';
import '../widgets/app_text_field.dart';
import '../widgets/pdf_export_flow.dart';

part 'vehicle_detail/photos_section.dart';
part 'vehicle_detail/document_photos_section.dart';
part 'vehicle_detail/maintenances_section.dart';
part 'vehicle_detail/notes_section.dart';
part 'vehicle_detail/fuel_charges_section.dart';
part 'vehicle_detail/detail_widgets.dart';
part 'vehicle_detail/pdf_preview.dart';
part 'vehicle_detail/pdf_export.dart';

class VehicleDetailScreen extends ConsumerStatefulWidget {
  final String vehicleId;
  final bool highlightDocs;

  const VehicleDetailScreen({
    super.key,
    required this.vehicleId,
    this.highlightDocs = false,
  });

  @override
  ConsumerState<VehicleDetailScreen> createState() =>
      _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends ConsumerState<VehicleDetailScreen> {
  final _expirySectionKey = GlobalKey();
  late bool _expiryScrollPending = widget.highlightDocs;

  String get vehicleId => widget.vehicleId;

  /// Al entrar desde Vencimientos, se asegura de que esa sección se vea
  /// entera, scrolleando lo mínimo (con letra grande puede quedar abajo). Dos
  /// pasadas: las secciones async cargan después del primer frame y corren el
  /// layout, así que la segunda corrige el desvío.
  void _scheduleExpiryScroll() {
    if (!_expiryScrollPending) return;
    _expiryScrollPending = false;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (final delay in const [100, 700]) {
        await Future.delayed(Duration(milliseconds: delay));
        if (!mounted) return;
        final sectionContext = _expirySectionKey.currentContext;
        if (sectionContext == null || !sectionContext.mounted) continue;
        await Scrollable.ensureVisible(
          sectionContext,
          duration: Motion.medium,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    });
  }

  Future<void> _refresh() async {
    if (SupabaseConfig.isConfigured) {
      await ref.read(syncServiceProvider.notifier).fullSync();
    }
    ref.invalidate(vehicleByIdProvider(vehicleId));
    ref.invalidate(maintenancesByVehicleProvider(vehicleId));
    ref.invalidate(notesByVehicleProvider(vehicleId));
    ref.invalidate(photosByVehicleProvider(vehicleId));
    ref.invalidate(documentPhotosByVehicleProvider(vehicleId));
    ref.invalidate(recentFuelChargesProvider(vehicleId));
  }

  @override
  Widget build(BuildContext context) {
    // El refresco post-sync de cada sección ocurre solo: replaceAllData emite
    // notifyChange y cada provider watchea su *ChangeProvider.
    final vehicleAsync = ref.watch(vehicleByIdProvider(vehicleId));

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Editar',
            onPressed: () => context.push('/vehicle/$vehicleId/edit'),
            icon: const Icon(Icons.edit_rounded),
          ),
          PopupMenuButton<VoidCallback>(
            tooltip: 'Más opciones',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (action) => action(),
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: vehicleAsync.valueOrNull != null,
                value: () => _exportPdf(vehicleAsync.valueOrNull!),
                child: const ListTile(
                  leading: Icon(Icons.picture_as_pdf_rounded),
                  title: Text('Exportar PDF'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: () => context.push('/vehicle/$vehicleId/history'),
                child: const ListTile(
                  leading: Icon(Icons.history_rounded),
                  title: Text('Cambios'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const Gap(Space.s1),
        ],
      ),
      body: vehicleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorRetryView(
          message: 'No se pudo cargar el vehículo',
          onRetry: () => ref.invalidate(vehicleByIdProvider(vehicleId)),
        ),
        data: (vehicle) {
          if (vehicle == null) {
            return Center(
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: 'No encontramos este vehículo',
                actionLabel: 'Ir a Vehículos',
                onAction: () => context.go('/vehicles'),
                primaryAction: false,
              ),
            );
          }
          _scheduleExpiryScroll();
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  Space.s5, Space.s2, Space.s5, Space.s10),
              children: [
                _DetailHeader(vehicle: vehicle),
                const Gap(Space.s6),
                Column(
                  key: _expirySectionKey,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader('Vencimientos'),
                    const Gap(Space.s2),
                    _ExpiryCard(vehicle: vehicle),
                  ],
                ),
                const Gap(Space.s6),
                const SectionHeader('Responsable'),
                const Gap(Space.s2),
                _ResponsibleCard(vehicle: vehicle),
                const Gap(Space.s6),
                _FuelChargesSection(vehicleId: vehicleId),
                const Gap(Space.s6),
                _AsyncSection(
                  value: ref.watch(maintenancesByVehicleProvider(vehicleId)),
                  title: 'Mantenimientos',
                  errorMessage: 'No se pudieron cargar los mantenimientos.',
                  onRetry: () =>
                      ref.invalidate(maintenancesByVehicleProvider(vehicleId)),
                  builder: (maintenances) => _MaintenancesSection(
                    maintenances: maintenances,
                    vehicleId: vehicleId,
                  ),
                ),
                const Gap(Space.s6),
                _AsyncSection(
                  value: ref.watch(notesByVehicleProvider(vehicleId)),
                  title: 'Notas',
                  errorMessage: 'No se pudieron cargar las notas.',
                  onRetry: () =>
                      ref.invalidate(notesByVehicleProvider(vehicleId)),
                  builder: (notes) =>
                      _NotesSection(notes: notes, vehicleId: vehicleId),
                ),
                const Gap(Space.s6),
                const SectionHeader('Datos'),
                const Gap(Space.s2),
                _DataCard(vehicle: vehicle),
                const Gap(Space.s6),
                _AsyncSection(
                  value: ref.watch(photosByVehicleProvider(vehicleId)),
                  title: 'Fotos',
                  errorMessage: 'No se pudieron cargar las fotos.',
                  onRetry: () =>
                      ref.invalidate(photosByVehicleProvider(vehicleId)),
                  builder: (photos) =>
                      _PhotosSection(photos: photos, vehicleId: vehicleId),
                ),
                const Gap(Space.s6),
                _AsyncSection(
                  value: ref.watch(documentPhotosByVehicleProvider(vehicleId)),
                  title: 'Papeles',
                  errorMessage: 'No se pudieron cargar los papeles.',
                  onRetry: () => ref
                      .invalidate(documentPhotosByVehicleProvider(vehicleId)),
                  builder: (photos) => _DocumentPhotosSection(
                    photos: photos,
                    vehicleId: vehicleId,
                  ),
                ),
                const Gap(Space.s8),
                Center(
                  child: TextButton.icon(
                    style: AppButtonStyles.dangerText(context),
                    onPressed: _confirmDelete,
                    icon: const Icon(Icons.delete_rounded),
                    label: const Text('Eliminar vehículo'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _exportPdf(Vehicle vehicle) {
    _showPdfOptions(
      context,
      ref,
      vehicle,
      ref.read(photosByVehicleProvider(vehicleId)).valueOrNull ?? [],
      ref.read(documentPhotosByVehicleProvider(vehicleId)).valueOrNull ?? [],
      ref.read(maintenancesByVehicleProvider(vehicleId)).valueOrNull ?? [],
      ref.read(notesByVehicleProvider(vehicleId)).valueOrNull ?? [],
    );
  }

  /// Borrado irreversible: diálogo destructivo con lo que también se borra.
  Future<void> _confirmDelete() async {
    final confirmed = await confirmDestructive(
      context,
      title: '¿Eliminar este vehículo?',
      message: 'Se borran también sus fotos, papeles, mantenimientos, notas y '
          'cargas de combustible. No se puede deshacer.',
    );
    if (!confirmed || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              Gap(Space.s4),
              Expanded(child: Text('Eliminando vehículo…')),
            ],
          ),
        ),
      ),
    );
    var deleted = false;
    try {
      deleted = await ref
          .read(vehicleNotifierProvider.notifier)
          .deleteVehicle(vehicleId);
    } catch (_) {
      deleted = false;
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (deleted) {
      context.go('/vehicles');
      AppSnack.success(context, 'Vehículo eliminado');
    } else {
      AppSnack.error(
          context, 'No se pudo eliminar el vehículo. Revisá la conexión.');
    }
  }
}
