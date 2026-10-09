import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import 'validacion_seguridad_screen.dart'; // 👈 NUEVO: Redirección con bloqueo diario

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usuarioController = TextEditingController();
  final _passwordController = TextEditingController();

  final LocalAuthentication _auth = LocalAuthentication();
  bool _isLoading = false;
  bool _obscurePassword = true;

  // 🚀 AUTENTICACIÓN POR HUELLA
  Future<void> _autenticarConHuella() async {
    final prefs = await SharedPreferences.getInstance();
    final usrGuardado = prefs.getString('saved_user');
    final passGuardado = prefs.getString('saved_pass');

    if (usrGuardado == null || passGuardado == null) {
      _mostrarError('Inicia sesión manualmente la primera vez para registrar tu huella.');
      return;
    }

    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();

      if (!canCheck && !isSupported) {
        _mostrarError('El teléfono no tiene sensor de huella activo o configurado.');
        return;
      }

      final autenticado = await _auth.authenticate(
        localizedReason: 'Toca el sensor de huella para iniciar sesión',
        options: const AuthenticationOptions(
          stickyAuth: true,
          useErrorDialogs: true,
          biometricOnly: false,
        ),
      );

      if (autenticado) {
        _usuarioController.text = usrGuardado;
        _passwordController.text = passGuardado;
        await _iniciarSesion();
      }
    } on PlatformException catch (e) {
      debugPrint('Error de huella (${e.code}): ${e.message}');
      if (e.code == 'NotEnrolled') {
        _mostrarError('No hay huellas registradas en los Ajustes del celular.');
      } else if (e.code == 'LockedOut' || e.code == 'PermanentlyLockedOut') {
        _mostrarError('Sensor bloqueado por intentos fallidos. Usa tu PIN.');
      } else {
        _mostrarError('Lectura cancelada o no disponible.');
      }
    }
  }

  // 🔐 INICIO DE SESIÓN Y REDIRECCIÓN A VALIDACIÓN
  Future<void> _iniciarSesion() async {
    final usuarioTexto = _usuarioController.text.trim();
    final passwordTexto = _passwordController.text.trim();

    if (usuarioTexto.isEmpty || passwordTexto.isEmpty) {
      _mostrarError('Por favor, ingresa tu usuario y contraseña.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/consultar/${ApiService.schema}/estibas_usaurios');

      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'x-api-key': ApiService.apiKey,
      });

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List items = [];

        // 🛡️ REGLA INTELIGENTE DE LECTURA (Evita el choque fatal de Dart)
        if (decoded is List) {
          items = decoded;
        } else if (decoded is Map<String, dynamic> && decoded['data'] != null) {
          items = decoded['data'] is List ? decoded['data'] : [];
        }

        final usuarioEncontrado = items.firstWhere(
              (item) =>
          (item['usuario'] ?? '').toString().trim() == usuarioTexto &&
              (item['contraseña'] ?? '').toString().trim() == passwordTexto,
          orElse: () => null,
        );

        if (usuarioEncontrado != null) {
          // 💾 Guardar credenciales para la huella digital
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('saved_user', usuarioTexto);
          await prefs.setString('saved_pass', passwordTexto);

          if (!mounted) return;

          // 🔒 REDIRECCIÓN AL BLOQUEO DE VALIDACIÓN DE SEGURIDAD
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ValidacionSeguridadScreen(
                datosEmpleado: Map<String, dynamic>.from(usuarioEncontrado),
              ),
            ),
          );
        } else {
          final existeUsuario = items.any((item) => (item['usuario'] ?? '').toString().trim() == usuarioTexto);
          if (existeUsuario) {
            _mostrarError('Contraseña incorrecta.');
          } else {
            _mostrarError('El usuario no existe.');
          }
        }
      } else {
        _mostrarError('Error de servidor (${response.statusCode}).');
      }
    } catch (e) {
      debugPrint('Error de login: $e');
      _mostrarError('Fallo de conexión. Revisa tu internet.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: SafeArea(
        child: SingleChildScrollView(
          child: SizedBox(
            height: size.height - MediaQuery.of(context).padding.top,
            child: Column(
              children: [
                // CABECERA CURVA Y LOGO
                Container(
                  width: double.infinity,
                  height: size.height * 0.35,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(50),
                      bottomRight: Radius.circular(50),
                    ),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_rounded, size: 80, color: Colors.white),
                      SizedBox(height: 15),
                      Text('REPARACIÓN DE ESTIBAS', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      SizedBox(height: 5),
                      Text('Sistema de Gestión Operativa', style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 0.5)),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // TARJETA DEL FORMULARIO DE LOGIN
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Iniciar Sesión', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF263238))),
                        const SizedBox(height: 25),

                        TextField(
                          controller: _usuarioController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Usuario (Cédula)',
                            prefixIcon: const Icon(Icons.person, color: Color(0xFF0D47A1)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: const Color(0xFFF8F9FA),
                          ),
                        ),
                        const SizedBox(height: 20),

                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(Icons.lock, color: Color(0xFF0D47A1)),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: const Color(0xFFF8F9FA),
                          ),
                        ),
                        const SizedBox(height: 35),

                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D47A1),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 5,
                            ),
                            onPressed: _isLoading ? null : _iniciarSesion,
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text('INGRESAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                          ),
                        ),

                        const SizedBox(height: 25),
                        const Center(child: Text('O ingresa con tu huella', style: TextStyle(color: Colors.grey, fontSize: 13))),
                        const SizedBox(height: 10),
                        Center(
                          child: InkWell(
                            onTap: _autenticarConHuella,
                            borderRadius: BorderRadius.circular(50),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFE3F2FD),
                                border: Border.all(color: const Color(0xFF0D47A1).withValues(alpha: 0.3), width: 1.5),
                              ),
                              child: const Icon(Icons.fingerprint_rounded, size: 38, color: Color(0xFF0D47A1)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    children: [
                      Icon(Icons.code_rounded, color: Colors.grey[400], size: 20),
                      const SizedBox(height: 5),
                      Text('Desarrollado por: Gerardo Rodriguez', style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usuarioController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}