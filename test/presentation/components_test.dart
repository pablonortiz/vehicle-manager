import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_vehiculos/core/constants/vehicle_constants.dart';
import 'package:gestor_vehiculos/core/theme/app_theme.dart';
import 'package:gestor_vehiculos/presentation/providers/connectivity_provider.dart';
import 'package:gestor_vehiculos/presentation/widgets/app_sheet.dart';
import 'package:gestor_vehiculos/presentation/widgets/app_snack.dart';
import 'package:gestor_vehiculos/presentation/widgets/offline_banner.dart';
import 'package:gestor_vehiculos/presentation/widgets/plate_text.dart';
import 'package:gestor_vehiculos/presentation/widgets/stat_tile.dart';
import 'package:gestor_vehiculos/presentation/widgets/status_pill.dart';

Widget inApp(Widget child) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('StatTile', () {
    testWidgets('cargando muestra un guion, no un cero', (tester) async {
      await tester.pumpWidget(
        inApp(
          const StatTile(label: 'Total', icon: Icons.directions_car_rounded),
        ),
      );

      expect(find.text('–'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('si falla avisa y no inventa un valor', (tester) async {
      await tester.pumpWidget(
        inApp(
          const StatTile(
            label: 'Total',
            icon: Icons.directions_car_rounded,
            value: '0',
            failed: true,
          ),
        ),
      );

      expect(find.text('–'), findsOneWidget);
      expect(find.text('No se pudo cargar'), findsOneWidget);
    });
  });

  group('StatusPill', () {
    testWidgets('estado del vehículo con ícono y palabra', (tester) async {
      await tester.pumpWidget(
        inApp(StatusPill.vehicle(VehicleStatus.outOfService)),
      );

      expect(find.text('Fuera de servicio'), findsOneWidget);
      expect(find.byIcon(Icons.block_rounded), findsOneWidget);
    });

    testWidgets('vencimiento pasado se marca vencido', (tester) async {
      final lastWeek = DateTime.now().subtract(const Duration(days: 7));
      await tester.pumpWidget(inApp(StatusPill.expiry(lastWeek)));

      expect(find.text('Vencido hace 7 días'), findsOneWidget);
      expect(find.byIcon(Icons.error_rounded), findsOneWidget);
    });
  });

  group('PlateText', () {
    testWidgets('normaliza la patente', (tester) async {
      await tester.pumpWidget(inApp(const PlateText('ae472kp')));

      expect(find.text('AE 472 KP'), findsOneWidget);
    });

    testWidgets('sin patente lo dice', (tester) async {
      await tester.pumpWidget(inApp(const PlateText('  ')));

      expect(find.text('Sin patente'), findsOneWidget);
    });
  });

  group('AppSheet con cambios sin guardar', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.pumpWidget(
        inApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppSheet<void>(
                context,
                enableDrag: false,
                builder: (_) => const AppSheet(
                  title: 'Nueva nota',
                  hasUnsavedChanges: true,
                  child: Text('contenido'),
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'cerrar pide confirmación y "Seguir editando" lo deja abierto',
      (tester) async {
        await openSheet(tester);

        expect(find.text('¿Descartar los cambios?'), findsOneWidget);
        await tester.tap(find.text('Seguir editando'));
        await tester.pumpAndSettle();
        expect(find.text('contenido'), findsOneWidget);
      },
    );

    testWidgets('"Descartar" cierra el sheet', (tester) async {
      await openSheet(tester);

      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      expect(find.text('contenido'), findsNothing);
    });
  });

  group('AppSnack.undoableDelete', () {
    Future<bool? Function()> showUndo(WidgetTester tester) async {
      bool? commit;
      await tester.pumpWidget(
        inApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => commit = await AppSnack.undoableDelete(
                context,
                'Nota eliminada',
              ),
              child: const Text('borrar'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('borrar'));
      await tester.pumpAndSettle();
      return () => commit;
    }

    testWidgets('"Deshacer" cancela el borrado', (tester) async {
      final commit = await showUndo(tester);

      await tester.tap(find.text('Deshacer'));
      await tester.pumpAndSettle();
      expect(commit(), isFalse);
    });

    testWidgets('si vence el snackbar, se borra', (tester) async {
      final commit = await showUndo(tester);

      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();
      expect(commit(), isTrue);
    });
  });

  testWidgets('el banner sin conexión no reinicia el contenido', (
    tester,
  ) async {
    final connectivity = StreamController<bool>();
    addTearDown(connectivity.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isOnlineProvider.overrideWith((ref) => connectivity.stream),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => OfflineBanner(child: child!),
          home: const _Counter(),
        ),
      ),
    );
    await tester.tap(find.text('0'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    connectivity.add(false);
    await tester.pump();
    expect(find.textContaining('Sin conexión'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    connectivity.add(true);
    await tester.pump();
    expect(find.textContaining('Sin conexión'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => setState(() => taps++),
        child: Text('$taps'),
      ),
    ),
  );
}
