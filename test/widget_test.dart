import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gestor_vehiculos/main.dart';
import 'package:gestor_vehiculos/presentation/providers/theme_mode_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    // La app lee config vía dotenv; en test la cargamos vacía para que no lance
    // NotInitializedError y corra en modo sin backend (no dispara sync/realtime).
    dotenv.testLoad(fileInput: '');
  });

  testWidgets('La app construye sin crashear', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const GestorVehiculosApp(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
