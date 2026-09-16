import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/config/supabase_config.dart';
import '../../core/constants/provinces.dart';
import '../../core/constants/vehicle_constants.dart';
import '../../core/theme/app_theme.dart';
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
import '../widgets/vehicle_icon.dart';
import '../widgets/fuel_summary_card.dart';
import '../../core/utils/contact_launcher.dart';
import '../../core/utils/confirm_dialog.dart';
import '../../core/utils/thousands_formatter.dart';
import '../widgets/error_retry_view.dart';
import '../widgets/empty_state.dart';
import '../widgets/app_card.dart';
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
  final _docsSectionKey = GlobalKey();
  late bool _docsScrollPending = widget.highlightDocs;

  String get vehicleId => widget.vehicleId;

  /// Al entrar desde "Documentos por Vencer", lleva la vista a Documentación.
  /// Dos pasadas: las secciones async (fotos, adjuntos) cargan después del
  /// primer frame y corren el layout, así que la segunda corrige el desvío.
  void _scheduleDocsScroll() {
    if (!_docsScrollPending) return;
    _docsScrollPending = false;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (final delay in const [100, 700]) {
        await Future.delayed(Duration(milliseconds: delay));
        if (!mounted) return;
        final docsContext = _docsSectionKey.currentContext;
        if (docsContext == null || !docsContext.mounted) continue;
        await Scrollable.ensureVisible(
          docsContext,
          duration: const Duration(milliseconds: 300),
          alignment: 0.05,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // El refresco post-sync de fotos/documentos/mantenimientos/notas/combustible
    // ya ocurre solo: replaceAllData emite notifyChange de esas tablas y cada
    // provider watchea su *ChangeProvider. No hace falta invalidar manualmente.

    final vehicleAsync = ref.watch(vehicleByIdProvider(vehicleId));
    final maintenancesAsync = ref.watch(maintenancesByVehicleProvider(vehicleId));
    final notesAsync = ref.watch(notesByVehicleProvider(vehicleId));
    final photosAsync = ref.watch(photosByVehicleProvider(vehicleId));
    final documentPhotosAsync = ref.watch(documentPhotosByVehicleProvider(vehicleId));
    final recentFuelChargesAsync = ref.watch(recentFuelChargesProvider(vehicleId));

    return Scaffold(
      body: vehicleAsync.when(
        data: (vehicle) {
          if (vehicle == null) {
            return const Center(child: Text('Vehículo no encontrado'));
          }

          _scheduleDocsScroll();

          final province = ArgentinaProvinces.getById(vehicle.provinceId);
          final dateFormat = DateFormat('dd/MM/yyyy');

          return RefreshIndicator(
            onRefresh: () async {
              if (SupabaseConfig.isConfigured) {
                await ref.read(syncServiceProvider.notifier).fullSync();
              }
              ref.invalidate(vehicleByIdProvider(vehicleId));
              ref.invalidate(maintenancesByVehicleProvider(vehicleId));
              ref.invalidate(notesByVehicleProvider(vehicleId));
              ref.invalidate(photosByVehicleProvider(vehicleId));
              ref.invalidate(documentPhotosByVehicleProvider(vehicleId));
              ref.invalidate(recentFuelChargesProvider(vehicleId));
            },
            child: CustomScrollView(
            slivers: [
              // App Bar con icono sticky
              SliverAppBar(
                expandedHeight: 180,
                pinned: true,
                backgroundColor: AppTheme.surface,
                leading: IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back),
                ),
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VehicleIcon(
                      type: vehicle.type,
                      vehicleColor: vehicle.color,
                      status: vehicle.status,
                      size: 36,
                      showStatusBadge: false,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            vehicle.plate,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            vehicle.status.label,
                            style: TextStyle(
                              fontSize: 11,
                              color: vehicle.status.color,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    onPressed: () => _showPdfOptions(
                      context,
                      ref,
                      vehicle,
                      photosAsync.valueOrNull ?? [],
                      documentPhotosAsync.valueOrNull ?? [],
                      maintenancesAsync.valueOrNull ?? [],
                      notesAsync.valueOrNull ?? [],
                    ),
                    icon: const Icon(Icons.picture_as_pdf),
                    tooltip: 'Exportar PDF',
                  ),
                  IconButton(
                    onPressed: () => context.push('/vehicle/$vehicleId/history'),
                    icon: const Icon(Icons.history),
                    tooltip: 'Historial',
                  ),
                  IconButton(
                    onPressed: () => context.push('/vehicle/$vehicleId/edit'),
                    icon: const Icon(Icons.edit),
                    tooltip: 'Editar',
                  ),
                  const SizedBox(width: 4),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          vehicle.color.withAlpha(80),
                          AppTheme.background,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 50),
                            VehicleIcon(
                              type: vehicle.type,
                              vehicleColor: vehicle.color,
                              status: vehicle.status,
                              size: 72,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              vehicle.plate,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre y estado
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              vehicle.displayName,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: vehicle.status.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: vehicle.status.color.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  vehicle.status.icon,
                                  size: 16,
                                  color: vehicle.status.color,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  vehicle.status.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: vehicle.status.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${vehicle.type.label} • ${vehicle.year} • ${vehicle.fuelType.label}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Galería de fotos
                      photosAsync.when(
                        data: (photos) => _PhotosSection(
                          photos: photos,
                          vehicleId: vehicleId,
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),

                      // Contacto del responsable
                      _SectionTitle(title: 'Responsable'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppTheme.accentPrimary.withValues(alpha: 0.2),
                                  child: Text(
                                    vehicle.responsibleName.isNotEmpty
                                        ? vehicle.responsibleName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: AppTheme.accentPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        vehicle.responsibleName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        vehicle.responsiblePhone,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _ContactButton(
                                    icon: Icons.phone,
                                    label: 'Llamar',
                                    color: AppTheme.success,
                                    onTap: () => _makePhoneCall(context, vehicle.responsiblePhone),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _ContactButton(
                                    icon: Icons.message,
                                    label: 'WhatsApp',
                                    color: AppTheme.whatsapp,
                                    onTap: () => ContactLauncher.openWhatsApp(vehicle.responsiblePhone),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Ubicación
                      _SectionTitle(title: 'Ubicación'),
                      const SizedBox(height: 12),
                      _InfoCard(
                        children: [
                          _InfoRow(
                            icon: Icons.location_city,
                            label: 'Ciudad',
                            value: vehicle.city,
                          ),
                          if (vehicle.lugar != null && vehicle.lugar!.isNotEmpty)
                            _InfoRow(
                              icon: Icons.place,
                              label: 'Lugar',
                              value: vehicle.lugar!,
                            ),
                          _InfoRow(
                            icon: Icons.map,
                            label: 'Provincia',
                            value: province.name,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Datos del vehículo
                      _SectionTitle(title: 'Información'),
                      const SizedBox(height: 12),
                      _InfoCard(
                        children: [
                          _InfoRow(
                            icon: Icons.speed,
                            label: 'Kilometraje',
                            value: AppFormats.km(vehicle.km),
                          ),
                          _InfoRow(
                            icon: vehicle.fuelType.icon,
                            label: 'Combustible',
                            value: vehicle.fuelType.label,
                          ),
                          _InfoRow(
                            icon: Icons.calendar_today,
                            label: 'Año',
                            value: vehicle.year.toString(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Documentación
                      KeyedSubtree(
                        key: _docsSectionKey,
                        child: _SectionTitle(title: 'Documentación'),
                      ),
                      const SizedBox(height: 12),
                      _InfoCard(
                        children: [
                          _InfoRow(
                            icon: Icons.fact_check,
                            label: 'VTV',
                            value: vehicle.vtvExpiry != null
                                ? dateFormat.format(vehicle.vtvExpiry!)
                                : 'No registrado',
                            valueColor: vehicle.isVtvExpired
                                ? AppTheme.error
                                : vehicle.isVtvExpiringSoon
                                    ? AppTheme.warning
                                    : null,
                            trailing: vehicle.isVtvExpired || vehicle.isVtvExpiringSoon
                                ? Icon(
                                    vehicle.isVtvExpired
                                        ? Icons.error
                                        : Icons.warning_amber_rounded,
                                    size: 18,
                                    color: vehicle.isVtvExpired
                                        ? AppTheme.error
                                        : AppTheme.warning,
                                  )
                                : null,
                          ),
                          _InfoRow(
                            icon: Icons.security,
                            label: 'Seguro',
                            value: vehicle.insuranceCompany ?? 'No registrado',
                          ),
                          _InfoRow(
                            icon: Icons.event,
                            label: 'Vence',
                            value: vehicle.insuranceExpiry != null
                                ? dateFormat.format(vehicle.insuranceExpiry!)
                                : 'No registrado',
                            valueColor: vehicle.isInsuranceExpired
                                ? AppTheme.error
                                : vehicle.isInsuranceExpiringSoon
                                    ? AppTheme.warning
                                    : null,
                            trailing: vehicle.isInsuranceExpired || vehicle.isInsuranceExpiringSoon
                                ? Icon(
                                    vehicle.isInsuranceExpired
                                        ? Icons.error
                                        : Icons.warning_amber_rounded,
                                    size: 18,
                                    color: vehicle.isInsuranceExpired
                                        ? AppTheme.error
                                        : AppTheme.warning,
                                  )
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Fotos de documentos (Cédula Verde, Azul, Título)
                      documentPhotosAsync.when(
                        data: (docPhotos) => _DocumentPhotosSection(
                          photos: docPhotos,
                          vehicleId: vehicleId,
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),

                      // Mantenimientos
                      maintenancesAsync.when(
                        data: (maintenances) => _MaintenancesSection(
                          maintenances: maintenances,
                          vehicleId: vehicleId,
                        ),
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (e, _) => ErrorRetryView(
                          message: 'No se pudieron cargar los mantenimientos',
                          onRetry: () => ref.invalidate(
                              maintenancesByVehicleProvider(vehicleId)),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Cargas de combustible
                      recentFuelChargesAsync.when(
                        data: (fuelCharges) => _FuelChargesSection(
                          recentCharges: fuelCharges,
                          vehicleId: vehicleId,
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 24),

                      // Notas
                      notesAsync.when(
                        data: (notes) => _NotesSection(
                          notes: notes,
                          vehicleId: vehicleId,
                        ),
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (e, _) => ErrorRetryView(
                          message: 'No se pudieron cargar las notas',
                          onRetry: () =>
                              ref.invalidate(notesByVehicleProvider(vehicleId)),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Botón eliminar
                      Center(
                        child: TextButton.icon(
                          onPressed: () => _confirmDelete(context, ref),
                          icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                          label: const Text(
                            'Eliminar vehículo',
                            style: TextStyle(color: AppTheme.error),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetryView(
          message: 'No se pudo cargar el vehículo',
          onRetry: () => ref.invalidate(vehicleByIdProvider(vehicleId)),
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(BuildContext context, String phoneNumber) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await ContactLauncher.callPhone(phoneNumber)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo iniciar la llamada')),
      );
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    bool isDeleting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Eliminar vehículo'),
          content: isDeleting
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Expanded(child: Text('Eliminando vehículo...')),
                  ],
                )
              : const Text(
                  '¿Estás seguro de que querés eliminar este vehículo? Esta acción no se puede deshacer.',
                ),
          actions: isDeleting
              ? null
              : [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () async {
                      setDialogState(() => isDeleting = true);

                      try {
                        final success = await ref
                            .read(vehicleNotifierProvider.notifier)
                            .deleteVehicle(vehicleId);

                        if (ctx.mounted) Navigator.pop(ctx);

                        if (success && context.mounted) {
                          context.go('/vehicles');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Vehículo eliminado')),
                          );
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Error al eliminar el vehículo'),
                              backgroundColor: AppTheme.error,
                            ),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('No se pudo eliminar el vehículo'),
                              backgroundColor: AppTheme.error,
                            ),
                          );
                        }
                      }
                    },
                    child: const Text(
                      'Eliminar',
                      style: TextStyle(color: AppTheme.error),
                    ),
                  ),
                ],
        ),
      ),
    );
  }
}
