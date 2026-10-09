import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

class SolicitudInsumosScreen extends StatefulWidget {
  final Map<String, dynamic> datosEmpleado;
  const SolicitudInsumosScreen({super.key, required this.datosEmpleado});

  @override
  State<SolicitudInsumosScreen> createState() => _SolicitudInsumosScreenState();
}

class _SolicitudInsumosScreenState extends State<SolicitudInsumosScreen> {
  bool _isLoading = true;
  List<dynamic> _registros = [];

  // 🔎 VARIABLES DE FILTROS
  DateTime? _filtroDia;
  String? _filtroMes;
  String? _filtroAnio;
  final _filtroSolicitanteController = TextEditingController();

  final List<String> _opcionesMeses = ['01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12'];
  final List<String> _opcionesAnios = [
    DateTime.now().year.toString(),
    (DateTime.now().year - 1).toString(),
    (DateTime.now().year - 2).toString()
  ];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  // 📥 LEER DATOS CON FILTROS APLICADOS MEDIANTE LA API
  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/consultar/${ApiService.schema}/estibas_insumo');

      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'x-api-key': ApiService.apiKey,
      });

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> query = [];

        // 🛡️ REGLA INTELIGENTE DE LECTURA (Evita el choque fatal)
        if (decoded is List) {
          query = decoded;
        } else if (decoded is Map<String, dynamic> && decoded['data'] != null) {
          query = decoded['data'] is List ? decoded['data'] : [];
        }

        // Filtros Locales
        if (_filtroDia != null) {
          final diaStr = _filtroDia.toString().substring(0, 10);
          query = query.where((r) => (r['fecha'] ?? '').toString().startsWith(diaStr)).toList();
        } else if (_filtroMes != null && _filtroAnio != null) {
          final prefijo = '$_filtroAnio-$_filtroMes';
          query = query.where((r) => (r['fecha'] ?? '').toString().startsWith(prefijo)).toList();
        }

        if (_filtroSolicitanteController.text.isNotEmpty) {
          final term = _filtroSolicitanteController.text.trim().toLowerCase();
          query = query.where((r) => (r['solicitante'] ?? '').toString().toLowerCase().contains(term)).toList();
        }

        query.sort((a, b) {
          final fechaA = a['fecha_registro'] ?? '';
          final fechaB = b['fecha_registro'] ?? '';
          return fechaB.compareTo(fechaA);
        });

        setState(() => _registros = query);
      }
    } catch (e) {
      debugPrint('Error al cargar solicitudes: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 📝 MOSTRAR FORMULARIO PARA CREAR O EDITAR
  void _mostrarFormulario({Map<String, dynamic>? registroAEditar}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FormularioSolicitud(
        datosEmpleado: widget.datosEmpleado,
        registroExistente: registroAEditar,
        onGuardado: () {
          _cargarDatos();
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  // 🗑️ CONFIRMAR Y ELIMINAR REGISTRO POR API
  void _confirmarEliminar(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.red[300]!, width: 3)),
              child: const Icon(Icons.delete_outline, color: Colors.red, size: 40),
            ),
            const SizedBox(height: 20),
            const Text('¿Eliminar registro?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('Esta acción no se puede deshacer.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        final url = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/borrar/${ApiService.schema}/estibas_insumo/${item['id']}');
                        final response = await http.delete(url, headers: {
                          'Content-Type': 'application/json',
                          'x-api-key': ApiService.apiKey,
                        });

                        if (mounted) {
                          if (response.statusCode == 200) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registro eliminado'), backgroundColor: Colors.green));
                            _cargarDatos();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al eliminar'), backgroundColor: Colors.red));
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                        }
                      }
                    },
                    child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[600], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  bool _esEditable(String fechaStr) {
    try {
      final fechaRegistro = DateTime.parse(fechaStr);
      final hoy = DateTime.now();
      final diferencia = hoy.difference(fechaRegistro).inDays;
      return diferencia <= 3 && diferencia >= -3;
    } catch (e) {
      return false;
    }
  }

  void _mostrarFiltros() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 20),
                  const Text('Filtros de Búsqueda', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                  const SizedBox(height: 20),

                  const Text('Por Día Específico:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_filtroDia == null ? 'Seleccionar Día' : _filtroDia.toString().substring(0, 10)),
                    onPressed: () async {
                      final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
                      if (date != null) setStateModal(() { _filtroDia = date; _filtroMes = null; _filtroAnio = null; });
                    },
                  ),
                  const SizedBox(height: 20),

                  const Text('O Por Mes y Año:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _filtroMes,
                          decoration: InputDecoration(labelText: 'Mes', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          items: _opcionesMeses.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                          onChanged: (val) => setStateModal(() { _filtroMes = val; _filtroDia = null; if (_filtroAnio == null) _filtroAnio = _opcionesAnios.first; }),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _filtroAnio,
                          decoration: InputDecoration(labelText: 'Año', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          items: _opcionesAnios.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                          onChanged: (val) => setStateModal(() { _filtroAnio = val; _filtroDia = null; if (_filtroMes == null) _filtroMes = _opcionesMeses[DateTime.now().month - 1]; }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  const Text('Por Solicitante:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _filtroSolicitanteController,
                    decoration: InputDecoration(hintText: 'Ej. Juan Perez', prefixIcon: const Icon(Icons.person_search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  const SizedBox(height: 30),

                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            setState(() { _filtroDia = null; _filtroMes = null; _filtroAnio = null; _filtroSolicitanteController.clear(); });
                            Navigator.pop(context);
                            _cargarDatos();
                          },
                          child: const Text('Limpiar', style: TextStyle(color: Colors.red, fontSize: 16)),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: () { Navigator.pop(context); _cargarDatos(); },
                          child: const Text('Aplicar Filtros', style: TextStyle(color: Colors.white, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hayFiltrosActivos = _filtroDia != null || _filtroMes != null || _filtroSolicitanteController.text.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Solicitud de Insumos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(hayFiltrosActivos ? Icons.filter_alt : Icons.filter_alt_outlined, color: hayFiltrosActivos ? Colors.amber : Colors.white),
            onPressed: _mostrarFiltros,
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargarDatos,
        color: const Color(0xFF0D47A1),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1)))
            : _registros.isEmpty
            ? _ConstruirEstadoVacio()
            : ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _registros.length,
          itemBuilder: (context, index) {
            final item = _registros[index];
            final String fechaCorta = (item['fecha'] ?? '').toString().length >= 10 ? (item['fecha'] ?? '').toString().substring(0, 10) : '';
            final bool editable = _esEditable(fechaCorta);

            Color colorPrioridad = Colors.grey;
            if (item['prioridad'] == 'Alta') colorPrioridad = Colors.orange;
            if (item['prioridad'] == 'Urgente') colorPrioridad = Colors.red;
            if (item['prioridad'] == 'Media') colorPrioridad = Colors.blue;

            return Card(
              elevation: 2, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF1565C0).withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.shopping_cart_outlined, color: Color(0xFF1565C0))),
                title: Text('${item['tipo']} (Cant: ${item['cantidad']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Solicitante: ${item['solicitante'] ?? 'N/A'}', style: const TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text('Prioridad: ', style: TextStyle(color: Colors.black87)),
                          Text('${item['prioridad'] ?? 'Media'}', style: TextStyle(color: colorPrioridad, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text(fechaCorta, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                        ],
                      ),
                      if (item['observacion'] != null && item['observacion'].toString().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('Obs: ${item['observacion']}', style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic)),
                      ]
                    ],
                  ),
                ),
                trailing: editable ? PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  onSelected: (value) {
                    if (value == 'editar') _mostrarFormulario(registroAEditar: item);
                    if (value == 'eliminar') _confirmarEliminar(item);
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem(value: 'editar', child: Row(children: [Icon(Icons.edit, color: Colors.blue, size: 20), SizedBox(width: 8), Text('Editar')])),
                    const PopupMenuItem(value: 'eliminar', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 8), Text('Eliminar')])),
                  ],
                ) : null,
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarFormulario(), backgroundColor: const Color(0xFF0D47A1), elevation: 4, icon: const Icon(Icons.add_shopping_cart, color: Colors.white), label: const Text('Nueva Solicitud', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _ConstruirEstadoVacio extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_add, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('Sin solicitudes registradas', style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// FORMULARIO DE INGRESO / EDICIÓN
// ==========================================
class FormularioSolicitud extends StatefulWidget {
  final Map<String, dynamic> datosEmpleado;
  final Map<String, dynamic>? registroExistente;
  final VoidCallback onGuardado;

  const FormularioSolicitud({super.key, required this.datosEmpleado, this.registroExistente, required this.onGuardado});

  @override
  State<FormularioSolicitud> createState() => _FormularioSolicitudState();
}

class _FormularioSolicitudState extends State<FormularioSolicitud> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  List<String> _listaUsuarios = [];
  bool _cargandoUsuarios = true;

  late final TextEditingController _fechaController;
  late final TextEditingController _solicitanteController;
  late final TextEditingController _cantidadController;
  late final TextEditingController _observacionController;

  late String _prioridadSeleccionada;
  final List<String> _opcionesPrioridad = ['Baja', 'Media', 'Alta', 'Urgente'];

  late String _insumoSeleccionado;
  final List<String> _opcionesInsumo = [
    'Cinta Transparente', 'Stretch Film', 'Bisturí', 'Guantes de Carnaza',
    'Guantes de Nitrilo', 'Marcadores', 'Zunchos', 'Grapas', 'Bolsas',
    'Otros', 'Clavos', 'Estibas Tipo B', 'Retirar estibas Tipo C'
  ];

  @override
  void initState() {
    super.initState();

    final item = widget.registroExistente;
    _fechaController = TextEditingController(text: item?['fecha']?.toString().substring(0, 10) ?? DateTime.now().toString().substring(0, 10));
    _solicitanteController = TextEditingController(text: item?['solicitante'] ?? '');
    _cantidadController = TextEditingController(text: item?['cantidad']?.toString() ?? '');
    _observacionController = TextEditingController(text: item?['observacion'] ?? '');

    _prioridadSeleccionada = _opcionesPrioridad.contains(item?['prioridad']) ? item!['prioridad'] : 'Media';
    _insumoSeleccionado = _opcionesInsumo.contains(item?['tipo']) ? item!['tipo'] : _opcionesInsumo.first;

    _cargarUsuariosDesdeApi();
  }

  Future<void> _cargarUsuariosDesdeApi() async {
    try {
      final lista = await ApiService.obtenerOperarios();
      if (mounted) {
        setState(() {
          _listaUsuarios = lista;
          _cargandoUsuarios = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargandoUsuarios = false);
    }
  }

  // 📧 MÉTODO ACTUALIZADO: ENVIAR CORREO PROFESIONAL Y DIAGNÓSTICO EN CONSOLA
  Future<void> _enviarCorreoNotificacion(Map<String, dynamic> datosSolicitud) async {
    try {
      debugPrint('=== 1. INICIANDO BÚSQUEDA DE DESTINATARIOS ===');
      final urlEmail = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/consultar/${ApiService.schema}/email');

      final resEmail = await http.get(urlEmail, headers: {
        'Content-Type': 'application/json',
        'x-api-key': ApiService.apiKey,
      });

      if (resEmail.statusCode != 200) {
        debugPrint('❌ Error al consultar emails (${resEmail.statusCode}): ${resEmail.body}');
        return;
      }

      final decodedEmail = jsonDecode(resEmail.body);
      List<dynamic> items = [];

      // 🛡️ REGLA INTELIGENTE DE LECTURA (Evita el choque fatal)
      if (decodedEmail is List) {
        items = decodedEmail;
      } else if (decodedEmail is Map<String, dynamic> && decodedEmail['data'] != null) {
        items = decodedEmail['data'] is List ? decodedEmail['data'] : [];
      }

      // Filtramos correos con estado = 'ACTIVO'
      List<String> correosActivos = items
          .where((e) => (e['estado'] ?? '').toString().toUpperCase() == 'ACTIVO')
          .map((e) => (e['correos'] ?? e['correo'] ?? '').toString().trim())
          .where((c) => c.isNotEmpty)
          .toList();

      if (correosActivos.isEmpty) {
        debugPrint('⚠️ ATENCIÓN: No hay correos con estado "ACTIVO" en la base de datos.');
        return;
      }

      String destinatariosMasivos = correosActivos.join(', ');
      debugPrint('📧 Destinatarios encontrados: $destinatariosMasivos');

      // Estilos dinámicos según prioridad
      String prioridad = (datosSolicitud['prioridad'] ?? 'Media').toString();
      String colorPrioridad = '#2563EB'; // Azul
      String bgPrioridad = '#EFF6FF';

      if (prioridad == 'Alta') {
        colorPrioridad = '#D97706'; // Naranja
        bgPrioridad = '#FEF3C7';
      } else if (prioridad == 'Urgente') {
        colorPrioridad = '#DC2626'; // Rojo
        bgPrioridad = '#FEE2E2';
      } else if (prioridad == 'Baja') {
        colorPrioridad = '#059669'; // Verde
        bgPrioridad = '#D1FAE5';
      }

      String obs = (datosSolicitud['observacion'] ?? '').toString().isNotEmpty
          ? datosSolicitud['observacion']
          : 'Sin observaciones adicionales.';

      // Plantilla HTML profesional
      String htmlString = '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
      </head>
      <body style="font-family: 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f1f5f9; margin: 0; padding: 20px; -webkit-font-smoothing: antialiased;">
        <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 15px rgba(0, 0, 0, 0.08); border: 1px solid #e2e8f0;">
          
          <!-- Banner Superior / Encabezado -->
          <div style="background-color: #0D47A1; padding: 25px 20px; text-align: center;">
            <!-- ETIQUETA DESTACADA REPARACION DE ESTIBAS URGENCIA -->
            <span style="display: inline-block; background-color: #DC2626; color: #ffffff; font-size: 11px; font-weight: bold; letter-spacing: 1.2px; padding: 6px 14px; border-radius: 20px; text-transform: uppercase; margin-bottom: 12px; box-shadow: 0 2px 4px rgba(0,0,0,0.2);">
              🚨 REPARACION DE ESTIBAS URGENCIA
            </span>
            <h1 style="color: #ffffff; margin: 0; font-size: 22px; font-weight: 700; letter-spacing: 0.5px;">
              Solicitud de Insumo Registrada
            </h1>
          </div>

          <!-- Contenido Principal -->
          <div style="padding: 24px;">
            <p style="color: #475569; font-size: 14px; margin-top: 0; margin-bottom: 20px; line-height: 1.5;">
              Se ha generado un nuevo requerimiento de insumos desde la aplicación móvil. A continuación se detallan los datos del registro:
            </p>

            <!-- Tabla de Detalles Estilizada -->
            <table style="width: 100%; border-collapse: separate; border-spacing: 0; background-color: #f8fafc; border-radius: 8px; border: 1px solid #e2e8f0; font-size: 14px;">
              <tr>
                <td style="padding: 12px 16px; color: #64748b; font-weight: 600; width: 35%; border-bottom: 1px solid #e2e8f0;">Fecha:</td>
                <td style="padding: 12px 16px; color: #1e293b; font-weight: 600; border-bottom: 1px solid #e2e8f0;">${datosSolicitud['fecha']}</td>
              </tr>
              <tr>
                <td style="padding: 12px 16px; color: #64748b; font-weight: 600; border-bottom: 1px solid #e2e8f0;">Solicitante:</td>
                <td style="padding: 12px 16px; color: #1e293b; font-weight: 600; border-bottom: 1px solid #e2e8f0;">${datosSolicitud['solicitante']}</td>
              </tr>
              <tr>
                <td style="padding: 12px 16px; color: #64748b; font-weight: 600; border-bottom: 1px solid #e2e8f0;">Insumo Requerido:</td>
                <td style="padding: 12px 16px; color: #0D47A1; font-weight: 700; font-size: 15px; border-bottom: 1px solid #e2e8f0;">${datosSolicitud['tipo']}</td>
              </tr>
              <tr>
                <td style="padding: 12px 16px; color: #64748b; font-weight: 600; border-bottom: 1px solid #e2e8f0;">Cantidad:</td>
                <td style="padding: 12px 16px; color: #1e293b; font-weight: 700; border-bottom: 1px solid #e2e8f0;">${datosSolicitud['cantidad']}</td>
              </tr>
              <tr>
                <td style="padding: 12px 16px; color: #64748b; font-weight: 600;">Prioridad:</td>
                <td style="padding: 12px 16px;">
                  <span style="display: inline-block; background-color: $bgPrioridad; color: $colorPrioridad; font-weight: 700; font-size: 12px; padding: 4px 10px; border-radius: 6px; border: 1px solid $colorPrioridad;">
                    ${datosSolicitud['prioridad']}
                  </span>
                </td>
              </tr>
            </table>

            <!-- Bloque de Observaciones -->
            <div style="margin-top: 20px;">
              <span style="display: block; font-size: 12px; font-weight: 700; color: #64748b; margin-bottom: 6px; text-transform: uppercase; letter-spacing: 0.5px;">Observación / Comentarios:</span>
              <div style="background-color: #f1f5f9; border-left: 4px solid #0D47A1; padding: 12px 16px; border-radius: 0 8px 8px 0; font-style: italic; color: #334155; font-size: 13px; line-height: 1.4;">
                "$obs"
              </div>
            </div>
          </div>

          <!-- Pie de Página -->
          <div style="background-color: #f8fafc; padding: 16px; text-align: center; border-top: 1px solid #e2e8f0; font-size: 11px; color: #94a3b8;">
            <p style="margin: 0; font-weight: 500;">Sistema Logístico de Control • Notificación Automática</p>
          </div>
        </div>
      </body>
      </html>
      ''';

      debugPrint('=== 2. DISPARANDO SERVICIO DE CORREO SMTP ===');
      await ApiService.enviarCorreo(
        esquemaCredenciales: 'administrador_principal',
        tablaCredenciales: 'smtp',
        para: destinatariosMasivos,
        asunto: '[REPARACION DE ESTIBAS URGENCIA] Solicitud: ${datosSolicitud['tipo']} - ${datosSolicitud['solicitante']}',
        html: htmlString,
      );

      debugPrint('✅ CORREO ENVIADO CON ÉXITO');
    } catch (e) {
      debugPrint('❌ ERROR CRÍTICO ENVIANDO CORREO: $e');
    }
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? seleccion = await showDatePicker(context: context, initialDate: DateTime.parse(_fechaController.text), firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (seleccion != null) setState(() => _fechaController.text = seleccion.toString().substring(0, 10));
  }

  void _confirmarGuardado() {
    if (!_formKey.currentState!.validate()) return;
    if (_solicitanteController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, busca un solicitante válido.'), backgroundColor: Colors.red));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.orange[300]!, width: 3)), child: const Icon(Icons.priority_high, color: Colors.orange, size: 40)),
            const SizedBox(height: 20),
            const Text('¿Guardar Solicitud?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 10),
            const Text('Se registrarán los datos.', style: TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E64F8), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _guardarEnApiNode();
                    },
                    child: const Text('Sí, confirmar', style: TextStyle(color: Colors.white, fontSize: 15)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5A6270), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar', style: TextStyle(color: Colors.white, fontSize: 15)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Future<void> _guardarEnApiNode() async {
    setState(() => _isSaving = true);
    try {
      final ahora = DateTime.now();
      final fechaRegistroStr = "${ahora.year}-${ahora.month.toString().padLeft(2, '0')}-${ahora.day.toString().padLeft(2, '0')} ${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')}:${ahora.second.toString().padLeft(2, '0')}";

      final datosMap = <String, dynamic>{
        'fecha_registro': fechaRegistroStr,
        'fecha': _fechaController.text,
        'solicitante': _solicitanteController.text.trim(),
        'tipo': _insumoSeleccionado,
        'cantidad': int.tryParse(_cantidadController.text) ?? 0,
        'prioridad': _prioridadSeleccionada,
        'observacion': _observacionController.text.trim(),
      };

      bool ok = false;
      String mensajeError = '';

      if (widget.registroExistente == null) {
        datosMap['id'] = 'INS-${ahora.millisecondsSinceEpoch}';

        final url = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/insertar/${ApiService.schema}/estibas_insumo');

        debugPrint('=== ENVIANDO DATOS A API ===');
        debugPrint('URL: $url');
        debugPrint('Body a enviar: ${jsonEncode(datosMap)}');

        final response = await http.post(url, headers: {
          'Content-Type': 'application/json',
          'x-api-key': ApiService.apiKey,
        }, body: jsonEncode(datosMap));

        debugPrint('=== RESPUESTA DE API ===');
        debugPrint('Status Code: ${response.statusCode}');
        debugPrint('Body Respuesta: ${response.body}');

        if (response.statusCode == 200 || response.statusCode == 201) {
          final resJson = jsonDecode(response.body);
          ok = resJson['exito'] == true || resJson['success'] == true;
          if (!ok) mensajeError = resJson['mensaje'] ?? resJson['error'] ?? 'Rechazado por servidor';
        } else {
          mensajeError = 'Error ${response.statusCode}: ${response.body}';
        }
      } else {
        final idExistente = widget.registroExistente!['id'];
        final url = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/actualizar/${ApiService.schema}/estibas_insumo/$idExistente');

        final response = await http.put(url, headers: {
          'Content-Type': 'application/json',
          'x-api-key': ApiService.apiKey,
        }, body: jsonEncode(datosMap));

        if (response.statusCode == 200) {
          final resJson = jsonDecode(response.body);
          ok = resJson['exito'] == true || resJson['success'] == true;
          if (!ok) mensajeError = resJson['mensaje'] ?? resJson['error'] ?? 'Error al actualizar';
        } else {
          mensajeError = 'Error ${response.statusCode}: ${response.body}';
        }
      }

      if (!mounted) return;

      if (ok) {
        // 🚀 ESPERAMOS EL ENVÍO DEL CORREO SI ES UN REGISTRO NUEVO
        if (widget.registroExistente == null) {
          await _enviarCorreoNotificacion(datosMap);
        }

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 60),
                const SizedBox(height: 20),
                Text(widget.registroExistente == null ? '¡Solicitud Creada!' : '¡Actualizado!', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text('La solicitud se guardó con éxito.', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () {
                    Navigator.pop(ctx);
                    widget.onGuardado();
                  },
                  child: const Text('Aceptar', style: TextStyle(color: Colors.white)),
                )
              ],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $mensajeError'), backgroundColor: Colors.red, duration: const Duration(seconds: 8)));
        setState(() => _isSaving = false);
      }
    } catch (e) {
      if (mounted) {
        debugPrint('=== EXCEPCIÓN CATCH ===: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error inesperado: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 8)));
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double paddingInferiorSistema = MediaQuery.of(context).padding.bottom;
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final esEdicion = widget.registroExistente != null;

    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      padding: EdgeInsets.only(top: 24, left: 24, right: 24, bottom: paddingInferiorSistema + keyboardHeight),
      height: MediaQuery.of(context).size.height * 0.9,
      child: Column(
        children: [
          Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 20),
          Text(esEdicion ? 'Editar Solicitud' : 'Nueva Solicitud', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
          const SizedBox(height: 20),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  Row(
                    children: [
                      Expanded(child: _crearCampo(controller: _fechaController, label: 'Fecha Solicitud', icono: Icons.calendar_today_outlined, soloLectura: true, onTap: () => _seleccionarFecha(context))),
                      const SizedBox(width: 15),
                      Expanded(child: DropdownButtonFormField<String>(isExpanded: true, value: _prioridadSeleccionada, decoration: InputDecoration(labelText: 'Prioridad', prefixIcon: const Icon(Icons.flag_outlined, color: Color(0xFF1565C0)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), items: _opcionesPrioridad.map((String val) => DropdownMenuItem(value: val, child: Text(val, style: const TextStyle(fontSize: 13)))).toList(), onChanged: (val) => setState(() => _prioridadSeleccionada = val!))),
                    ],
                  ),
                  const SizedBox(height: 15),

                  _crearBuscador(controller: _solicitanteController, label: 'Solicitante', icono: Icons.person_search_outlined, opciones: _listaUsuarios, cargando: _cargandoUsuarios),
                  const SizedBox(height: 15),

                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _insumoSeleccionado,
                            decoration: InputDecoration(
                                labelText: 'Insumo',
                                prefixIcon: const Icon(Icons.category_outlined, color: Color(0xFF1565C0)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
                            ),
                            items: _opcionesInsumo.map((String val) => DropdownMenuItem(
                                value: val,
                                child: Text(val, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)
                            )).toList(),
                            onChanged: (val) => setState(() => _insumoSeleccionado = val!)
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(flex: 1, child: _crearCampo(controller: _cantidadController, label: 'Cant.', icono: Icons.numbers, esNumero: true)),
                    ],
                  ),
                  const SizedBox(height: 15),

                  TextFormField(
                    controller: _observacionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Observación (Opcional)',
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 40),
                        child: Icon(Icons.notes, color: Color(0xFF1565C0)),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 35),
                  SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: esEdicion ? Colors.orange : const Color(0xFF0D47A1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      onPressed: _isSaving ? null : _confirmarGuardado,
                      child: _isSaving ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: Colors.white), SizedBox(width: 10), Text('Guardando...', style: TextStyle(color: Colors.white))]) : Text(esEdicion ? 'ACTUALIZAR SOLICITUD' : 'GUARDAR SOLICITUD', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _crearCampo({required TextEditingController controller, required String label, required IconData icono, bool esNumero = false, bool soloLectura = false, VoidCallback? onTap}) {
    return TextFormField(controller: controller, readOnly: soloLectura, onTap: onTap, keyboardType: esNumero ? TextInputType.number : TextInputType.text, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icono, color: const Color(0xFF1565C0)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: soloLectura && onTap == null ? Colors.grey[200] : Colors.white), validator: (value) => (!soloLectura && (value == null || value.isEmpty) && !esNumero) ? 'Requerido' : null);
  }

  Widget _crearBuscador({
    required TextEditingController controller,
    required String label,
    required IconData icono,
    required List<String> opciones,
    required bool cargando,
  }) {
    if (cargando) {
      return TextFormField(
        decoration: InputDecoration(
          labelText: 'Cargando $label...',
          prefixIcon: Icon(icono, color: const Color(0xFF1565C0)),
          suffixIcon: const Padding(padding: EdgeInsets.all(14.0), child: CircularProgressIndicator(strokeWidth: 2)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[100],
        ),
        readOnly: true,
      );
    }

    return Autocomplete<String>(
      initialValue: TextEditingValue(text: controller.text),
      optionsBuilder: (text) {
        if (text.text.isEmpty) {
          return opciones.take(3);
        }
        return opciones
            .where((o) => o.toLowerCase().contains(text.text.toLowerCase()))
            .take(3);
      },
      onSelected: (selection) {
        controller.text = selection;
        FocusScope.of(context).unfocus();
      },
      fieldViewBuilder: (ctx, fieldCtrl, focus, onEdit) {
        if (fieldCtrl.text != controller.text && !focus.hasFocus) fieldCtrl.text = controller.text;
        fieldCtrl.addListener(() => controller.text = fieldCtrl.text);
        return TextFormField(
          controller: fieldCtrl,
          focusNode: focus,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icono, color: const Color(0xFF1565C0)),
            suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (val) => val == null || val.isEmpty ? 'Selecciona' : null,
        );
      },
      optionsViewBuilder: (ctx, onSelect, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 6.0,
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 180),
            width: MediaQuery.of(context).size.width - 48,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (ctx, i) => ListTile(
                leading: Icon(icono, color: const Color(0xFF1565C0)),
                title: Text(options.elementAt(i), style: const TextStyle(fontSize: 14)),
                onTap: () => onSelect(options.elementAt(i)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}