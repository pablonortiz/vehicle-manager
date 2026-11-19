import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_vehiculos/core/theme/app_tone.dart';
import 'package:gestor_vehiculos/data/services/sync_service.dart';
import 'package:gestor_vehiculos/presentation/screens/settings/sync_status_view.dart';

void main() {
  test('un error de sincronización no se muestra con la nube tildada', () {
    final view = syncStatusView(SyncStatus.error);
    expect(view.icon, isNot(Icons.cloud_done_rounded));
    expect(view.tone, Tone.danger);
    expect(view.label, 'No se pudo sincronizar');
  });

  test('cada estado tiene su ícono y su tono', () {
    expect(syncStatusView(SyncStatus.offline).tone, Tone.warning);
    expect(syncStatusView(SyncStatus.syncing).icon, Icons.sync_rounded);
    expect(syncStatusView(SyncStatus.success).icon, Icons.cloud_done_rounded);
    expect(syncStatusView(SyncStatus.idle).tone, Tone.success);
  });
}
