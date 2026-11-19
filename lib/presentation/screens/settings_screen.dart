import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_tone.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/services/sync_service.dart';
import '../providers/vehicle_provider.dart';
import '../widgets/app_card.dart';
import '../widgets/app_snack.dart';
import '../widgets/fleet_export_sheet.dart';
import '../widgets/fleet_insurance_sheet.dart';
import '../widgets/root_app_bar.dart';
import '../widgets/section_header.dart';
import '../widgets/theme_mode_selector.dart';
import 'settings/sync_status_view.dart';

const _appVersion = '1.0.0';

/// Ajustes: acciones sobre toda la flota, estado de la sincronización,
/// apariencia e información de la app.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isSyncing = false;

  Future<void> _syncNow() async {
    setState(() => _isSyncing = true);
    try {
      await ref.read(syncServiceProvider.notifier).fullSync();
      await ref.read(vehicleNotifierProvider.notifier).refresh();
      if (mounted) AppSnack.success(context, 'Todo sincronizado');
    } catch (_) {
      if (mounted) {
        AppSnack.error(context, 'No se pudo sincronizar. Revisá la conexión.');
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicleCount = ref.watch(totalVehicleCountProvider).valueOrNull;
    final hasVehicles = (vehicleCount ?? 0) > 0;
    return Scaffold(
      appBar: const RootAppBar(title: 'Ajustes'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            Space.s5, Space.s2, Space.s5, Space.s10),
        children: [
          const SectionHeader('Flota'),
          const Gap(Space.s2),
          AppCard.list(
            children: [
              _SettingsRow(
                icon: Icons.shield_rounded,
                title: 'Seguro de la flota',
                subtitle: hasVehicles
                    ? 'Asignar compañía y vencimiento a varios vehículos'
                    : 'Todavía no hay vehículos cargados',
                onTap: hasVehicles
                    ? () => showFleetInsuranceSheet(context, ref)
                    : null,
              ),
              _SettingsRow(
                icon: Icons.picture_as_pdf_rounded,
                title: 'Exportar listado',
                subtitle: hasVehicles
                    ? 'PDF con los vehículos y sus vencimientos'
                    : 'Todavía no hay vehículos cargados',
                onTap: hasVehicles ? () => showFleetExportSheet(context) : null,
              ),
            ],
          ),
          const Gap(Space.s6),
          const SectionHeader('Sincronización'),
          const Gap(Space.s2),
          SupabaseConfig.isConfigured
              ? _SyncCard(isSyncing: _isSyncing, onSync: _syncNow)
              : AppCard.list(
                  children: const [
                    _SettingsRow(
                      icon: Icons.cloud_off_rounded,
                      title: 'Sin configurar',
                      subtitle: 'Los datos quedan solo en este teléfono',
                    ),
                  ],
                ),
          const Gap(Space.s6),
          const SectionHeader('Apariencia'),
          const Gap(Space.s2),
          const ThemeModeSelector(),
          const Gap(Space.s6),
          const SectionHeader('Información'),
          const Gap(Space.s2),
          AppCard.list(
            children: [
              if (vehicleCount != null)
                _SettingsRow(
                  icon: Icons.directions_car_rounded,
                  title: vehicleCount == 1
                      ? '1 vehículo cargado'
                      : '$vehicleCount vehículos cargados',
                ),
              _SettingsRow(
                icon: Icons.info_rounded,
                title: 'Acerca de',
                subtitle: 'Versión $_appVersion',
                onTap: () => _showAbout(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final c = dialogContext.colors;
        return AlertDialog(
          title: const Text('Gestor de Vehículos'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Versión $_appVersion',
                  style: AppText.label.copyWith(color: c.text)),
              const Gap(Space.s3),
              Text(
                'Para gestionar los vehículos de la empresa, ordenados por '
                'provincia y ciudad, con sus vencimientos, cargas de '
                'combustible y mantenimientos.',
                style: AppText.body.copyWith(color: c.textMuted),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }
}

/// Estado de la sincronización, "Sincronizar ahora" y los cambios que todavía
/// no llegaron a la nube.
class _SyncCard extends ConsumerWidget {
  final bool isSyncing;
  final VoidCallback onSync;

  const _SyncCard({required this.isSyncing, required this.onSync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncServiceProvider);
    final queue = ref.watch(syncQueueCountsProvider).valueOrNull;
    final status = syncStatusView(
        isSyncing ? SyncStatus.syncing : syncState.status);
    final lastSync = syncState.lastSync;
    return AppCard.list(
      children: [
        _SettingsRow(
          icon: status.icon,
          iconTone: status.tone,
          title: status.label,
          subtitle: lastSync == null
              ? null
              : 'Última vez: ${AppFormats.dateTime(lastSync)}',
          trailing: syncState.status == SyncStatus.error && !isSyncing
              ? TextButton(onPressed: onSync, child: const Text('Reintentar'))
              : null,
        ),
        _SettingsRow(
          icon: Icons.sync_rounded,
          title: 'Sincronizar ahora',
          subtitle: 'Trae los últimos cambios de la nube',
          trailing: isSyncing
              ? const SizedBox.square(
                  dimension: Sizes.iconLg,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: isSyncing ? null : onSync,
        ),
        if (queue != null && queue.pending > 0)
          _SettingsRow(
            icon: Icons.cloud_upload_rounded,
            title: queue.pending == 1
                ? '1 cambio sin subir'
                : '${queue.pending} cambios sin subir',
            subtitle: 'Se suben solos al volver la conexión',
          ),
        if (queue != null && queue.failed > 0)
          _SettingsRow(
            icon: Icons.error_rounded,
            iconTone: Tone.danger,
            title: queue.failed == 1
                ? '1 cambio no se pudo subir'
                : '${queue.failed} cambios no se pudieron subir',
            trailing: TextButton(
              onPressed: () =>
                  ref.read(syncServiceProvider.notifier).retryFailedItems(),
              child: const Text('Reintentar'),
            ),
          ),
      ],
    );
  }
}

/// Fila de ajustes: ícono en tile, título, detalle opcional y, si se puede
/// tocar, chevron (o la acción que traiga).
class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Tone iconTone;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.title,
    this.iconTone = Tone.info,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final action = trailing ??
        (onTap == null
            ? null
            : Icon(Icons.chevron_right_rounded,
                size: Sizes.iconMd, color: c.textMuted));
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Space.s4, vertical: Space.s3),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconTone.background(c),
                  borderRadius: Radii.smAll,
                ),
                child: Icon(icon,
                    size: Sizes.iconMd, color: iconTone.foreground(c)),
              ),
              const Gap(Space.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.label.copyWith(color: c.text)),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: AppText.caption.copyWith(color: c.textMuted)),
                  ],
                ),
              ),
              if (action != null) ...[const Gap(Space.s2), action],
            ],
          ),
        ),
      ),
    );
  }
}
