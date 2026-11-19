import 'package:flutter/material.dart';

import '../../../core/theme/app_tone.dart';
import '../../../data/services/sync_service.dart';

/// Ícono, tono y texto de cada estado de sincronización. Un error nunca usa
/// `cloud_done` (antes se veía "Error de sincronización" con la nube tildada).
({IconData icon, Tone tone, String label}) syncStatusView(SyncStatus status) =>
    switch (status) {
      SyncStatus.offline => (
          icon: Icons.cloud_off_rounded,
          tone: Tone.warning,
          label: 'Sin conexión',
        ),
      SyncStatus.syncing => (
          icon: Icons.sync_rounded,
          tone: Tone.info,
          label: 'Sincronizando…',
        ),
      SyncStatus.error => (
          icon: Icons.sync_problem_rounded,
          tone: Tone.danger,
          label: 'No se pudo sincronizar',
        ),
      SyncStatus.success || SyncStatus.idle => (
          icon: Icons.cloud_done_rounded,
          tone: Tone.success,
          label: 'Sincronizado',
        ),
    };
