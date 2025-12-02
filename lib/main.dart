import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/guest_mode_provider.dart';
import 'screens/login_screen.dart';
import 'screens/welcome_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  // Inicializar el binding de Flutter
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(
    const ProviderScope(
      child: TuGuiApp(),
    ),
  );
}

/// Aplicación principal TuGuiApp
class TuGuiApp extends ConsumerStatefulWidget {
  const TuGuiApp({super.key});

  @override
  ConsumerState<TuGuiApp> createState() => _TuGuiAppState();
}

class _TuGuiAppState extends ConsumerState<TuGuiApp> {
  // Key único que cambia cuando se hace logout para forzar reinicio completo
  Key _appKey = UniqueKey();
  bool _themeLoaded = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // Cargar preferencia de tema una sola vez
    if (!_themeLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(themeModeProvider.notifier).loadOnce();
        _themeLoaded = true;
      });
    }
    
    final themeMode = ref.watch(themeModeProvider);
    
    // Escuchar cambios de autenticación para reiniciar la app cuando se hace logout
    // Esto debe estar en build, no en initState
    ref.listen(authStateChangesProvider, (previous, next) {
      next.whenData((user) {
        // Si había un usuario antes y ahora no hay usuario, reiniciar la app
        if (previous?.value != null && user == null) {
          // Cambiar el key para forzar reconstrucción completa
          if (mounted) {
            setState(() {
              _appKey = UniqueKey();
            });
          }
        }
      });
    });
    
    return MaterialApp(
      key: _appKey, // Key único que cambia en logout para reiniciar la app
      title: 'TuGuiApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const _RootRouter(),
    );
  }
}

class _RootRouter extends ConsumerStatefulWidget {
  const _RootRouter();

  @override
  ConsumerState<_RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends ConsumerState<_RootRouter> {
  String? _lastUserId;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateChangesProvider);
    final isGuestMode = ref.watch(guestModeProvider);
    
    return authState.when(
      data: (user) {
        // PRIORIDAD 1: Si no hay usuario, mostrar LoginScreen directamente
        // Esto evita que se cargue cualquier otra pantalla que pueda inicializar Mapbox
        if (user == null) {
          // Si estaba en modo invitado, desactivarlo
          if (isGuestMode) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ref.read(guestModeProvider.notifier).disableGuestMode();
              }
            });
          }
          // Resetear el estado cuando no hay usuario
          if (_lastUserId != null) {
            _lastUserId = null;
          }
          return const LoginScreen();
        }
        
        // Detectar cambio de usuario y actualizar estado
        final currentUserId = user.uid;
        if (_lastUserId != currentUserId) {
          // Actualizar inmediatamente
          if (mounted) {
            setState(() {
              _lastUserId = currentUserId;
              // Desactivar modo invitado si está activo
              if (isGuestMode) {
                ref.read(guestModeProvider.notifier).disableGuestMode();
              }
            });
          }
        }
        
        // Si hay usuario autenticado, siempre mostrar WelcomeScreen
        return const WelcomeScreen();
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}
