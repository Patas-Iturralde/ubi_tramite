import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'config/mapbox_config.dart';
import 'screens/map_screen.dart';

void main() {
  // Inicializar el binding de Flutter
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar Mapbox con el token de acceso
  MapboxOptions.setAccessToken(MapboxConfig.accessToken);
  
  runApp(
    const ProviderScope(
      child: UbiTramiteApp(),
    ),
  );
}

/// Aplicación principal UbiTrámite
class UbiTramiteApp extends StatelessWidget {
  const UbiTramiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UbiTrámite',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 2,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 2,
        ),
      ),
      home: const MapScreen(),
    );
  }
}
