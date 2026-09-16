import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/config/supabase_config.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/sync_service.dart';
import '../providers/vehicle_provider.dart';
import '../widgets/fleet_insurance_sheet.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isSyncing = false;

  @override
  Widget build(BuildContext context) {
    final totalCountAsync = ref.watch(totalVehicleCountProvider);
    final syncState = ref.watch(syncServiceProvider);
    final queueCounts = ref.watch(syncQueueCountsProvider).valueOrNull;
    final hasVehicles = (totalCountAsync.valueOrNull ?? 0) > 0;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Ajustes',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 24),

          // Estadísticas
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.accentPrimary.withValues(alpha: 0.2),
                  AppTheme.accentPrimary.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.accentPrimary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.accentPrimary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.directions_car,
                    color: AppTheme.accentPrimary,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vehículos registrados',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    totalCountAsync.when(
                      data: (count) => Text(
                        count.toString(),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentPrimary,
                        ),
                      ),
                      loading: () => const Text(
                        '...',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentPrimary,
                        ),
                      ),
                      error: (_, _) => const Text(
                        '0',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Estado de sincronización
          if (SupabaseConfig.isConfigured) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Icon(
                    syncState.status == SyncStatus.offline
                        ? Icons.cloud_off
                        : syncState.status == SyncStatus.syncing
                            ? Icons.sync
                            : Icons.cloud_done,
                    color: syncState.status == SyncStatus.offline
                        ? AppTheme.warning
                        : syncState.status == SyncStatus.error
                            ? AppTheme.error
                            : AppTheme.success,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          syncState.status == SyncStatus.offline
                              ? 'Sin conexión'
                              : syncState.status == SyncStatus.syncing
                                  ? 'Sincronizando...'
                                  : syncState.status == SyncStatus.error
                                      ? 'Error de sincronización'
                                      : 'Conectado',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (syncState.lastSync != null)
                          Text(
                            'Última sync: ${DateFormat('dd/MM HH:mm').format(syncState.lastSync!)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Sección Flota
          const Text(
            'Flota',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.accentPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.security,
            title: 'Seguro de la flota',
            subtitle: hasVehicles
                ? 'Asignar compañía y vencimiento a varios vehículos'
                : 'Sin vehículos cargados',
            trailing:
                const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            onTap: hasVehicles
                ? () => showFleetInsuranceSheet(context, ref)
                : null,
          ),
          const SizedBox(height: 32),

          // Sección Sincronización
          const Text(
            'Sincronización',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.accentPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // Sincronizar ahora
          _SettingsTile(
            icon: Icons.sync,
            title: 'Sincronizar ahora',
            subtitle: SupabaseConfig.isConfigured
                ? 'Descargar últimos cambios desde la nube'
                : 'Supabase no configurado',
            trailing: _isSyncing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            onTap: !SupabaseConfig.isConfigured || _isSyncing ? null : _syncNow,
          ),

          // Cambios locales que todavía no llegaron a la nube
          if (queueCounts != null && !queueCounts.isEmpty) ...[
            const SizedBox(height: 12),
            if (queueCounts.pending > 0)
              _SettingsTile(
                icon: Icons.cloud_upload_outlined,
                title: queueCounts.pending == 1
                    ? '1 cambio pendiente de sincronizar'
                    : '${queueCounts.pending} cambios pendientes de sincronizar',
                subtitle: 'Se suben automáticamente al reconectar',
              ),
            if (queueCounts.failed > 0) ...[
              const SizedBox(height: 12),
              _SettingsTile(
                icon: Icons.error_outline,
                title: queueCounts.failed == 1
                    ? '1 cambio no se pudo sincronizar'
                    : '${queueCounts.failed} cambios no se pudieron sincronizar',
                subtitle: 'Tocá para reintentar',
                trailing:
                    const Icon(Icons.refresh, color: AppTheme.warning),
                onTap: () =>
                    ref.read(syncServiceProvider.notifier).retryFailedItems(),
              ),
            ],
          ],
          const SizedBox(height: 32),

          // Sección Info
          const Text(
            'Información',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.accentPrimary,
            ),
          ),
          const SizedBox(height: 12),

          _SettingsTile(
            icon: Icons.info_outline,
            title: 'Acerca de',
            subtitle: 'Versión 1.0.0',
            onTap: () => _showAbout(context),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _syncNow() async {
    setState(() => _isSyncing = true);

    try {
      await ref.read(syncServiceProvider.notifier).fullSync();
      await ref.read(vehicleNotifierProvider.notifier).refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sincronización completada'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo sincronizar. Probá de nuevo.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accentPrimary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.directions_car,
                color: AppTheme.accentPrimary,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Gestor de Vehículos'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Versión 1.0.0'),
            SizedBox(height: 16),
            Text(
              'Aplicación para gestionar vehículos de la empresa, '
              'organizados por provincia y ciudad de Argentina.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Con sincronización en la nube mediante Supabase.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accentPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.accentPrimary, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
