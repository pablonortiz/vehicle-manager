import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/router.dart';
import 'data/services/db_change_service.dart';
import 'data/services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar sqflite para desktop (Windows/Linux/macOS)
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  // Cargar variables de entorno
  await dotenv.load(fileName: '.env');
  
  // Inicializar locale para fechas en español
  await initializeDateFormatting('es', null);
  
  // Inicializar Supabase (solo si está configurado)
  if (SupabaseConfig.isConfigured) {
    try {
      await SupabaseConfig.initialize();
    } catch (e) {
      debugPrint('Error inicializando Supabase: $e');
    }
  }
  
  // Configurar barra de estado transparente
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    const ProviderScope(
      child: GestorVehiculosApp(),
    ),
  );
}

class GestorVehiculosApp extends ConsumerStatefulWidget {
  const GestorVehiculosApp({super.key});

  @override
  ConsumerState<GestorVehiculosApp> createState() => _GestorVehiculosAppState();
}

class _GestorVehiculosAppState extends ConsumerState<GestorVehiculosApp> {
  @override
  void initState() {
    super.initState();
    // Sincronizar datos y suscribirse a cambios en tiempo real
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (SupabaseConfig.isConfigured) {
        ref.read(syncServiceProvider.notifier).fullSync();
        DbChangeService.instance.onRemoteChange = () {
          ref.read(syncServiceProvider.notifier).fullSync();
        };
        DbChangeService.instance.startRealtimeSubscription();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Gestor de Vehículos',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
      locale: const Locale('es', 'ES'),
      supportedLocales: const [
        Locale('es', 'ES'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return MediaQuery(
          // Asegurar que el texto no se escale demasiado
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child!,
        );
      },
    );
  }
}
