import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

class RegistroEstibaScreen extends StatefulWidget {
  final Map<String, dynamic>? datosEmpleado;
  const RegistroEstibaScreen({super.key, this.datosEmpleado});

  @override
  State<RegistroEstibaScreen> createState() => _RegistroEstibaScreenState();
}

typedef ProductividadScreen = RegistroEstibaScreen;

class _RegistroEstibaScreenState extends State<RegistroEstibaScreen> {
  bool _isLoading = true;
  List<dynamic> _registros = [];

  // 🔎 VARIABLES DE FILTROS
  DateTime? _filtroDia;
  String? _filtroMes;
  String? _filtroAnio;
  String? _filtroTurno;
  final _filtroOperadorController = TextEditingController();

  final List<String> _opcionesMeses = ['01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12'];
  final List<String> _opcionesAnios = [
    DateTime.now().year.toString(),
    (DateTime.now().year - 1).toString(),
    (DateTime.now().year - 2).toString()
  ];
  final List<String> _opcionesTurno = ['Todos', 'T1', 'T2', 'T3'];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      // 🛡️ PETICIÓN DIRECTA CON LECTURA INTELIGENTE
      final url = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/consultar/${ApiService.schema}/reparacion_estibas');
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'x-api-key': ApiService.apiKey,
      });

      List<dynamic> dataCompleta = [];
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          dataCompleta = decoded;
        } else if (decoded is Map<String, dynamic> && decoded['data'] != null) {
          dataCompleta = decoded['data'] is List ? decoded['data'] : [];
        }
      }

      List<dynamic> query = List.from(dataCompleta);

      if (_filtroDia != null) {
        final diaStr = _filtroDia.toString().substring(0, 10);
        query = query.where((r) => (r['fecha'] ?? '').toString().startsWith(diaStr)).toList();
      } else if (_filtroMes != null && _filtroAnio != null) {
        final prefijo = '$_filtroAnio-$_filtroMes';
        query = query.where((r) => (r['fecha'] ?? '').toString().startsWith(prefijo)).toList();
      }

      if (_filtroTurno != null && _filtroTurno != 'Todos') {
        query = query.where((r) => r['turno'] == _filtroTurno).toList();
      }

      if (_filtroOperadorController.text.isNotEmpty) {
        final term = _filtroOperadorController.text.trim().toLowerCase();
        query = query.where((r) => (r['operario'] ?? '').toString().toLowerCase().contains(term)).toList();
      }

      setState(() => _registros = query);
    } catch (e) {
      debugPrint('Error al cargar: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _mostrarFormulario({Map<String, dynamic>? registroAEditar}) {
    if (registroAEditar != null && !_esEditable(registroAEditar)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No es posible editar registros creados hace más de 48 horas.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FormularioProductividad(
        datosEmpleado: widget.datosEmpleado ?? {},
        registroExistente: registroAEditar,
        onGuardado: () {
          _cargarDatos();
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  void _confirmarEliminar(Map<String, dynamic> item) {
    if (!_esEditable(item)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No es posible eliminar registros creados hace más de 48 horas.'),
          backgroundColor: Colors.red,
        ),
      );
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
                        // 🛡️ ELIMINACIÓN DIRECTA PARA EVITAR FALLO DE APISERVICE
                        final url = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/borrar/${ApiService.schema}/reparacion_estibas/${item['id']}');
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
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
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

  // ⏱️ RESTRICCIÓN DE 48 HORAS PARA EDITAR O ELIMINAR
  bool _esEditable(Map<String, dynamic> item) {
    try {
      final strFecha = (item['fecha_de_reporte'] ?? item['fecha_registro'] ?? item['fecha'] ?? '').toString();
      if (strFecha.isEmpty) return false;

      final fechaRegistro = DateTime.parse(strFecha);
      final ahora = DateTime.now();

      final diferenciaHoras = ahora.difference(fechaRegistro).inHours;
      return diferenciaHoras >= 0 && diferenciaHoras <= 48;
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
                          initialValue: _filtroMes,
                          decoration: InputDecoration(labelText: 'Mes', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          items: _opcionesMeses.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                          onChanged: (val) => setStateModal(() { _filtroMes = val; _filtroDia = null; _filtroAnio ??= _opcionesAnios.first; }),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _filtroAnio,
                          decoration: InputDecoration(labelText: 'Año', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          items: _opcionesAnios.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                          onChanged: (val) => setStateModal(() { _filtroAnio = val; _filtroDia = null; _filtroMes ??= _opcionesMeses[DateTime.now().month - 1]; }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  const Text('Por Turno:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _filtroTurno ?? 'Todos',
                    decoration: InputDecoration(prefixIcon: const Icon(Icons.access_time), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    items: _opcionesTurno.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) => setStateModal(() { _filtroTurno = val; }),
                  ),
                  const SizedBox(height: 20),

                  const Text('Por Operador:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _filtroOperadorController,
                    decoration: InputDecoration(hintText: 'Ej. Juan Perez', prefixIcon: const Icon(Icons.person_search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  const SizedBox(height: 30),

                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _filtroDia = null;
                              _filtroMes = null;
                              _filtroAnio = null;
                              _filtroTurno = 'Todos';
                              _filtroOperadorController.clear();
                            });
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
    bool hayFiltrosActivos = _filtroDia != null || _filtroMes != null || _filtroOperadorController.text.isNotEmpty || (_filtroTurno != null && _filtroTurno != 'Todos');

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Productividad Diaria', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            ? _buildEstadoVacio()
            : ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _registros.length,
          itemBuilder: (context, index) {
            final item = _registros[index];
            final String fechaCompleta = (item['fecha'] ?? '').toString();
            final String fechaMostrar = fechaCompleta.length >= 10 ? fechaCompleta.substring(0, 10) : fechaCompleta;
            final bool editable = _esEditable(item);

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF1565C0).withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.assessment_rounded, color: Color(0xFF1565C0)),
                ),
                title: Text('Fecha: $fechaMostrar | Turno: ${item['turno'] ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Operario: ${item['operario'] ?? 'N/A'}', style: const TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.w500)),
                      Text('Supervisor: ${item['supervisor'] ?? 'N/A'} | OPM: ${item['opm'] ?? 'N/A'}', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('Reparadas: ${item['reparadas'] ?? '0'} | Clasificadas: ${item['clasificadas'] ?? '0'}', style: const TextStyle(color: Colors.black87)),
                    ],
                  ),
                ),
                trailing: editable
                    ? PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  onSelected: (value) {
                    if (value == 'editar') _mostrarFormulario(registroAEditar: item);
                    if (value == 'eliminar') _confirmarEliminar(item);
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem(value: 'editar', child: Row(children: [Icon(Icons.edit, color: Colors.blue, size: 20), SizedBox(width: 8), Text('Editar')])),
                    const PopupMenuItem(value: 'eliminar', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 8), Text('Eliminar')])),
                  ],
                )
                    : null, // Si pasaron > 48 horas, se remueve el menú desplegable
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarFormulario(),
        backgroundColor: const Color(0xFF0D47A1),
        elevation: 4,
        icon: const Icon(Icons.add_task, color: Colors.white),
        label: const Text('Registrar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEstadoVacio() {
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
// FORMULARIO DE PRODUCTIVIDAD
// ==========================================
class FormularioProductividad extends StatefulWidget {
  final Map<String, dynamic> datosEmpleado;
  final Map<String, dynamic>? registroExistente;
  final VoidCallback onGuardado;

  const FormularioProductividad({
    super.key,
    required this.datosEmpleado,
    this.registroExistente,
    required this.onGuardado,
  });

  @override
  State<FormularioProductividad> createState() => _FormularioProductividadState();
}

class _FormularioProductividadState extends State<FormularioProductividad> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // LISTAS INDEPENDIENTES
  List<String> _listaOperarios = [];
  bool _cargandoOperarios = true;

  List<String> _listaSupervisores = [];
  bool _cargandoSupervisores = true;

  List<String> _listaOpm = [];
  bool _cargandoOpm = true;

  late final TextEditingController _fechaController;
  late String _turnoSeleccionado;

  final List<String> _opcionesTurno = ['T1', 'T2', 'T3'];

  late final TextEditingController _supervisorController;
  late final TextEditingController _opmController;
  late final TextEditingController _operarioController;
  late final TextEditingController _clasificadasController;
  late final TextEditingController _reparadasController;
  late final TextEditingController _tipoCController;

  late String _causalSeleccionada;
  final List<String> _opcionesCausal = [
    'Ninguna', 'LLuvias', 'Renuncia', 'Separando tablilla', 'Fluido electrico', 'Trabajos de contratista (Infrastructura)',
    'Falla Estructural', 'Sin puntillas', 'Sin inventario de estibas tipo B', 'Ausentismo',
    'Estado de salud (Enfermeria)', 'Pistola de aire (Mal estado)', 'Bomba de aire (En mal estado )', 'Sin estibas tipo B'
  ];

  late String _causalTipoCSeleccionada;
  final List<String> _opcionesCausalTipoC = ['Ninguna', 'Estibas 6 tablillas', 'Estibas con hongo', 'Estibas sin listones', 'Estibas con 8 tablillas'];

  @override
  void initState() {
    super.initState();

    final item = widget.registroExistente;
    _fechaController = TextEditingController(text: item?['fecha']?.toString().substring(0, 10) ?? DateTime.now().toString().substring(0, 10));

    final turnoValor = item?['turno'] ?? 'T1';
    _turnoSeleccionado = _opcionesTurno.contains(turnoValor) ? turnoValor : 'T1';

    _operarioController = TextEditingController(text: item?['operario'] ?? '');
    _supervisorController = TextEditingController(text: item?['supervisor'] ?? '');
    _opmController = TextEditingController(text: item?['opm'] ?? '');
    _reparadasController = TextEditingController(text: item?['reparadas']?.toString() ?? '');
    _clasificadasController = TextEditingController(text: item?['clasificadas']?.toString() ?? '');
    _tipoCController = TextEditingController(text: item?['tipo_c']?.toString() ?? '');

    _causalSeleccionada = _opcionesCausal.contains(item?['causal']) ? item!['causal'] : 'Ninguna';
    _causalTipoCSeleccionada = _opcionesCausalTipoC.contains(item?['causal_tipo_c']) ? item!['causal_tipo_c'] : 'Ninguna';

    _cargarOperarios();
    _cargarSupervisores();
    _cargarOpm();
  }

  // 🛡️ REGLAS INTELIGENTES EN LOS 3 BUSCADORES PARA EVITAR CARGAS INFINITAS
  Future<void> _cargarOperarios() async {
    try {
      final url = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/consultar/estibas/estibas_usaurios');
      final res = await http.get(url, headers: {'Content-Type': 'application/json', 'x-api-key': ApiService.apiKey});
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        List items = decoded is List ? decoded : (decoded['data'] ?? []);
        final lista = items.map((e) => (e['nombre'] ?? '').toString().trim()).where((n) => n.isNotEmpty).toSet().toList();
        if (mounted) setState(() { _listaOperarios = lista; _cargandoOperarios = false; });
      }
    } catch (e) { if (mounted) setState(() => _cargandoOperarios = false); }
  }

  Future<void> _cargarSupervisores() async {
    try {
      final url = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/consultar/roturas/rotura_lista');
      final res = await http.get(url, headers: {'Content-Type': 'application/json', 'x-api-key': ApiService.apiKey});
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        List items = decoded is List ? decoded : (decoded['data'] ?? []);
        final lista = items.map((e) => (e['supervisor'] ?? '').toString().trim()).where((n) => n.isNotEmpty && n != 'NO APLICA').toSet().toList();
        if (mounted) setState(() { _listaSupervisores = lista; _cargandoSupervisores = false; });
      }
    } catch (e) { if (mounted) setState(() => _cargandoSupervisores = false); }
  }

  Future<void> _cargarOpm() async {
    try {
      final url = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/consultar/roturas/rotura_lista');
      final res = await http.get(url, headers: {'Content-Type': 'application/json', 'x-api-key': ApiService.apiKey});
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        List items = decoded is List ? decoded : (decoded['data'] ?? []);
        final lista = items.map((e) => (e['personal'] ?? '').toString().trim()).where((n) => n.isNotEmpty).toSet().toList();
        if (mounted) setState(() { _listaOpm = lista; _cargandoOpm = false; });
      }
    } catch (e) { if (mounted) setState(() => _cargandoOpm = false); }
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final hace2Dias = hoy.subtract(const Duration(days: 2)); // Máximo 48 horas (2 días atrás)

    DateTime initial = DateTime.parse(_fechaController.text);
    if (initial.isBefore(hace2Dias)) initial = hace2Dias;
    if (initial.isAfter(hoy)) initial = hoy;

    final DateTime? seleccion = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: hace2Dias,
      lastDate: hoy,
      helpText: 'SELECCIONA FECHA (MÁXIMO 48 HORAS ATRÁS)',
    );
    if (seleccion != null) setState(() => _fechaController.text = seleccion.toString().substring(0, 10));
  }

  void _confirmarGuardado() {
    if (!_formKey.currentState!.validate()) return;

    if (_operarioController.text.isEmpty || _supervisorController.text.isEmpty || _opmController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecciona Operario, Supervisor y OPM'), backgroundColor: Colors.red));
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
                    onPressed: () { Navigator.pop(ctx); _guardarEnApi(); },
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

  Future<void> _guardarEnApi() async {
    setState(() => _isSaving = true);
    try {
      final datosMap = {
        'fecha_de_reporte': widget.registroExistente?['fecha_de_reporte'] ?? DateTime.now().toIso8601String(),
        'fecha': _fechaController.text,
        'turno': _turnoSeleccionado,
        'supervisor': _supervisorController.text.trim(),
        'opm': _opmController.text.trim(),
        'operario': _operarioController.text.trim(),
        'clasificadas': int.tryParse(_clasificadasController.text) ?? 0,
        'reparadas': int.tryParse(_reparadasController.text) ?? 0,
        'tipo_c': int.tryParse(_tipoCController.text) ?? 0,
        'causal': _causalSeleccionada,
        'causal_tipo_c': _causalTipoCSeleccionada,
      };

      bool ok = false;
      final isEdit = widget.registroExistente != null;

      // 🛡️ GUARDADO DIRECTO
      final url = isEdit
          ? Uri.parse('${ApiService.baseUrl}/${ApiService.database}/actualizar/${ApiService.schema}/reparacion_estibas/${widget.registroExistente!['id']}')
          : Uri.parse('${ApiService.baseUrl}/${ApiService.database}/insertar/${ApiService.schema}/reparacion_estibas');

      final response = isEdit
          ? await http.put(url, headers: {'Content-Type': 'application/json', 'x-api-key': ApiService.apiKey}, body: jsonEncode(datosMap))
          : await http.post(url, headers: {'Content-Type': 'application/json', 'x-api-key': ApiService.apiKey}, body: jsonEncode(datosMap));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final resJson = jsonDecode(response.body);
        if (resJson is Map) {
          ok = resJson['exito'] == true || resJson['success'] == true;
        } else {
          ok = true; // Si el servidor respondió con lista o string puro pero con 200, asumimos éxito.
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
                const Text('El registro se guardó con éxito.', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 20),
                ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green), onPressed: () { Navigator.pop(ctx); widget.onGuardado(); }, child: const Text('Aceptar', style: TextStyle(color: Colors.white)))
              ],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al guardar en el servidor'), backgroundColor: Colors.red));
        setState(() => _isSaving = false);
      }
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)); setState(() => _isSaving = false); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.registroExistente != null;
    final paddingBottom = MediaQuery.of(context).padding.bottom;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      padding: EdgeInsets.only(top: 24, left: 24, right: 24, bottom: paddingBottom + keyboardHeight),
      height: MediaQuery.of(context).size.height * 0.9,
      child: Column(
        children: [
          Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 20),
          Text(esEdicion ? 'Editar Productividad' : 'Nueva Productividad', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
          const SizedBox(height: 20),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  Row(
                    children: [
                      Expanded(child: _crearCampo(controller: _fechaController, label: 'Fecha', icono: Icons.calendar_today_outlined, soloLectura: true, onTap: () => _seleccionarFecha(context))),
                      const SizedBox(width: 15),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _turnoSeleccionado,
                          decoration: InputDecoration(labelText: 'Turno', prefixIcon: const Icon(Icons.access_time, color: Color(0xFF1565C0)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          items: _opcionesTurno.map((String val) => DropdownMenuItem(value: val, child: Text(val, style: const TextStyle(fontSize: 14)))).toList(),
                          onChanged: (val) => setState(() => _turnoSeleccionado = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  _crearBuscador(controller: _operarioController, label: 'Buscar Operario', icono: Icons.person_search_outlined, opciones: _listaOperarios, cargando: _cargandoOperarios),
                  const SizedBox(height: 15),
                  _crearBuscador(controller: _supervisorController, label: 'Buscar Supervisor', icono: Icons.admin_panel_settings_outlined, opciones: _listaSupervisores, cargando: _cargandoSupervisores),
                  const SizedBox(height: 15),
                  _crearBuscador(controller: _opmController, label: 'Buscar OPM', icono: Icons.tag, opciones: _listaOpm, cargando: _cargandoOpm),

                  const Divider(height: 40, thickness: 1),
                  Row(
                    children: [
                      Expanded(child: _crearCampo(controller: _reparadasController, label: 'Reparadas', icono: Icons.build_circle_outlined, esNumero: true)),
                      const SizedBox(width: 15),
                      Expanded(child: _crearCampo(controller: _clasificadasController, label: 'Clasificadas', icono: Icons.rule_outlined, esNumero: true)),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _crearCampo(controller: _tipoCController, label: 'Cantidad Tipo C', icono: Icons.warning_amber_rounded, esNumero: true),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _causalSeleccionada,
                    decoration: InputDecoration(labelText: 'Causal General', prefixIcon: const Icon(Icons.edit_note, color: Color(0xFF1565C0)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    items: _opcionesCausal.map((String val) => DropdownMenuItem(value: val, child: Text(val, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (val) => setState(() => _causalSeleccionada = val!),
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _causalTipoCSeleccionada,
                    decoration: InputDecoration(labelText: 'Causal Tipo C', prefixIcon: const Icon(Icons.feedback_outlined, color: Color(0xFF1565C0)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    items: _opcionesCausalTipoC.map((String val) => DropdownMenuItem(value: val, child: Text(val, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (val) => setState(() => _causalTipoCSeleccionada = val!),
                  ),
                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: esEdicion ? Colors.orange : const Color(0xFF0D47A1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      onPressed: _isSaving ? null : _confirmarGuardado,
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(esEdicion ? 'ACTUALIZAR REGISTRO' : 'GUARDAR PRODUCTIVIDAD', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
    return TextFormField(
      controller: controller,
      readOnly: soloLectura,
      onTap: onTap,
      keyboardType: esNumero ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icono, color: const Color(0xFF1565C0)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: soloLectura && onTap == null ? Colors.grey[200] : Colors.white,
      ),
      validator: (value) => (!soloLectura && (value == null || value.isEmpty) && !esNumero) ? 'Requerido' : null,
    );
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