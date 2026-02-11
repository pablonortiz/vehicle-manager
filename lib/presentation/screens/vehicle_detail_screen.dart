import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/provinces.dart';
import '../../core/constants/vehicle_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/maintenance.dart';
import '../../domain/models/vehicle.dart';
import '../../domain/models/vehicle_note.dart';
import '../../domain/models/vehicle_photo.dart';
import '../../domain/models/document_photo.dart';
import '../../domain/models/fuel_charge.dart';
import '../../data/repositories/maintenance_repository.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/repositories/photo_repository.dart';
import '../../data/repositories/document_photo_repository.dart';
import '../../data/services/cloudinary_service.dart';
import '../../data/services/pdf_service.dart';
import '../../data/services/sync_service.dart';
import '../providers/vehicle_provider.dart';
import '../providers/fuel_charge_provider.dart';
import '../widgets/vehicle_icon.dart';

class VehicleDetailScreen extends ConsumerWidget {
  final String vehicleId;

  const VehicleDetailScreen({super.key, required this.vehicleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Escuchar cambios en el estado de sincronización para refrescar las fotos
    ref.listen<SyncState>(syncServiceProvider, (previous, next) {
      if (previous?.status == SyncStatus.syncing && next.status == SyncStatus.success) {
        // Invalidar providers de fotos cuando la sincronización completa
        ref.invalidate(photosByVehicleProvider(vehicleId));
        ref.invalidate(documentPhotosByVehicleProvider(vehicleId));
        ref.invalidate(maintenancesByVehicleProvider(vehicleId));
        ref.invalidate(notesByVehicleProvider(vehicleId));
        ref.invalidate(recentFuelChargesProvider(vehicleId));
      }
    });

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

          final province = ArgentinaProvinces.getById(vehicle.provinceId);
          final dateFormat = DateFormat('dd/MM/yyyy');

          return CustomScrollView(
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
                    onPressed: () => _exportPdf(
                      context,
                      ref,
                      vehicle,
                      photosAsync.valueOrNull ?? [],
                      documentPhotosAsync.valueOrNull ?? [],
                      maintenancesAsync.valueOrNull ?? [],
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
                        error: (_, __) => const SizedBox.shrink(),
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
                                    onTap: () => _makePhoneCall(vehicle.responsiblePhone),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _ContactButton(
                                    icon: Icons.message,
                                    label: 'WhatsApp',
                                    color: const Color(0xFF25D366),
                                    onTap: () => _openWhatsApp(vehicle.responsiblePhone),
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
                            value: '${NumberFormat('#,###').format(vehicle.km)} km',
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
                      _SectionTitle(title: 'Documentación'),
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
                        error: (_, __) => const SizedBox.shrink(),
                      ),

                      // Mantenimientos
                      maintenancesAsync.when(
                        data: (maintenances) => _MaintenancesSection(
                          maintenances: maintenances,
                          vehicleId: vehicleId,
                        ),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Text('Error: $e'),
                      ),
                      const SizedBox(height: 24),

                      // Cargas de combustible
                      recentFuelChargesAsync.when(
                        data: (fuelCharges) => _FuelChargesSection(
                          recentCharges: fuelCharges,
                          vehicleId: vehicleId,
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 24),

                      // Notas
                      notesAsync.when(
                        data: (notes) => _NotesSection(
                          notes: notes,
                          vehicleId: vehicleId,
                        ),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Text('Error: $e'),
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
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    if (cleanNumber.startsWith('0')) {
      cleanNumber = cleanNumber.substring(1);
    }
    
    if (cleanNumber.length > 2) {
      final areaCode = cleanNumber.substring(0, 2);
      final rest = cleanNumber.substring(2);
      if (rest.startsWith('15')) {
        cleanNumber = areaCode + rest.substring(2);
      }
    }
    
    if (!cleanNumber.startsWith('54')) {
      cleanNumber = '549$cleanNumber';
    }
    
    final uri = Uri.parse('https://wa.me/$cleanNumber');
    
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      final androidUri = Uri.parse('whatsapp://send?phone=$cleanNumber');
      await launchUrl(androidUri);
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
                              content: Text('Error: $e'),
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
                  ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.photos.isEmpty && !_isUploading)
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library_outlined, color: AppTheme.textSecondary, size: 32),
                  SizedBox(height: 8),
                  Text('Sin fotos', style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            ),
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
                          CachedNetworkImage(
                            imageUrl: photo.cloudinaryUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            errorWidget: (_, __, ___) => const Icon(Icons.error),
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

      if (source == 'camera') {
        final result = await cloudinary.uploadFromCamera();
        if (result != null) {
          await photoRepo.insertPhoto(VehiclePhoto(
            vehicleId: widget.vehicleId,
            cloudinaryUrl: result.url,
            cloudinaryPublicId: result.publicId,
          ));
        }
      } else {
        // Galería - selección múltiple
        final results = await cloudinary.uploadMultipleFromGallery();
        setState(() => _uploadTotal = results.length);

        for (int i = 0; i < results.length; i++) {
          final result = results[i];
          await photoRepo.insertPhoto(VehiclePhoto(
            vehicleId: widget.vehicleId,
            cloudinaryUrl: result.url,
            cloudinaryPublicId: result.publicId,
          ));
          setState(() => _uploadProgress = i + 1);
        }
      }

      ref.invalidate(photosByVehicleProvider(widget.vehicleId));
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _viewPhoto(VehiclePhoto photo) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: CachedNetworkImage(
          imageUrl: photo.cloudinaryUrl,
          fit: BoxFit.contain,
        ),
      ),
    );
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

// Sección de fotos de documentos (Cédula Verde, Azul, Título)
class _DocumentPhotosSection extends ConsumerStatefulWidget {
  final List<DocumentPhoto> photos;
  final String vehicleId;

  const _DocumentPhotosSection({
    required this.photos,
    required this.vehicleId,
  });

  @override
  ConsumerState<_DocumentPhotosSection> createState() => _DocumentPhotosSectionState();
}

class _DocumentPhotosSectionState extends ConsumerState<_DocumentPhotosSection> {
  bool _isUploading = false;
  DocumentType? _uploadingType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Documentos'),
        const SizedBox(height: 12),
        ...DocumentType.values.map((type) => _buildDocumentTypeSection(type)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildDocumentTypeSection(DocumentType type) {
    final photosForType = widget.photos.where((p) => p.documentType == type).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    type == DocumentType.titulo
                        ? Icons.description
                        : type == DocumentType.vtv
                            ? Icons.verified_user
                            : Icons.credit_card,
                    size: 20,
                    color: AppTheme.accentPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    type.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (photosForType.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accentPrimary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${photosForType.length}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.accentPrimary),
                      ),
                    ),
                ],
              ),
              _isUploading && _uploadingType == type
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      onPressed: () => _addPhoto(type),
                      icon: const Icon(Icons.add_a_photo, size: 20),
                      color: AppTheme.accentPrimary,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
            ],
          ),
          if (photosForType.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: photosForType.length,
                itemBuilder: (context, index) {
                  final photo = photosForType[index];
                  return GestureDetector(
                    onTap: () => _showFullScreenImage(context, photo.cloudinaryUrl),
                    onLongPress: () => _showPhotoOptions(photo),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 70,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: photo.cloudinaryUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          errorWidget: (_, __, ___) => const Icon(Icons.error),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Sin fotos',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary.withValues(alpha: 0.7),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _addPhoto(DocumentType type) async {
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
          ],
        ),
      ),
    );

    if (source == null) return;

    setState(() {
      _isUploading = true;
      _uploadingType = type;
    });

    try {
      final cloudinary = CloudinaryService.instance;
      final docPhotoRepo = ref.read(documentPhotoRepositoryProvider);

      if (source == 'camera') {
        final result = await cloudinary.uploadFromCamera();
        if (result != null) {
          await docPhotoRepo.insertPhoto(DocumentPhoto(
            vehicleId: widget.vehicleId,
            documentType: type,
            cloudinaryUrl: result.url,
            cloudinaryPublicId: result.publicId,
          ));
        }
      } else {
        final results = await cloudinary.uploadMultipleFromGallery();
        for (final result in results) {
          await docPhotoRepo.insertPhoto(DocumentPhoto(
            vehicleId: widget.vehicleId,
            documentType: type,
            cloudinaryUrl: result.url,
            cloudinaryPublicId: result.publicId,
          ));
        }
      }

      ref.invalidate(documentPhotosByVehicleProvider(widget.vehicleId));
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadingType = null;
        });
      }
    }
  }

  void _showPhotoOptions(DocumentPhoto photo) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.fullscreen),
              title: const Text('Ver en pantalla completa'),
              onTap: () {
                Navigator.pop(ctx);
                _showFullScreenImage(context, photo.cloudinaryUrl);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppTheme.error),
              title: const Text('Eliminar', style: TextStyle(color: AppTheme.error)),
              onTap: () async {
                Navigator.pop(ctx);
                final docPhotoRepo = ref.read(documentPhotoRepositoryProvider);
                await docPhotoRepo.deletePhoto(photo.id!);
                ref.invalidate(documentPhotosByVehicleProvider(widget.vehicleId));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Foto eliminada')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Sección de mantenimientos
class _MaintenancesSection extends ConsumerStatefulWidget {
  final List<Maintenance> maintenances;
  final String vehicleId;

  const _MaintenancesSection({
    required this.maintenances,
    required this.vehicleId,
  });

  @override
  ConsumerState<_MaintenancesSection> createState() => _MaintenancesSectionState();
}

class _MaintenancesSectionState extends ConsumerState<_MaintenancesSection> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionTitle(title: 'Mantenimientos'),
            IconButton(
              onPressed: () => _showMaintenanceDialog(null),
              icon: const Icon(Icons.add, color: AppTheme.accentPrimary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.maintenances.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Center(
              child: Text(
                'Sin mantenimientos registrados',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          )
        else
          ...widget.maintenances.map((m) => _MaintenanceCard(
            maintenance: m,
            dateFormat: dateFormat,
            onTap: () => _showMaintenanceDialog(m),
            onDelete: () => _deleteMaintenance(m),
            isDeleting: _isDeleting,
          )),
      ],
    );
  }

  void _showMaintenanceDialog(Maintenance? maintenance) {
    final isEditing = maintenance != null;
    final dateController = TextEditingController(
      text: maintenance != null
          ? DateFormat('dd/MM/yyyy').format(maintenance.date)
          : '',
    );
    final detailController = TextEditingController(text: maintenance?.detail ?? '');
    DateTime? selectedDate = maintenance?.date;
    List<MaintenanceInvoice> existingInvoices = List.from(maintenance?.invoices ?? []);
    List<PlatformFile> pendingFiles = [];
    bool isSaving = false;
    bool isSelectingFiles = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
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
                        isEditing ? 'Editar Mantenimiento' : 'Nuevo Mantenimiento',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        onPressed: isSaving ? null : () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: dateController,
                    readOnly: true,
                    enabled: !isSaving,
                    decoration: const InputDecoration(
                      labelText: 'Fecha *',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setDialogState(() {
                          selectedDate = date;
                          dateController.text = DateFormat('dd/MM/yyyy').format(date);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: detailController,
                    maxLines: 4,
                    enabled: !isSaving,
                    decoration: const InputDecoration(
                      labelText: 'Detalle *',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Facturas/Archivos',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      isSelectingFiles
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : TextButton.icon(
                              onPressed: isSaving ? null : () async {
                                setDialogState(() => isSelectingFiles = true);
                                try {
                                  final result = await FilePicker.platform.pickFiles(
                                    type: FileType.custom,
                                    allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
                                    allowMultiple: true,
                                  );
                                  if (result != null && result.files.isNotEmpty) {
                                    setDialogState(() {
                                      pendingFiles.addAll(result.files);
                                    });
                                  }
                                } finally {
                                  setDialogState(() => isSelectingFiles = false);
                                }
                              },
                              icon: const Icon(Icons.attach_file, size: 18),
                              label: const Text('Adjuntar'),
                            ),
                    ],
                  ),
                  // Mostrar facturas existentes (solo en edición)
                  if (existingInvoices.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Adjuntos guardados (tocá para abrir):', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: existingInvoices.map((invoice) => GestureDetector(
                        onTap: () {
                          if (invoice.isPdf) {
                            _openFileUrl(ctx, invoice.cloudinaryUrl, true);
                          } else {
                            _showFullScreenImage(ctx, invoice.cloudinaryUrl);
                          }
                        },
                        child: Chip(
                          avatar: Icon(
                            invoice.isPdf ? Icons.picture_as_pdf : Icons.image,
                            size: 18,
                            color: invoice.isPdf ? Colors.red : AppTheme.accentPrimary,
                          ),
                          label: Text(
                            invoice.fileName ?? 'Archivo',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onDeleted: isSaving ? null : () async {
                            final maintenanceRepo = ref.read(maintenanceRepositoryProvider);
                            await maintenanceRepo.deleteInvoice(invoice.id!);
                            setDialogState(() {
                              existingInvoices.remove(invoice);
                            });
                            ref.invalidate(maintenancesByVehicleProvider(widget.vehicleId));
                          },
                        ),
                      )).toList(),
                    ),
                  ],
                  // Mostrar archivos pendientes
                  if (pendingFiles.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Pendientes de subir:', style: TextStyle(fontSize: 12, color: AppTheme.warning)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: pendingFiles.map((file) {
                        final isPdf = file.extension?.toLowerCase() == 'pdf';
                        return Chip(
                          avatar: Icon(
                            isPdf ? Icons.picture_as_pdf : Icons.image,
                            size: 18,
                            color: isPdf ? Colors.red : AppTheme.accentPrimary,
                          ),
                          label: Text(
                            file.name.length > 15 ? '${file.name.substring(0, 15)}...' : file.name,
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: AppTheme.warning.withValues(alpha: 0.2),
                          onDeleted: isSaving ? null : () {
                            setDialogState(() {
                              pendingFiles.remove(file);
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : () async {
                        if (selectedDate == null || detailController.text.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Completá la fecha y el detalle')),
                          );
                          return;
                        }

                        setDialogState(() => isSaving = true);

                        try {
                          final maintenanceRepo = ref.read(maintenanceRepositoryProvider);
                          String maintenanceId;

                          if (isEditing) {
                            await maintenanceRepo.updateMaintenance(
                              maintenance!.copyWith(
                                date: selectedDate,
                                detail: detailController.text,
                              ),
                            );
                            maintenanceId = maintenance.id!;
                          } else {
                            maintenanceId = await maintenanceRepo.insertMaintenance(Maintenance(
                              vehicleId: widget.vehicleId,
                              date: selectedDate!,
                              detail: detailController.text,
                            ));
                          }

                          // Subir archivos pendientes
                          if (pendingFiles.isNotEmpty) {
                            final cloudinary = CloudinaryService.instance;
                            for (final file in pendingFiles) {
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

                          ref.invalidate(maintenancesByVehicleProvider(widget.vehicleId));
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(isEditing ? 'Mantenimiento actualizado' : 'Mantenimiento agregado')),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
                            );
                          }
                        } finally {
                          if (ctx.mounted) setDialogState(() => isSaving = false);
                        }
                      },
                      child: isSaving
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                SizedBox(width: 12),
                                Text('Guardando...'),
                              ],
                            )
                          : Text(isEditing ? 'Guardar' : 'Agregar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteMaintenance(Maintenance maintenance) async {
    setState(() => _isDeleting = true);
    try {
      final maintenanceRepo = ref.read(maintenanceRepositoryProvider);
      await maintenanceRepo.deleteMaintenance(maintenance.id!);
      ref.invalidate(maintenancesByVehicleProvider(widget.vehicleId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mantenimiento eliminado')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }
}

class _MaintenanceCard extends StatelessWidget {
  final Maintenance maintenance;
  final DateFormat dateFormat;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool isDeleting;

  const _MaintenanceCard({
    required this.maintenance,
    required this.dateFormat,
    required this.onTap,
    required this.onDelete,
    this.isDeleting = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isDeleting ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.build, color: AppTheme.accentPrimary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateFormat.format(maintenance.date),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (maintenance.invoices.isNotEmpty)
                        Text(
                          '${maintenance.invoices.length} adjunto(s)',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                isDeleting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
                      ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              maintenance.detail,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

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
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

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
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.notes.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Center(
              child: Text(
                'Sin notas',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          )
        else
          ...widget.notes.map((n) => _NoteCard(
            note: n,
            dateFormat: dateFormat,
            onTap: () => _showNoteDialog(n),
            onDelete: () => _deleteNote(n),
            isDeleting: _isDeleting,
          )),
      ],
    );
  }

  void _showNoteDialog(VehicleNote? note) {
    final isEditing = note != null;
    final detailController = TextEditingController(text: note?.detail ?? '');
    List<NotePhoto> existingPhotos = List.from(note?.photos ?? []);
    List<XFile> pendingPhotos = [];
    bool isSaving = false;
    bool isSelectingPhotos = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
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
                        isEditing ? 'Editar Nota' : 'Nueva Nota',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        onPressed: isSaving ? null : () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: detailController,
                    maxLines: 4,
                    enabled: !isSaving,
                    decoration: const InputDecoration(
                      labelText: 'Detalle *',
                      alignLabelWithHint: true,
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
                      isSelectingPhotos
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : TextButton.icon(
                              onPressed: isSaving ? null : () async {
                                setDialogState(() => isSelectingPhotos = true);
                                try {
                                  final picker = ImagePicker();
                                  final images = await picker.pickMultiImage(imageQuality: 80);
                                  if (images.isNotEmpty) {
                                    setDialogState(() {
                                      pendingPhotos.addAll(images);
                                    });
                                  }
                                } finally {
                                  setDialogState(() => isSelectingPhotos = false);
                                }
                              },
                              icon: const Icon(Icons.add_photo_alternate, size: 18),
                              label: const Text('Agregar'),
                            ),
                    ],
                  ),
                  // Fotos existentes (solo en edición)
                  if (existingPhotos.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Fotos guardadas:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: existingPhotos.length,
                        itemBuilder: (ctx, index) {
                          final photo = existingPhotos[index];
                          return Stack(
                            children: [
                              GestureDetector(
                                onTap: () => _showFullScreenImage(ctx, photo.cloudinaryUrl),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  width: 80,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedNetworkImage(
                                      imageUrl: photo.cloudinaryUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                    ),
                                  ),
                                ),
                              ),
                              if (!isSaving)
                                Positioned(
                                  top: 2,
                                  right: 10,
                                  child: GestureDetector(
                                    onTap: () async {
                                      final noteRepo = ref.read(noteRepositoryProvider);
                                      await noteRepo.deletePhoto(photo.id!);
                                      setDialogState(() {
                                        existingPhotos.remove(photo);
                                      });
                                      ref.invalidate(notesByVehicleProvider(widget.vehicleId));
                                    },
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
                  // Fotos pendientes de subir
                  if (pendingPhotos.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Pendientes de subir:', style: TextStyle(fontSize: 12, color: AppTheme.warning)),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: pendingPhotos.length,
                        itemBuilder: (ctx, index) {
                          final photo = pendingPhotos[index];
                          return Stack(
                            children: [
                              Container(
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
                              ),
                              if (!isSaving)
                                Positioned(
                                  top: 2,
                                  right: 10,
                                  child: GestureDetector(
                                    onTap: () {
                                      setDialogState(() {
                                        pendingPhotos.remove(photo);
                                      });
                                    },
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
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : () async {
                        if (detailController.text.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Completá el detalle')),
                          );
                          return;
                        }

                        setDialogState(() => isSaving = true);

                        try {
                          final noteRepo = ref.read(noteRepositoryProvider);
                          String noteId;

                          if (isEditing) {
                            await noteRepo.updateNote(
                              note!.copyWith(detail: detailController.text),
                            );
                            noteId = note.id!;
                          } else {
                            noteId = await noteRepo.insertNote(VehicleNote(
                              vehicleId: widget.vehicleId,
                              detail: detailController.text,
                            ));
                          }

                          // Subir fotos pendientes
                          if (pendingPhotos.isNotEmpty) {
                            final cloudinary = CloudinaryService.instance;
                            for (final photo in pendingPhotos) {
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

                          ref.invalidate(notesByVehicleProvider(widget.vehicleId));
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(isEditing ? 'Nota actualizada' : 'Nota agregada')),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
                            );
                          }
                        } finally {
                          if (ctx.mounted) setDialogState(() => isSaving = false);
                        }
                      },
                      child: isSaving
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                SizedBox(width: 12),
                                Text('Guardando...'),
                              ],
                            )
                          : Text(isEditing ? 'Guardar' : 'Agregar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteNote(VehicleNote note) async {
    setState(() => _isDeleting = true);
    try {
      final noteRepo = ref.read(noteRepositoryProvider);
      await noteRepo.deleteNote(note.id!);
      ref.invalidate(notesByVehicleProvider(widget.vehicleId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nota eliminada')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }
}

class _NoteCard extends StatelessWidget {
  final VehicleNote note;
  final DateFormat dateFormat;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool isDeleting;

  const _NoteCard({
    required this.note,
    required this.dateFormat,
    required this.onTap,
    required this.onDelete,
    this.isDeleting = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isDeleting ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
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
                          '${note.photos.length} foto(s)',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.accentPrimary,
                          ),
                        ),
                    ],
                  ),
                ),
                isDeleting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
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
                      onTap: () => _showFullScreenImage(context, photo.cloudinaryUrl),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 60,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
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
      ),
    );
  }
}

// Widgets auxiliares
class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppTheme.accentPrimary,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;

  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: children
            .expand((widget) => [widget, const Divider(height: 24)])
            .take(children.length * 2 - 1)
            .toList(),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailing;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 20, color: AppTheme.textSecondary),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: valueColor ?? AppTheme.textPrimary,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}

class _ContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ContactButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper para mostrar imagen en pantalla completa
void _showFullScreenImage(BuildContext context, String imageUrl) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          InteractiveViewer(
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: (_, __) => const Center(
                child: CircularProgressIndicator(),
              ),
              errorWidget: (_, __, ___) => const Center(
                child: Icon(Icons.error, color: AppTheme.error, size: 48),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// Helper para abrir archivos (PDFs o imágenes) en el navegador
Future<void> _openFileUrl(BuildContext context, String url, bool isPdf) async {
  final uri = Uri.parse(url);
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el archivo')),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
      );
    }
  }
}

// Exportar vehículo a PDF
Future<void> _exportPdf(
  BuildContext context,
  WidgetRef ref,
  Vehicle vehicle,
  List<VehiclePhoto> photos,
  List<DocumentPhoto> documentPhotos,
  List<Maintenance> maintenances,
) async {
  // Mostrar diálogo de progreso
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surface,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          const Text(
            'Generando PDF...',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Descargando imágenes y creando documento',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );

  try {
    final pdfBytes = await PdfService.generateVehiclePdf(
      vehicle: vehicle,
      photos: photos,
      documentPhotos: documentPhotos,
      maintenances: maintenances,
    );

    // Cerrar diálogo de progreso
    if (context.mounted) {
      Navigator.pop(context);
    }

    // Compartir/guardar PDF
    await PdfService.sharePdf(pdfBytes, vehicle.plate);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF generado exitosamente'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  } catch (e) {
    // Cerrar diálogo de progreso si aún está abierto
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar PDF: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }
}

// Sección de cargas de combustible
class _FuelChargesSection extends ConsumerStatefulWidget {
  final List<FuelCharge> recentCharges;
  final String vehicleId;

  const _FuelChargesSection({
    required this.recentCharges,
    required this.vehicleId,
  });

  @override
  ConsumerState<_FuelChargesSection> createState() => _FuelChargesSectionState();
}

class _FuelChargesSectionState extends ConsumerState<_FuelChargesSection> {
  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat.currency(
      locale: 'es_AR',
      symbol: '\$',
      decimalDigits: 0,
    );

    // Get current month summary
    final now = DateTime.now();
    final summaryParams = MonthlyFuelParams(
      vehicleId: widget.vehicleId,
      year: now.year,
      month: now.month,
    );
    final summaryAsync = ref.watch(fuelChargeSummaryProvider(summaryParams));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionTitle(title: 'Combustible'),
            TextButton.icon(
              onPressed: () => context.push('/vehicle/${widget.vehicleId}/fuel'),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('Ver historial'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.accentPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Monthly summary card
        summaryAsync.when(
          data: (summary) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.accentPrimary.withOpacity(0.1),
                  AppTheme.accentDark.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accentPrimary.withOpacity(0.2)),
            ),
            child: summary.chargeCount == 0
                ? const Center(
                    child: Text(
                      'Sin cargas este mes',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _FuelSummaryItem(
                        icon: Icons.local_gas_station,
                        value: '${summary.totalLiters.toStringAsFixed(1)} L',
                        label: 'Este mes',
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: AppTheme.border,
                      ),
                      _FuelSummaryItem(
                        icon: Icons.attach_money,
                        value: currencyFormat.format(summary.totalPrice),
                        label: 'Gastado',
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: AppTheme.border,
                      ),
                      _FuelSummaryItem(
                        icon: Icons.trending_up,
                        value: '${currencyFormat.format(summary.averagePricePerLiter)}/L',
                        label: 'Promedio',
                      ),
                    ],
                  ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
        ),

        if (widget.recentCharges.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Últimas cargas',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ...widget.recentCharges.map((charge) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.local_gas_station,
                    size: 16,
                    color: AppTheme.accentPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${charge.liters.toStringAsFixed(1)} L',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        dateFormat.format(charge.date),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  currencyFormat.format(charge.price),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accentPrimary,
                  ),
                ),
              ],
            ),
          )),
        ],
      ],
    );
  }
}

class _FuelSummaryItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _FuelSummaryItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.accentPrimary, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
