import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';

class InventarioEstibasScreen extends StatefulWidget {
  final Map<String, dynamic> datosEmpleado;
  const InventarioEstibasScreen({super.key, required this.datosEmpleado});

  @override
  State<InventarioEstibasScreen> createState() => _InventarioEstibasScreenState();
}

class _InventarioEstibasScreenState extends State<InventarioEstibasScreen> {
  bool _isLoading = true;
  List<dynamic> _registros = [];

  // 🔎 VARIABLES DE FILTROS
  DateTime? _filtroDia;
  String? _filtroMes;
  String? _filtroAnio;
  final _filtroResponsableController = TextEditingController();

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
      final url = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/consultar/${ApiService.schema}/inventario_estibas');

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

        if (_filtroResponsableController.text.isNotEmpty) {
          final term = _filtroResponsableController.text.trim().toLowerCase();
          query = query.where((r) => (r['responsable'] ?? '').toString().toLowerCase().contains(term)).toList();
        }

        query.sort((a, b) {
          final fechaA = a['fecha'] ?? a['fecha_de_reporte'] ?? '';
          final fechaB = b['fecha'] ?? b['fecha_de_reporte'] ?? '';
          return fechaB.compareTo(fechaA);
        });

        setState(() => _registros = query);
      }
    } catch (e) {
      debugPrint('Error al cargar inventario: $e');
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
      builder: (context) => FormularioInventario(
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
                        final url = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/borrar/${ApiService.schema}/inventario_estibas/${item['id']}');
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

  // ⏳ VERIFICAR SI TIENE MENOS DE 3 DÍAS
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

  // 🔎 PANEL DE FILTROS A MEDIDA
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

                  const Text('Por Responsable:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _filtroResponsableController,
                    decoration: InputDecoration(hintText: 'Ej. Juan Perez', prefixIcon: const Icon(Icons.person_search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  const SizedBox(height: 30),

                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            setState(() { _filtroDia = null; _filtroMes = null; _filtroAnio = null; _filtroResponsableController.clear(); });
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
    bool hayFiltrosActivos = _filtroDia != null || _filtroMes != null || _filtroResponsableController.text.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Inventario de Estibas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            final String fechaCorta = (item['fecha'] ?? '').toString().length >= 10
                ? (item['fecha'] ?? '').toString().substring(0, 10)
                : '';
            final bool editable = _esEditable(fechaCorta);

            return Card(
              elevation: 2, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF1565C0).withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF1565C0))),
                title: Text('Fecha: $fechaCorta | Turno: ${item['turno'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Responsable: ${item['responsable'] ?? 'N/A'}', style: const TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Tipo A: ${item['total_tipo_a'] ?? '0'}', style: const TextStyle(color: Colors.black87)),
                          Text('Tipo B: ${item['total_tipo_b'] ?? '0'}', style: const TextStyle(color: Colors.black87)),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Tipo C: ${item['total_tipo_c'] ?? '0'}', style: const TextStyle(color: Colors.black87)),
                          Text('Guacales: ${item['guacales'] ?? '0'}', style: const TextStyle(color: Colors.black87)),
                        ],
                      ),
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
        onPressed: () => _mostrarFormulario(), backgroundColor: const Color(0xFF0D47A1), elevation: 4, icon: const Icon(Icons.add_box, color: Colors.white), label: const Text('Nuevo Conteo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('Sin registros encontrados', style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500)),
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
class FormularioInventario extends StatefulWidget {
  final Map<String, dynamic> datosEmpleado;
  final Map<String, dynamic>? registroExistente;
  final VoidCallback onGuardado;

  const FormularioInventario({super.key, required this.datosEmpleado, this.registroExistente, required this.onGuardado});

  @override
  State<FormularioInventario> createState() => _FormularioInventarioState();
}

class _FormularioInventarioState extends State<FormularioInventario> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  List<String> _listaUsuarios = [];
  bool _cargandoUsuarios = true;

  late final TextEditingController _fechaController;
  late String _turnoSeleccionado;

  // 🕒 OPCIONES DE TURNO
  final List<String> _opcionesTurno = ['T1', 'T2', 'T3'];

  late final TextEditingController _responsableController;
  late final TextEditingController _tipoAController;
  late final TextEditingController _tipoBController;
  late final TextEditingController _tipoCController;
  late final TextEditingController _guacalesController;

  @override
  void initState() {
    super.initState();

    final item = widget.registroExistente;

    _fechaController = TextEditingController(text: item?['fecha']?.toString().substring(0, 10) ?? DateTime.now().toString().substring(0, 10));
    _turnoSeleccionado = _opcionesTurno.contains(item?['turno']) ? item!['turno'] : _opcionesTurno.first;
    _responsableController = TextEditingController(text: item?['responsable'] ?? '');
    _tipoAController = TextEditingController(text: item?['total_tipo_a']?.toString() ?? '');
    _tipoBController = TextEditingController(text: item?['total_tipo_b']?.toString() ?? '');
    _tipoCController = TextEditingController(text: item?['total_tipo_c']?.toString() ?? '');
    _guacalesController = TextEditingController(text: item?['guacales']?.toString() ?? '');

    _cargarUsuariosDesdeApi();
  }

  // 🛡️ BÚSQUEDA DIRECTA DE OPERARIOS CON LECTURA INTELIGENTE
  Future<void> _cargarUsuariosDesdeApi() async {
    try {
      final url = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/consultar/estibas/estibas_usaurios');
      final res = await http.get(url, headers: {'Content-Type': 'application/json', 'x-api-key': ApiService.apiKey});
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        List items = [];

        if (decoded is List) {
          items = decoded;
        } else if (decoded is Map<String, dynamic> && decoded['data'] != null) {
          items = decoded['data'] is List ? decoded['data'] : [];
        }

        final lista = items.map((e) => (e['nombre'] ?? '').toString().trim()).where((n) => n.isNotEmpty).toSet().toList();
        if (mounted) setState(() { _listaUsuarios = lista; _cargandoUsuarios = false; });
      }
    } catch (e) {
      if (mounted) setState(() => _cargandoUsuarios = false);
    }
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? seleccion = await showDatePicker(context: context, initialDate: DateTime.parse(_fechaController.text), firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (seleccion != null) setState(() => _fechaController.text = seleccion.toString().substring(0, 10));
  }

  void _confirmarGuardado() {
    if (!_formKey.currentState!.validate()) return;
    if (_responsableController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecciona un responsable.'), backgroundColor: Colors.red));
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
            const Text('¿Guardar?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
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
      final fechaReporteStr = "${ahora.year}-${ahora.month.toString().padLeft(2, '0')}-${ahora.day.toString().padLeft(2, '0')} ${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')}:${ahora.second.toString().padLeft(2, '0')}";

      final datosMap = <String, dynamic>{
        'fecha_de_reporte': fechaReporteStr,
        'fecha': _fechaController.text,
        'turno': _turnoSeleccionado,
        'responsable': _responsableController.text.trim(),
        'total_tipo_a': int.tryParse(_tipoAController.text) ?? 0,
        'total_tipo_b': int.tryParse(_tipoBController.text) ?? 0,
        'total_tipo_c': int.tryParse(_tipoCController.text) ?? 0,
        'guacales': int.tryParse(_guacalesController.text) ?? 0,
      };

      bool ok = false;
      String mensajeError = '';

      final String schemaUsar = ApiService.schema;

      if (widget.registroExistente == null) {
        final url = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/insertar/$schemaUsar/inventario_estibas');

        final response = await http.post(url, headers: {
          'Content-Type': 'application/json',
          'x-api-key': ApiService.apiKey,
        }, body: jsonEncode(datosMap));

        if (response.statusCode == 200 || response.statusCode == 201) {
          final resJson = jsonDecode(response.body);
          // 🛡️ REGLA INTELIGENTE DE GUARDADO
          if (resJson is Map) {
            ok = resJson['exito'] == true || resJson['success'] == true;
            if (!ok) mensajeError = resJson['mensaje'] ?? resJson['error'] ?? 'Rechazado por el servidor';
          } else {
            ok = true;
          }
        } else {
          mensajeError = 'Status ${response.statusCode}: ${response.body}';
        }
      } else {
        final idExistente = widget.registroExistente!['id'];
        final url = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/actualizar/$schemaUsar/inventario_estibas/$idExistente');

        final response = await http.put(url, headers: {
          'Content-Type': 'application/json',
          'x-api-key': ApiService.apiKey,
        }, body: jsonEncode(datosMap));

        if (response.statusCode == 200) {
          final resJson = jsonDecode(response.body);
          // 🛡️ REGLA INTELIGENTE DE GUARDADO
          if (resJson is Map) {
            ok = resJson['exito'] == true || resJson['success'] == true;
            if (!ok) mensajeError = resJson['mensaje'] ?? resJson['error'] ?? 'Error al actualizar';
          } else {
            ok = true;
          }
        } else {
          mensajeError = 'Status ${response.statusCode}: ${response.body}';
        }
      }

      if (!mounted) return;

      if (ok) {
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
                Text(widget.registroExistente == null ? '¡Guardado!' : '¡Actualizado!', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text('El inventario se guardó con éxito.', style: TextStyle(color: Colors.grey)),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $mensajeError'), backgroundColor: Colors.red, duration: const Duration(seconds: 8)));
        setState(() => _isSaving = false);
      }
    } catch (e) {
      if (mounted) {
        debugPrint('❌ EXCEPCIÓN: $e');
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
          Text(esEdicion ? 'Editar Inventario' : 'Conteo de Inventario', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
          const SizedBox(height: 20),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  Row(
                    children: [
                      Expanded(child: _crearCampo(controller: _fechaController, label: 'Fecha Conteo', icono: Icons.calendar_today_outlined, soloLectura: true, onTap: () => _seleccionarFecha(context))),
                      const SizedBox(width: 15),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _turnoSeleccionado,
                          decoration: InputDecoration(
                            labelText: 'Turno',
                            prefixIcon: const Icon(Icons.access_time, color: Color(0xFF1565C0)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: _opcionesTurno.map((String val) => DropdownMenuItem(value: val, child: Text(val, style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (val) => setState(() => _turnoSeleccionado = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _crearAutocomplete(controller: _responsableController, label: 'Responsable', icono: Icons.person_search_outlined, opciones: _listaUsuarios, cargando: _cargandoUsuarios),
                  const Divider(height: 40, thickness: 1),
                  const Text('Cantidades Contadas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(child: _crearCampo(controller: _tipoAController, label: 'Total Tipo A', icono: Icons.layers_outlined, esNumero: true)),
                      const SizedBox(width: 15),
                      Expanded(child: _crearCampo(controller: _tipoBController, label: 'Total Tipo B', icono: Icons.layers_outlined, esNumero: true)),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(child: _crearCampo(controller: _tipoCController, label: 'Total Tipo C', icono: Icons.warning_amber_rounded, esNumero: true)),
                      const SizedBox(width: 15),
                      Expanded(child: _crearCampo(controller: _guacalesController, label: 'Guacales', icono: Icons.widgets_outlined, esNumero: true)),
                    ],
                  ),
                  const SizedBox(height: 35),
                  SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: esEdicion ? Colors.orange : const Color(0xFF0D47A1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      onPressed: _isSaving ? null : _confirmarGuardado,
                      child: _isSaving ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: Colors.white), SizedBox(width: 10), Text('Guardando...', style: TextStyle(color: Colors.white))]) : Text(esEdicion ? 'ACTUALIZAR INVENTARIO' : 'GUARDAR INVENTARIO', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget _crearAutocomplete({required TextEditingController controller, required String label, required IconData icono, required List<String> opciones, required bool cargando}) {
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
      optionsBuilder: (text) => text.text.isEmpty ? opciones.take(3) : opciones.where((o) => o.toLowerCase().contains(text.text.toLowerCase())).take(3),
      onSelected: (selection) { controller.text = selection; FocusScope.of(context).unfocus(); },
      fieldViewBuilder: (ctx, fieldCtrl, focus, onEdit) {
        if (fieldCtrl.text != controller.text && !focus.hasFocus) fieldCtrl.text = controller.text;
        fieldCtrl.addListener(() => controller.text = fieldCtrl.text);
        return TextFormField(controller: fieldCtrl, focusNode: focus, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icono, color: const Color(0xFF1565C0)), suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.grey), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white), validator: (val) => val == null || val.isEmpty ? 'Selecciona' : null);
      },
      optionsViewBuilder: (ctx, onSelect, options) => Align(alignment: Alignment.topLeft, child: Material(elevation: 6.0, borderRadius: BorderRadius.circular(12), color: Colors.white, child: Container(constraints: const BoxConstraints(maxHeight: 180), width: MediaQuery.of(context).size.width - 48, child: ListView.builder(padding: EdgeInsets.zero, shrinkWrap: true, itemCount: options.length, itemBuilder: (ctx, i) => ListTile(leading: Icon(icono, color: const Color(0xFF1565C0)), title: Text(options.elementAt(i), style: const TextStyle(fontSize: 14)), onTap: () => onSelect(options.elementAt(i))))))),
    );
  }
}