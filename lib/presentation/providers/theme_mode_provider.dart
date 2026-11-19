import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Se sobreescribe en `main()` con la instancia ya cargada, así el tema
/// guardado aplica desde el primer frame.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider sin override'),
);

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(ref.watch(sharedPreferencesProvider)),
);

/// Tema elegido en Ajustes (Sistema, Claro u Oscuro); por defecto, Oscuro.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const _key = 'theme_mode';
  final SharedPreferences _prefs;

  ThemeModeNotifier(this._prefs)
      : super(ThemeMode.values.asNameMap()[_prefs.getString(_key)] ??
            ThemeMode.dark);

  Future<void> select(ThemeMode mode) async {
    state = mode;
    await _prefs.setString(_key, mode.name);
  }
}
