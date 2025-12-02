import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import 'splash_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const String _hasSeenWelcomeKey = 'has_seen_welcome';

  /// Verifica si el usuario ya vio la pantalla de bienvenida
  static Future<bool> hasSeenWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSeenWelcomeKey) ?? false;
  }

  /// Marca que el usuario ya vio la pantalla de bienvenida
  static Future<void> markWelcomeAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenWelcomeKey, true);
  }

  void _onStartPressed(BuildContext context) async {
    await markWelcomeAsSeen();
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const SplashScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.darkBlue,
              AppColors.mediumBlue,
              AppColors.lightBlue,
              AppColors.cyan,
              AppColors.teal,
              AppColors.brightGreen,
            ],
            stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Título
                const Text(
                  'Bienvenido a',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w300,
                    color: AppColors.white,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'TuGuiApp',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                    letterSpacing: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                // Texto principal
                const Text(
                  'TuGuiApp es tu guía rápida y segura para realizar trámites legales y administrativos, aquí podrás buscar el trámite que necesitas, conocer la entidad exacta donde debes acudir y recibir información completa sobre requisitos, horarios de atención y el procedimiento a seguir. Además, tendrás acceso a asesoría jurídica confiable que te orientará en cada etapa, evitando confusiones, pérdida de tiempo o visitas innecesarias.',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: AppColors.white,
                    fontWeight: FontWeight.normal,
                  ),
                  textAlign: TextAlign.justify,
                ),
                const SizedBox(height: 32),
                // Texto de cierre
                const Text(
                  'EXPLORA, INFÓRMATE Y AVANZA CON CLARIDAD. ESTAMOS AQUÍ PARA AYUDARTE EN CADA TRÁMITE.',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                    letterSpacing: 0.5,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 60),
                // Botón Empezar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _onStartPressed(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.white,
                      foregroundColor: AppColors.darkBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: const Text(
                      'Empezar',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

