import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'services/api_service.dart';

// 🔗 IMPORTACIÓN DE PANTALLAS
import 'screens/login_screen.dart';
import 'screens/registro_screen.dart';
import 'screens/solicitud_insumos_screen.dart';
import 'screens/inventario_estibas_screen.dart';
import 'screens/resultado_dia_screen.dart';
import 'screens/estibas_entregadas_screen.dart';
import 'screens/dashboard_estibas_screen.dart';
import 'screens/podium_screen.dart';
import 'screens/preo_hmanuales_screen.dart';
import 'screens/preo_bomba_screen.dart';
import 'screens/preo_pistola_screen.dart';
import 'screens/historial_preop_screen.dart';
import 'screens/cinco_s_screen.dart';
import 'screens/dashboard_5s_screen.dart';
import 'screens/dashboard_5s_bavaria_screen.dart';
import 'screens/duenos_territorio_screen.dart';
import 'screens/cinco_why_screen.dart';
import 'screens/condicion_salud_screen.dart'; // 👈 IMPORTACIÓN CONDICIÓN DE SALUD

void main() {
  runApp(const ReparacionEstibasApp());
}

class ReparacionEstibasApp extends StatelessWidget {
  const ReparacionEstibasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reparación de Estibas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D47A1),
          primary: const Color(0xFF0D47A1),
          secondary: const Color(0xFF1565C0),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF8F9FA),
          foregroundColor: Colors.black87,
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

class PantallaMenu extends StatefulWidget {
  final Map<String, dynamic>? datosEmpleado;
  const PantallaMenu({super.key, this.datosEmpleado});

  @override
  State<PantallaMenu> createState() => _PantallaMenuState();
}

typedef HomeScreen = PantallaMenu;

class _PantallaMenuState extends State<PantallaMenu> {
  String _mensajeMotivacional = "Hoy es un gran día para dar lo mejor de ti.\n¡Vamos con toda!";

  final List<String> _mensajes = [
    "¡El éxito es la suma de pequeños esfuerzos\nrepetidos día tras día!",
    "Tu dedicación y esfuerzo marcan\nla diferencia en nuestra operación hoy.",
    "La calidad de tu trabajo es el reflejo\nde tu excelencia.",
    "Hoy es un gran día para dar lo mejor de ti.\n¡Vamos con toda!",
    "Los grandes logros nacen de\npersonas comprometidas como tú.",
    "¡Mantén la actitud positiva y el éxito\nte seguirá en cada estiba!",
    "Tu seguridad y tu buen trabajo son\nel motor de esta operación."
  ];

