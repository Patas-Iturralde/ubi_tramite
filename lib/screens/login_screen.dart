import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _acceptedTerms = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isLogin && !_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes aceptar los términos y condiciones para continuar'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      if (_isLogin) {
        await AuthService.signInWithEmail(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );
        // El router automáticamente detectará el cambio de autenticación
        // y navegará a la pantalla correspondiente
      } else {
        await AuthService.registerWithEmail(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
          displayName: _nameCtrl.text.trim().isNotEmpty
              ? _nameCtrl.text.trim()
              : null,
        );
        // El router automáticamente detectará el cambio de autenticación
        // y navegará a la pantalla correspondiente
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMessage = 'Error al autenticarse';
        switch (e.code) {
          case 'user-not-found':
            errorMessage = 'No existe una cuenta con este correo';
            break;
          case 'wrong-password':
            errorMessage = 'Contraseña incorrecta';
            break;
          case 'email-already-in-use':
            errorMessage = 'Este correo ya está registrado';
            break;
          case 'weak-password':
            errorMessage = 'La contraseña es muy débil';
            break;
          case 'invalid-email':
            errorMessage = 'Correo electrónico inválido';
            break;
          case 'user-disabled':
            errorMessage = 'Esta cuenta ha sido deshabilitada';
            break;
          case 'too-many-requests':
            errorMessage = 'Demasiados intentos. Intenta más tarde';
            break;
          case 'operation-not-allowed':
            errorMessage = 'Operación no permitida';
            break;
          default:
            errorMessage = e.message ?? 'Error desconocido';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString().replaceAll('Exception: ', '').replaceAll('[firebase_auth]', '').trim()}',
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _nameCtrl.clear();
      _emailCtrl.clear();
      _passwordCtrl.clear();
      _acceptedTerms = false;
    });
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Términos y Condiciones de uso de TuGuiApp',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTermsSection('1. ACEPTACIÓN DE LOS TÉRMINOS',
                  'Al acceder o utilizar la aplicación móvil TuGuiApp, usted (el "Usuario") acepta estar legalmente obligado por los presentes Términos y Condiciones ("Términos"). Si no está de acuerdo con estos Términos, no debe usar la Aplicación.'),
              _buildTermsSection('2. OBJETO DE LA APLICACIÓN',
                  'TuGuiApp es una plataforma que ofrece información de carácter general y orientativo sobre trámites legales y administrativos, esta información se limita a proporcionar:\n\n• Requisitos específicos necesarios para la realización de un trámite.\n• Horarios de atención de la entidad pública o privada competente.\n• Costos o tarifas asociados al procedimiento.'),
              _buildTermsSection('3. REGISTRO Y ACCESO',
                  'Para utilizar los servicios de la Aplicación, el Usuario debe registrarse y proporcionar información veraz, completa y actualizada. El Usuario es responsable de la confidencialidad de sus credenciales de acceso y del uso de su cuenta. Los Administradores se reservan el derecho de suspender o eliminar cuentas que incumplan los presentes Términos, proporcionen información falsa o utilicen la plataforma con fines indebidos.'),
              _buildTermsSection('4. TARIFAS Y PAGOS',
                  'Algunos servicios y contenidos ofrecidos por la aplicación pueden estar sujetos al pago de tarifas. Estas tarifas serán informadas previamente al Usuario de manera clara.\n\nLas tarifas pagadas no son reembolsables, salvo que expresamente se indique lo contrario en casos específicos de cancelación del servicio por parte de la Administradora.'),
              _buildTermsSection('5. RESPONSABILIDADES DEL USUARIO',
                  'El Usuario se compromete a:\n\n• Proporcionar información precisa, veraz y actualizada en el registro y durante el uso de la Aplicación.\n• Utilizar la Aplicación únicamente para fines lícitos y de conformidad con estos Términos.\n• No utilizar la plataforma para cargar, publicar o transmitir contenido ilegal, difamatorio, obsceno o que viole los derechos de terceros.\n• Mantener la confidencialidad de sus credenciales y notificar inmediatamente a los Administradores cualquier uso no autorizado de su cuenta.'),
              _buildTermsSection('6. PROPIEDAD INTELECTUAL',
                  'Todos los contenidos, diseños, gráficos, logos y el software de TuGuiApp son propiedad exclusiva de los Administradores de la Aplicación. Se prohíbe el uso, copia, reproducción, modificación o distribución no autorizada de dicho contenido.'),
              _buildTermsSection('7. PROTECCIÓN DE DATOS PERSONALES',
                  'TuGuiApp recolecta y trata datos personales conforme a lo establecido en la Ley Orgánica de Protección de Datos Personales de Ecuador.\n\nFinalidades del tratamiento:\n• Gestión de usuarios registrados.\n• Envío de información relevante (notificaciones, actualizaciones, oportunidades).\n• Estadísticas y mejoras del servicio.\n\nDerechos del titular de los datos:\n• El usuario podrá ejercer sus derechos de acceso, rectificación y eliminación de sus datos ante los Administradores de la Aplicación.\n• Los datos no serán compartidos con terceros sin conocimiento expreso, salvo obligación legal.'),
              _buildTermsSection('8. MODIFICACIONES DE LOS TÉRMINOS',
                  'Nos reservamos el derecho de modificar estos términos en cualquier momento. Se le notificará sobre cualquier cambio importante a través de la aplicación o por otros medios. El uso continuado de la Aplicación después de dichas modificaciones constituye su aceptación de los nuevos términos.'),
              _buildTermsSection('9. SOLUCIÓN DE CONTROVERSIAS',
                  'En caso de controversias relacionadas con el uso de la Aplicación, las partes acuerdan:\n\n• Buscar una solución amistosa mediante mediación administrada por un centro debidamente acreditado.\n• Si la mediación no resulta exitosa en un plazo de 30 días, la controversia se resolverá mediante arbitraje en derecho, conforme a la Ley de Arbitraje y Mediación del Ecuador.\n• El tribunal arbitral estará compuesto por tres árbitros: uno designado por la parte demandante, otro por la parte demandada, y el tercero elegido por sorteo entre árbitros inscritos en el centro de arbitraje seleccionado.\n• El laudo arbitral será definitivo, obligatorio e inapelable.'),
              _buildTermsSection('10. LEY APLICABLE Y JURISDICCIÓN',
                  'Estos Términos se rigen por las leyes de la República del Ecuador. En todo lo no previsto, se aplicarán las disposiciones del Código Civil, Código de Comercio, Ley de Protección de Datos Personales, Ley de Arbitraje y Mediación, y demás normas aplicables.'),
              _buildTermsSection('11. CONTACTO',
                  'Para consultas, sugerencias o ejercicio de derechos en materia de protección de datos, puede contactarse a:\n\nTuGuiApp: 💌 tuguiapp1@gmail.com'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
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
            ],
            stops: [0.0, 0.25, 0.5, 0.75, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 32,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        // Logo/Título
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.account_circle,
                            size: 80,
                            color: AppColors.white,
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Título
                        Text(
                          _isLogin ? 'Bienvenido' : 'Crear cuenta',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isLogin
                              ? 'Inicia sesión para continuar'
                              : 'Regístrate para comenzar',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.white.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 40),
                        // Campo de nombre (solo en registro)
                        if (!_isLogin) ...[
                          _buildTextField(
                            controller: _nameCtrl,
                            label: 'Nombre completo',
                            icon: Icons.person_outline,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'El nombre es requerido'
                                : null,
                          ),
                          const SizedBox(height: 20),
                        ],
                        // Campo de email
                        _buildTextField(
                          controller: _emailCtrl,
                          label: 'Correo electrónico',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) => (v == null || !v.contains('@'))
                              ? 'Ingresa un email válido'
                              : null,
                        ),
                        const SizedBox(height: 20),
                        // Campo de contraseña
                        _buildTextField(
                          controller: _passwordCtrl,
                          label: 'Contraseña',
                          icon: Icons.lock_outline,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppColors.white.withOpacity(0.7),
                            ),
                            onPressed: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          validator: (v) => (v == null || v.length < 6)
                              ? 'Mínimo 6 caracteres'
                              : null,
                        ),
                        // Checkbox de términos y condiciones (solo en registro)
                        if (!_isLogin) ...[
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: _acceptedTerms,
                                onChanged: (value) {
                                  setState(() {
                                    _acceptedTerms = value ?? false;
                                  });
                                },
                                activeColor: AppColors.white,
                                checkColor: AppColors.darkBlue,
                                side: BorderSide(
                                  color: AppColors.white.withOpacity(0.7),
                                  width: 2,
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _acceptedTerms = !_acceptedTerms;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: RichText(
                                      text: TextSpan(
                                        style: TextStyle(
                                          color: AppColors.white.withOpacity(0.9),
                                          fontSize: 13,
                                        ),
                                        children: [
                                          const TextSpan(text: 'Acepto los '),
                                          TextSpan(
                                            text: 'términos y condiciones',
                                            style: TextStyle(
                                              color: AppColors.white,
                                              fontWeight: FontWeight.bold,
                                              decoration: TextDecoration.underline,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _showTermsDialog,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Ver términos',
                                  style: TextStyle(
                                    color: AppColors.white,
                                    fontSize: 12,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 32),
                        // Botón principal
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: (_loading || (!_isLogin && !_acceptedTerms))
                                ? null
                                : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.white,
                              foregroundColor: AppColors.darkBlue,
                              elevation: 8,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(AppColors.darkBlue),
                                    ),
                                  )
                                : Text(
                                    _isLogin ? 'Iniciar sesión' : 'Crear cuenta',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Cambiar modo
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isLogin
                                  ? '¿No tienes cuenta?'
                                  : '¿Ya tienes cuenta?',
                              style: TextStyle(
                                color: AppColors.white.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                            TextButton(
                              onPressed: _loading ? null : _toggleMode,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              child: Text(
                                _isLogin ? 'Regístrate' : 'Inicia sesión',
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: AppColors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.white.withOpacity(0.7)),
        prefixIcon: Icon(icon, color: AppColors.white.withOpacity(0.7)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppColors.white.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppColors.white.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppColors.white,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 1.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 2,
          ),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
    );
  }
}



