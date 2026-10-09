import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../main.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'preo_hmanuales_screen.dart';
import 'preo_pistola_screen.dart';
import 'preo_bomba_screen.dart';
import 'cinco_s_screen.dart';
import 'condicion_salud_screen.dart';

class ValidacionSeguridadScreen extends StatefulWidget {
  final Map<String, dynamic> datosEmpleado;
  const ValidacionSeguridadScreen({super.key, required this.datosEmpleado});

  @override
  State<ValidacionSeguridadScreen> createState() => _ValidacionSeguridadScreenState();
}

class _ValidacionSeguridadScreenState extends State<ValidacionSeguridadScreen> {
  bool _cargandoValidacion = true;

  bool _preoManualesHecho = false;
  bool _preoPistolaHecha = false;
  bool _preoBombaHecha = false;
  bool _cincoSHecho = false;
  bool _condicionSaludHecha = false;

  late String _nombreAuxiliar;
  late String _fechaHoy;

  @override
  void initState() {
    super.initState();
    _nombreUsuario();

    // 🇨🇴 FECHA FIJADA A HORA COLOMBIA (UTC-5)
    _fechaHoy = DateTime.now().toUtc().subtract(const Duration(hours: 5)).toString().substring(0, 10);
    _validarPreoperacionalesHoy();
  }

  void _nombreUsuario() {
    _nombreAuxiliar = (widget.datosEmpleado['nombre'] ??
        widget.datosEmpleado['Nombre'] ??
        widget.datosEmpleado['usuario'] ??
        '')
        .toString()
        .trim();
  }

  Future<void> _validarPreoperacionalesHoy() async {
    setState(() => _cargandoValidacion = true);

    try {
      // 🛠️ Los 3 primeros reportes están en el esquema principal (ApiService.schema)
      final bool manuales = await _verificarModulo(ApiService.schema, 'estibas_herramientas_manuales');
      final bool pistola = await _verificarModulo(ApiService.schema, 'estibas_pistolas');
      final bool bomba = await _verificarModulo(ApiService.schema, 'estibas_bomba');

      // 🚨 CAMBIO IMPORTANTE: 5S y Salud están en el esquema 'gestion'
      // Y la tabla de 5S se llama exactamente '5s_ol'
      final bool cincoS = await _verificarModulo('gestion', '5s_ol');
      final bool salud = await _verificarModulo('gestion', 'condicion_de_salud');

      if (mounted) {
        setState(() {
          _preoManualesHecho = manuales;
          _preoPistolaHecha = pistola;
          _preoBombaHecha = bomba;
          _cincoSHecho = cincoS;
          _condicionSaludHecha = salud;
          _cargandoValidacion = false;
        });

        // 🔓 DESBLOQUEO SI LOS 5 REPORTES ESTÁN COMPLETOS
        if (_preoManualesHecho &&
            _preoPistolaHecha &&
            _preoBombaHecha &&
            _cincoSHecho &&
            _condicionSaludHecha) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PantallaMenu(datosEmpleado: widget.datosEmpleado),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _cargandoValidacion = false);
    }
  }

  Future<bool> _verificarModulo(String esquema, String tabla) async {
    try {
      final url = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/consultar/$esquema/$tabla');
      final res = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'x-api-key': ApiService.apiKey,
      });

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        List<dynamic> registros = [];

        // 🛡️ REGLA INTELIGENTE DE LECTURA (Evita el choque fatal)
        if (decoded is List) {
          registros = decoded;
        } else if (decoded is Map<String, dynamic> && decoded['data'] != null) {
          registros = decoded['data'] is List ? decoded['data'] : [];
        }

        return registros.any((reg) {
          // 📅 Buscamos la fecha en cualquier columna posible, priorizando 'fecha'
          String fechaReg = (
              reg['fecha'] ??
                  reg['fecha_auditoria'] ??
                  reg['fecha_registro'] ??
                  reg['fecha_reporte'] ??
                  reg['timestamp_registro'] ??
                  ''
          ).toString();

          if (fechaReg.length >= 10) {
            fechaReg = fechaReg.substring(0, 10);
          }

          // 👤 Buscamos el nombre del operario en cualquier columna posible
          String auxReg = (
              reg['auxiliar'] ??
                  reg['operario'] ??
                  reg['nombre'] ??
                  reg['auditor'] ??
                  reg['usuario'] ??
                  reg['empleado'] ??
                  reg['evaluador'] ??
                  ''
          ).toString().trim();

          return fechaReg == _fechaHoy && auxReg.toLowerCase() == _nombreAuxiliar.toLowerCase();
        });
      }
    } catch (e) {
      debugPrint('Error verificando $esquema.$tabla: $e');
    }
    return false;
  }

  void _abrirPantalla(Widget pantalla) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => pantalla),
    );
    _validarPreoperacionalesHoy();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoValidacion) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF0D47A1)),
              SizedBox(height: 15),
              Text(
                'Validando reportes del día...',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
              )
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFE9ECEF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield_rounded,
                        color: Color(0xFFE53935),
                        size: 55,
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      '¡Acción Requerida!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      'Completa tus 5 reportes obligatorios de seguridad y preoperacionales con fecha de hoy ($_fechaHoy) para desbloquear el sistema.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),

                    _buildBotonReporte(
                      titulo: 'Preop. H. Manuales',
                      icono: Icons.build_rounded,
                      color: const Color(0xFFE65100),
                      completado: _preoManualesHecho,
                      onTap: () => _abrirPantalla(PreoHManualesScreen(datosEmpleado: widget.datosEmpleado)),
                    ),
                    const SizedBox(height: 10),

                    _buildBotonReporte(
                      titulo: 'Preop. Pistola Neumática',
                      icono: Icons.air_rounded,
                      color: const Color(0xFF37474F),
                      completado: _preoPistolaHecha,
                      onTap: () => _abrirPantalla(PreoPistolaScreen(datosEmpleado: widget.datosEmpleado)),
                    ),
                    const SizedBox(height: 10),

                    _buildBotonReporte(
                      titulo: 'Preop. Bomba de presion de aire',
                      icono: Icons.invert_colors_rounded,
                      color: const Color(0xFF0D47A1),
                      completado: _preoBombaHecha,
                      onTap: () => _abrirPantalla(PreoBombaScreen(datosEmpleado: widget.datosEmpleado)),
                    ),
                    const SizedBox(height: 10),

                    _buildBotonReporte(
                      titulo: 'Inspección 5S',
                      icono: Icons.fact_check_outlined,
                      color: const Color(0xFF2E7D32),
                      completado: _cincoSHecho,
                      onTap: () => _abrirPantalla(CincoSScreen(datosEmpleado: widget.datosEmpleado)),
                    ),
                    const SizedBox(height: 10),

                    _buildBotonReporte(
                      titulo: 'Condición de Salud',
                      icono: Icons.health_and_safety_outlined,
                      color: const Color(0xFF00796B),
                      completado: _condicionSaludHecha,
                      onTap: () => _abrirPantalla(CondicionSaludScreen(datosEmpleado: widget.datosEmpleado)),
                    ),
                    const SizedBox(height: 25),

                    TextButton.icon(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                        );
                      },
                      icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 18),
                      label: const Text(
                        'Cerrar Sesión',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBotonReporte({
    required String titulo,
    required IconData icono,
    required Color color,
    required bool completado,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: completado ? Colors.green.shade600 : color,
          foregroundColor: Colors.white,
          elevation: completado ? 0 : 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: completado ? null : onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(completado ? Icons.check_circle_rounded : icono, size: 20),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                completado ? '$titulo (LISTO)' : titulo,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}