import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_vehiculos/presentation/providers/theme_mode_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> containerWithSaved(Map<String, Object> saved) async {
  SharedPreferences.setMockInitialValues(saved);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('sin preferencia guardada arranca en oscuro', () async {
    final container = await containerWithSaved({});

    expect(container.read(themeModeProvider), ThemeMode.dark);
  });

  test('lee el tema guardado', () async {
    final container = await containerWithSaved({'theme_mode': 'light'});

    expect(container.read(themeModeProvider), ThemeMode.light);
  });

  test('un valor desconocido cae en oscuro', () async {
    final container = await containerWithSaved({'theme_mode': 'sepia'});

    expect(container.read(themeModeProvider), ThemeMode.dark);
  });

  test('elegir un tema lo aplica y lo persiste', () async {
    final container = await containerWithSaved({});

    await container.read(themeModeProvider.notifier).select(ThemeMode.system);

    expect(container.read(themeModeProvider), ThemeMode.system);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'system');
  });
}