  @override
  void initState() {
    super.initState();
    _mensajeMotivacional = _mensajes[Random().nextInt(_mensajes.length)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Panel Principal',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      drawer: CustomDrawer(datosEmpleado: widget.datosEmpleado ?? {}),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF0D47A1), width: 3.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: const Icon(
                    Icons.inventory_2_rounded,
                    size: 85,
                    color: Color(0xFF0D47A1),
                  ),
                ),
                const SizedBox(height: 25),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF333333),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      )
                    ],
                  ),
                  child: const Text(
                    'REPARACIÓN DE ESTIBAS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 36),
                        const SizedBox(height: 12),
                        Text(
                          _mensajeMotivacional,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF37474F),
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CustomDrawer extends StatefulWidget {
  final Map<String, dynamic> datosEmpleado;
  const CustomDrawer({super.key, required this.datosEmpleado});

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  late String _nombreUsuario;
  String? _fotoUrl;
  bool _subiendoFoto = false;

  @override
  void initState() {
    super.initState();
    _nombreUsuario = (widget.datosEmpleado['nombre'] ?? widget.datosEmpleado['usuario'] ?? 'PLANTA TOCANCIPÁ').toString();
    _fotoUrl = widget.datosEmpleado['foto'] ?? widget.datosEmpleado['foto_url'];
  }

  // 📷 PROCESAR SELECCIÓN Y SUBIDA DE IMAGEN
  Future<void> _procesarSeleccionFoto(ImageSource origen) async {
    final ImagePicker picker = ImagePicker();
    final XFile? imagen = await picker.pickImage(source: origen, imageQuality: 75);

    if (imagen == null) return;

    setState(() => _subiendoFoto = true);

    try {
      final urlSubida = Uri.parse('${ApiService.baseUrl}/archivos/subir');
      var request = http.MultipartRequest('POST', urlSubida);
      request.headers['x-api-key'] = ApiService.apiKey;
      request.files.add(await http.MultipartFile.fromPath('foto_perfil', imagen.path));

      var responseStream = await request.send();
      var response = await http.Response.fromStream(responseStream);

      String urlFinalFoto = imagen.path;

      if (response.statusCode == 200) {
        final resJson = jsonDecode(response.body);
        if (resJson['exito'] == true && resJson['urls'] != null) {
          urlFinalFoto = resJson['urls']['foto_perfil'] ?? imagen.path;
        }
      }

      setState(() {
        _fotoUrl = urlFinalFoto;
        widget.datosEmpleado['foto'] = urlFinalFoto;
        widget.datosEmpleado['foto_url'] = urlFinalFoto;
      });

      final idUsuario = widget.datosEmpleado['id'] ?? widget.datosEmpleado['usuario'];
      if (idUsuario != null) {
        final urlUser = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/actualizar/${ApiService.schema}/usuarios/$idUsuario');
        await http.put(
          urlUser,
          headers: {'Content-Type': 'application/json', 'x-api-key': ApiService.apiKey},
          body: jsonEncode({'foto': urlFinalFoto}),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil actualizada con éxito'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error subiendo imagen: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }

  // 🖼️ MENÚ INFERIOR PARA ELEGIR CÁMARA O GALERÍA
  void _mostrarOpcionesFoto() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(height: 15),
              const Text('Foto de Perfil', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF0D47A1)),
                ),
                title: const Text('Tomar Foto con Cámara', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _procesarSeleccionFoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.purple.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.photo_library_rounded, color: Colors.purple),
                ),
                title: const Text('Seleccionar de la Galería', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _procesarSeleccionFoto(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✏️ DIÁLOGO PARA EDITAR INFORMACIÓN DEL PERFIL
  void _mostrarDialogoEditarPerfil() {
    final nombreCtrl = TextEditingController(text: _nombreUsuario);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: Color(0xFF0D47A1)),
            SizedBox(width: 10),
            Text('Editar Perfil', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nombreCtrl,
              decoration: InputDecoration(
                labelText: 'Nombre del Operario',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.person),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              if (nombreCtrl.text.trim().isNotEmpty) {
                setState(() {
                  _nombreUsuario = nombreCtrl.text.trim().toUpperCase();
                  widget.datosEmpleado['nombre'] = _nombreUsuario;
                });
              }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Información del perfil actualizada')),
              );
            },
            child: const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 🔑 DIÁLOGO PARA CAMBIAR CONTRASEÑA
  void _mostrarDialogoCambiarContrasena() {
    final actualCtrl = TextEditingController();
    final nuevaCtrl = TextEditingController();
    final confirmarCtrl = TextEditingController();

    bool ocultarActual = true;
    bool ocultarNueva = true;
    bool ocultarConfirmar = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.lock_reset_rounded, color: Color(0xFF0D47A1)),
              SizedBox(width: 10),
              Text('Cambiar Contraseña', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: actualCtrl,
                  obscureText: ocultarActual,
                  decoration: InputDecoration(
                    labelText: 'Contraseña Actual',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(ocultarActual ? Icons.visibility_off : Icons.visibility, size: 20),
                      onPressed: () => setStateDialog(() => ocultarActual = !ocultarActual),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nuevaCtrl,
                  obscureText: ocultarNueva,
                  decoration: InputDecoration(
                    labelText: 'Nueva Contraseña',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.lock_open_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(ocultarNueva ? Icons.visibility_off : Icons.visibility, size: 20),
                      onPressed: () => setStateDialog(() => ocultarNueva = !ocultarNueva),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmarCtrl,
                  obscureText: ocultarConfirmar,
                  decoration: InputDecoration(
                    labelText: 'Confirmar Contraseña',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.check_circle_outline),
                    suffixIcon: IconButton(
                      icon: Icon(ocultarConfirmar ? Icons.visibility_off : Icons.visibility, size: 20),
                      onPressed: () => setStateDialog(() => ocultarConfirmar = !ocultarConfirmar),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (actualCtrl.text.isEmpty || nuevaCtrl.text.isEmpty || confirmarCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Todos los campos son obligatorios'), backgroundColor: Colors.orange),
                  );
                  return;
                }
                if (nuevaCtrl.text != confirmarCtrl.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Las contraseñas nuevas no coinciden'), backgroundColor: Colors.red),
                  );
                  return;
                }

                try {
                  final idUsuario = widget.datosEmpleado['id'] ?? widget.datosEmpleado['usuario'];
                  if (idUsuario != null) {
                    final url = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/actualizar/${ApiService.schema}/usuarios/$idUsuario');
                    await http.put(
                      url,
                      headers: {'Content-Type': 'application/json', 'x-api-key': ApiService.apiKey},
                      body: jsonEncode({'password': nuevaCtrl.text.trim()}),
                    );
                  }
                } catch (_) {}

                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contraseña actualizada con éxito'), backgroundColor: Colors.green),
                  );
                }
              },
              child: const Text('Actualizar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  ImageProvider? _obtenerImagenPerfil(String? ruta) {
    if (ruta == null || ruta.isEmpty) return null;
    if (ruta.startsWith('http://') || ruta.startsWith('https://')) {
      return NetworkImage(ruta);
    }
    return FileImage(File(ruta));
  }

  @override
  Widget build(BuildContext context) {
    final imagenPerfil = _obtenerImagenPerfil(_fotoUrl);

    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 50, bottom: 25, left: 20, right: 20),
            decoration: const BoxDecoration(
              color: Color(0xFF0D47A1),
              borderRadius: BorderRadius.only(bottomRight: Radius.circular(50)),
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                        image: imagenPerfil != null
                            ? DecorationImage(
                          image: imagenPerfil,
                          fit: BoxFit.cover,
                        )
                            : null,
                      ),
                      child: _subiendoFoto
                          ? const CircularProgressIndicator(color: Colors.white)
                          : (imagenPerfil == null
                          ? const Icon(Icons.person_rounded, size: 65, color: Colors.white)
                          : null),
                    ),
                    GestureDetector(
                      onTap: _mostrarOpcionesFoto,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565C0),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  _nombreUsuario.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Módulo de Estibas',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 10),
              children: [
                ExpansionTile(
                  leading: const Icon(Icons.manage_accounts_rounded, color: Color(0xFF0D47A1)),
                  title: const Text(
                    'CONFIGURACIÓN Y PERFIL',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D47A1),
                      fontSize: 14,
                    ),
                  ),
                  iconColor: const Color(0xFF0D47A1),
                  collapsedIconColor: const Color(0xFF0D47A1),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.only(left: 35, right: 15),
                      leading: const Icon(Icons.edit_outlined, color: Color(0xFF1565C0), size: 20),
                      title: const Text('Editar Perfil', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      onTap: () {
                        Navigator.pop(context);
                        _mostrarDialogoEditarPerfil();
                      },
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.only(left: 35, right: 15),
                      leading: const Icon(Icons.add_a_photo_outlined, color: Color(0xFF1565C0), size: 20),
                      title: const Text('Cambiar Foto de Perfil', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      onTap: () {
                        Navigator.pop(context);
                        _mostrarOpcionesFoto();
                      },
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.only(left: 35, right: 15),
                      leading: const Icon(Icons.lock_reset_outlined, color: Color(0xFF1565C0), size: 20),
                      title: const Text('Cambiar Contraseña', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      onTap: () {
                        Navigator.pop(context);
                        _mostrarDialogoCambiarContrasena();
                      },
                    ),
                  ],
                ),

                ExpansionTile(
                  leading: const Icon(Icons.inventory_2_outlined, color: Color(0xFF0D47A1)),
                  title: const Text(
                    'OPERACIÓN',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D47A1),
                      fontSize: 15,
                    ),
                  ),
                  iconColor: const Color(0xFF0D47A1),
                  collapsedIconColor: const Color(0xFF0D47A1),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  children: [
                    _buildSubMenuItem(
                      context,
                      'Registro Reparación',
                      Icons.app_registration,
                      RegistroEstibaScreen(datosEmpleado: widget.datosEmpleado),
                    ),
                    _buildSubMenuItem(
                      context,
                      'Solicitud de Insumos',
                      Icons.add_shopping_cart_outlined,
                      SolicitudInsumosScreen(datosEmpleado: widget.datosEmpleado),
                    ),
                    _buildSubMenuItem(
                      context,
                      'Inventario Estibas',
                      Icons.inventory_rounded,
                      InventarioEstibasScreen(datosEmpleado: widget.datosEmpleado),
                    ),
                    _buildSubMenuItem(
                      context,
                      'Resultado Día',
                      Icons.bar_chart_rounded,
                      ResultadoDiaScreen(datosEmpleado: widget.datosEmpleado),
                    ),
                    _buildSubMenuItem(
                      context,
                      'Estibas Entregadas',
                      Icons.local_shipping_outlined,
                      EstibasEntregadasScreen(datosEmpleado: widget.datosEmpleado),
                    ),
                    _buildSubMenuItem(
                      context,
                      'Mi Productividad',
                      Icons.analytics_outlined,
                      DashboardOperacionScreen(datosEmpleado: widget.datosEmpleado),
                    ),
                    _buildSubMenuItem(
                      context,
                      'Podium del Mes',
                      Icons.emoji_events_outlined,
                      PodiumScreen(datosEmpleado: widget.datosEmpleado),
                    ),
                  ],
                ),

                ExpansionTile(
                  leading: const Icon(Icons.assignment_turned_in_outlined, color: Color(0xFF0D47A1)),
                  title: const Text(
                    'PREOPERACIONALES',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D47A1),
                      fontSize: 15,
                    ),
                  ),
                  iconColor: const Color(0xFF0D47A1),
                  collapsedIconColor: const Color(0xFF0D47A1),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  children: [
                    _buildSubMenuItem(
                      context,
                      'Herramientas Manuales',
                      Icons.build_circle_outlined,
                      PreoHManualesScreen(datosEmpleado: widget.datosEmpleado),
                    ),
                    _buildSubMenuItem(
                      context,
                      'Pistola',
                      Icons.hardware_rounded,
                      PreoPistolaScreen(datosEmpleado: widget.datosEmpleado),
                    ),
                    _buildSubMenuItem(
                      context,
                      'Bomba',
                      Icons.invert_colors_rounded,
                      PreoBombaScreen(datosEmpleado: widget.datosEmpleado),
                    ),
                    _buildSubMenuItem(
                      context,
                      'Historial',
                      Icons.history_edu_rounded,
                      HistorialPreopScreen(datosEmpleado: widget.datosEmpleado),
                    ),
                  ],
                ),

                // 🛡️ MÓDULO DE SEGURIDAD
                ExpansionTile(
                  leading: const Icon(Icons.shield_outlined, color: Color(0xFF0D47A1)),
                  title: const Text(
                    'SEGURIDAD',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D47A1),
                      fontSize: 15,
                    ),
                  ),
                  iconColor: const Color(0xFF0D47A1),
                  collapsedIconColor: const Color(0xFF0D47A1),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  children: [
                    _buildSubMenuItem(
                      context,
                      '5S',
                      Icons.fact_check_outlined,
                      CincoSScreen(datosEmpleado: widget.datosEmpleado),
                    ),
                    _buildSubMenuItem(
                      context,
                      'Condición de Salud',
                      Icons.health_and_safety_outlined,
                      CondicionSaludScreen(datosEmpleado: widget.datosEmpleado),
                    ),
                  ],
                ),

                ExpansionTile(
                  leading: const Icon(Icons.manage_accounts_outlined, color: Color(0xFF0D47A1)),
                  title: const Text(
                    'GESTIÓN',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D47A1),
                      fontSize: 15,
                    ),
                  ),
                  iconColor: const Color(0xFF0D47A1),
                  collapsedIconColor: const Color(0xFF0D47A1),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  children: [
                    _buildSubMenuItem(
                      context,
                      'Dashboard 5S',
                      Icons.donut_large_rounded,
                      Dashboard5SScreen(datosEmpleado: widget.datosEmpleado),
                    ),
                    _buildSubMenuItem(
                      context,
                      'Dashboard 5S Bavaria',
                      Icons.insert_chart_outlined_rounded,
                      Dashboard5SBavariaScreen(datosEmpleado: widget.datosEmpleado),
                    ),
                    _buildSubMenuItem(
                      context,
                      'Dueños de Territorio',
                      Icons.people_alt_outlined,
                      DuenosTerritorioScreen(datosEmpleado: widget.datosEmpleado),
                    ),
                    _buildSubMenuItem(
                      context,
                      '5Why (5 Porqués)',
                      Icons.psychology_outlined,
                      Gestion5WhyScreen(datosEmpleado: widget.datosEmpleado),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0, top: 10.0),
            child: Text(
              'Desarrollado por: Gerardo Rodriguez',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade400,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubMenuItem(
      BuildContext context,
      String titulo,
      IconData icono,
      Widget? pantallaDestino,
      ) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 35, right: 15),
      leading: Icon(icono, color: const Color(0xFF1565C0), size: 20),
      title: Text(
        titulo,
        style: const TextStyle(
          fontSize: 13,
          color: Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        if (pantallaDestino != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => pantallaDestino),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Módulo "$titulo" en desarrollo...')),
          );
        }
      },
    );
  }
}