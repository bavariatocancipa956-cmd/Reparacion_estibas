import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import 'pdf_5why_service.dart';

// =========================================================================
// 1. PANTALLA PRINCIPAL: PANEL GLOBAL CON HISTORIAL Y RETROALIMENTACIÓN
// =========================================================================
class Gestion5WhyScreen extends StatefulWidget {
  final Map<String, dynamic> datosEmpleado;

  const Gestion5WhyScreen({super.key, required this.datosEmpleado});

  @override
  State<Gestion5WhyScreen> createState() => _Gestion5WhyScreenState();
}

class _Gestion5WhyScreenState extends State<Gestion5WhyScreen> {
  bool _isListLoading = true;
  List<Map<String, dynamic>> _allReportes = [];
  List<Map<String, dynamic>> _reportesFiltrados = [];

  String _filterMes = 'Todos';
  String _filterArea = 'Todos';
  String _filterPi = 'Todos';

  final List<String> _mesesOpciones = [
    'Todos', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
  ];

  List<String> _areasOpciones = ['Todos'];
  List<String> _piOpciones = ['Todos'];

  @override
  void initState() {
    super.initState();
    _cargarFiltrosYDatos();
  }

  Future<void> _cargarFiltrosYDatos() async {
    setState(() => _isListLoading = true);

    try {
      // CARGAR LISTAS PARA FILTROS
      final urlListas = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/consultar/gestion/lista_5why');
      final resListas = await http.get(urlListas, headers: {
        'Content-Type': 'application/json',
        'x-api-key': ApiService.apiKey,
      });

      if (resListas.statusCode == 200) {
        final decodedListas = jsonDecode(resListas.body);
        List<dynamic> dataListas = [];

        // 🛡️ REGLA INTELIGENTE DE LECTURA
        if (decodedListas is List) {
          dataListas = decodedListas;
        } else if (decodedListas is Map<String, dynamic> && decodedListas['data'] != null) {
          dataListas = decodedListas['data'] is List ? decodedListas['data'] : [];
        }

        final areasDB = dataListas.map((e) => (e['areas'] ?? '').toString().toUpperCase().trim()).where((s) => s.isNotEmpty).toSet().toList()..sort();
        final pisDB = dataListas.map((e) => (e['pi'] ?? '').toString().toUpperCase().trim()).where((s) => s.isNotEmpty).toSet().toList()..sort();

        _areasOpciones = ['Todos', ...areasDB];
        _piOpciones = ['Todos', ...pisDB];
      }

      // CARGAR HISTORIAL DE REPORTES
      final urlReportes = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/consultar/gestion/5why');
      final resReportes = await http.get(urlReportes, headers: {
        'Content-Type': 'application/json',
        'x-api-key': ApiService.apiKey,
      });

      if (resReportes.statusCode == 200) {
        final decodedReportes = jsonDecode(resReportes.body);
        List<dynamic> dataReportes = [];

        // 🛡️ REGLA INTELIGENTE DE LECTURA
        if (decodedReportes is List) {
          dataReportes = decodedReportes;
        } else if (decodedReportes is Map<String, dynamic> && decodedReportes['data'] != null) {
          dataReportes = decodedReportes['data'] is List ? decodedReportes['data'] : [];
        }

        _allReportes = List<Map<String, dynamic>>.from(dataReportes);
      } else {
        _allReportes = [];
      }

      if (mounted) {
        setState(() {
          _aplicarFiltrosEstructurados();
          _isListLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isListLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al sincronizar datos: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _aplicarFiltrosEstructurados() {
    setState(() {
      _reportesFiltrados = _allReportes.where((item) {
        if (_filterMes != 'Todos') {
          final fechaStr = (item['fecha_evento'] ?? item['fecha_creacion'] ?? '').toString();
          if (fechaStr.isEmpty) return false;
          try {
            DateTime fecha = DateTime.parse(fechaStr);
            if (_mesesOpciones[fecha.month] != _filterMes.toLowerCase()) return false;
          } catch (_) {
            return false;
          }
        }

        if (_filterArea != 'Todos') {
          if (item['area']?.toString().toUpperCase() != _filterArea.toUpperCase()) return false;
        }

        if (_filterPi != 'Todos') {
          if (item['pi']?.toString().toUpperCase() != _filterPi.toUpperCase()) return false;
        }

        return true;
      }).toList();
    });
  }

  void _mostrarPestaanaFlotanteRetroalimentacion(BuildContext context, String mensajeRetro, String areaReporte) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.assignment_late_rounded, color: Colors.amber.shade900, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Notas $areaReporte',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.black45),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    mensajeRetro,
                    style: const TextStyle(fontSize: 13.5, color: Colors.black87, fontWeight: FontWeight.w500, height: 1.4),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('ENTENDIDO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  void _mostrarDetalleReporte(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.description_rounded, color: Color(0xFF0D47A1)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Reporte 5W - ${item['area'] ?? ''}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _itemDetalle('Fecha Evento:', item['fecha_evento'] ?? 'N/A'),
              _itemDetalle('Área:', item['area'] ?? 'N/A'),
              _itemDetalle('PI:', item['pi'] ?? 'N/A'),
              _itemDetalle('Turno:', item['turno'] ?? 'N/A'),
              _itemDetalle('Supervisor:', item['supervisor'] ?? 'N/A'),
              _itemDetalle('Involucrados:', item['involucrados'] ?? 'N/A'),
              const Divider(),
              _itemDetalle('Descripción:', item['descripcion'] ?? 'N/A'),
              _itemDetalle('Contención:', item['contencion'] ?? 'N/A'),
              const Divider(),
              _itemDetalle('1. ¿Por qué?:', item['porque_1'] ?? 'N/A'),
              _itemDetalle('2. ¿Por qué?:', item['porque_2'] ?? 'N/A'),
              _itemDetalle('3. ¿Por qué?:', item['porque_3'] ?? 'N/A'),
              if ((item['porque_4'] ?? '').toString().isNotEmpty) _itemDetalle('4. ¿Por qué?:', item['porque_4']),
              if ((item['porque_5'] ?? '').toString().isNotEmpty) _itemDetalle('5. ¿Por qué?:', item['porque_5']),
              const Divider(),
              _itemDetalle('Causa Raíz:', item['causa_raiz'] ?? 'N/A'),
              _itemDetalle('Acción Preventiva:', item['accion_preventiva'] ?? 'N/A'),
              _itemDetalle('Acción Reactiva:', item['accion_reactiva'] ?? 'N/A'),
              if ((item['accion_1'] ?? '').toString().isNotEmpty) ...[
                const Divider(),
                _itemDetalle('Acción 1:', item['accion_1']),
                _itemDetalle('Responsable 1:', item['responsable_1'] ?? 'N/A'),
                _itemDetalle('Plazo 1:', item['fecha_plazo'] ?? 'N/A'),
              ],
              if ((item['accion_2'] ?? '').toString().isNotEmpty) ...[
                const Divider(),
                _itemDetalle('Acción 2:', item['accion_2']),
                _itemDetalle('Responsable 2:', item['responsable_2'] ?? 'N/A'),
                _itemDetalle('Plazo 2:', item['fecha_plazo_2'] ?? 'N/A'),
              ],
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _itemDetalle(String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          children: [
            TextSpan(text: '$titulo ', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
            TextSpan(text: valor),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Panel Global de 5W',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Form5WhyScreen(datosEmpleado: widget.datosEmpleado),
                  ),
                );
                if (result == true) _cargarFiltrosYDatos();
              },
              icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: Colors.white),
              label: const Text(
                'Realizar 5 Why',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildSelectorFiltroNativo('Filtrar Mes', _filterMes, _mesesOpciones, (v) {
                      setState(() => _filterMes = v!);
                      _aplicarFiltrosEstructurados();
                    })),
                    const SizedBox(width: 12),
                    Expanded(child: _buildSelectorFiltroNativo('Filtrar Área', _filterArea, _areasOpciones, (v) {
                      setState(() => _filterArea = v!);
                      _aplicarFiltrosEstructurados();
                    })),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSelectorFiltroNativo('Filtrar Causa (PI)', _filterPi, _piOpciones, (v) {
                  setState(() => _filterPi = v!);
                  _aplicarFiltrosEstructurados();
                }),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: _cargarFiltrosYDatos,
                    icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF0D47A1)),
                    label: const Text(
                      'ACTUALIZAR TABLA',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1), letterSpacing: 0.5),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFE3F2FD).withValues(alpha: 0.4),
                      side: const BorderSide(color: Color(0xFFB3E5FC), width: 1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isListLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1)))
                : _reportesFiltrados.isEmpty
                ? const Center(child: Text('No hay análisis con los filtros seleccionados.', style: TextStyle(color: Colors.black38, fontSize: 13, fontWeight: FontWeight.bold)))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: _reportesFiltrados.length,
              itemBuilder: (context, index) {
                final item = _reportesFiltrados[index];
                final String area = (item['area'] ?? 'N/A').toString();
                final String pi = (item['pi'] ?? 'N/A').toString();
                final String descripcion = (item['descripcion'] ?? item['problema'] ?? 'Sin descripción').toString();
                final String fecha = (item['fecha_evento'] ?? '').toString();
                final String supervisor = (item['supervisor'] ?? 'No Definido').toString();
                final String estatus = (item['estatus'] ?? 'PENDIENTE REVISION').toString();

                final String retroalimentacion = (item['retroalimentacion'] ?? '').toString().trim();

                bool esEditable = estatus.toUpperCase() == 'PENDIENTE REVISION' || estatus.toUpperCase() == 'PENDIENTE' || estatus.toUpperCase() == 'RECHAZADO';
                bool tieneRetro = retroalimentacion.isNotEmpty;

                Color badgeBgColor;
                Color badgeTextColor;
                String badgeText = estatus.toUpperCase();

                if (estatus.toUpperCase() == 'PENDIENTE REVISION' || estatus.toUpperCase() == 'PENDIENTE') {
                  badgeBgColor = const Color(0xFFFFF3E0);
                  badgeTextColor = Colors.orange.shade800;
                  badgeText = 'PENDIENTE';
                } else if (estatus.toUpperCase() == 'RECHAZADO') {
                  badgeBgColor = const Color(0xFFFFEBEE);
                  badgeTextColor = Colors.red.shade800;
                } else {
                  badgeBgColor = const Color(0xFFE8F5E9);
                  badgeTextColor = Colors.green.shade800;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              'ÁREA: ${area.toUpperCase()}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: -0.2),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: badgeBgColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                color: badgeTextColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Fecha Evento: $fecha', style: const TextStyle(fontSize: 11.5, color: Colors.black54, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text('PI Detectado: $pi', style: const TextStyle(fontSize: 11.5, color: Colors.black54, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text('Supervisor: $supervisor', style: const TextStyle(fontSize: 11.5, color: Colors.black54, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            const Text('Descripción del Problema:', style: TextStyle(fontSize: 11, color: Colors.black45, fontWeight: FontWeight.bold)),
                            Text(descripcion, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.2)),
                          ],
                        ),
                      ),

                      if (tieneRetro) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 38,
                          child: ElevatedButton.icon(
                            onPressed: () => _mostrarPestaanaFlotanteRetroalimentacion(context, retroalimentacion, area),
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFFE65100)),
                            label: const Text('Ver Retroalimentación', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFF3E0),
                              foregroundColor: const Color(0xFFE65100),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.amber.shade300)),
                            ),
                          ),
                        )
                      ],

                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (esEditable)
                            Expanded(
                              flex: 2,
                              child: SWidthButton(
                                label: 'REVISAR Y EDITAR',
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => Form5WhyScreen(
                                        datosEmpleado: widget.datosEmpleado,
                                        recordModificar: item,
                                      ),
                                    ),
                                  );
                                  if (result == true) _cargarFiltrosYDatos();
                                },
                              ),
                            )
                          else
                            Expanded(
                              flex: 2,
                              child: SWidthButton(
                                label: 'VER DETALLE COMPLETO',
                                onPressed: () => _mostrarDetalleReporte(item),
                              ),
                            ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 1,
                            child: SizedBox(
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: () => Pdf5WhyService.abrirVisorPdf(context, item),
                                icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Color(0xFFB71C1C)),
                                label: const Text('PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB71C1C))),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFEBEE),
                                  side: BorderSide(color: Colors.red.shade200),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorFiltroNativo(String label, String value, List<String> opciones, ValueChanged<String?> onChanged) {
    if (!opciones.contains(value)) value = opciones.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black45)),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              isDense: true,
              style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600),
              items: opciones.map((String op) => DropdownMenuItem(value: op, child: Text(op, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class SWidthButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const SWidthButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0D47A1),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ),
    );
  }
}

// =========================================================================
// 2. FORMULARIO INTERACTIVO SECUNDARIO (CREACIÓN Y EDICIÓN)
// =========================================================================
class Form5WhyScreen extends StatefulWidget {
  final Map<String, dynamic> datosEmpleado;
  final Map<String, dynamic>? recordModificar;

  const Form5WhyScreen({super.key, required this.datosEmpleado, this.recordModificar});

  @override
  State<Form5WhyScreen> createState() => _Form5WhyScreenState();
}

class _Form5WhyScreenState extends State<Form5WhyScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isDropdownsLoading = true;
  bool _isSaving = false;
  bool _mostrarAccion2 = false;

  DateTime _fechaEvento = DateTime.now();

  String _selectedArea = 'CARGANDO...';
  String _selectedPi = 'CARGANDO...';
  String _selectedTurno = 'T1';
  String _selectedSupervisor = 'CARGANDO...';

  final TextEditingController _liderController = TextEditingController();
  final TextEditingController _part2Controller = TextEditingController();
  final TextEditingController _part3Controller = TextEditingController();
  final TextEditingController _part4Controller = TextEditingController();

  final TextEditingController _descripcionController = TextEditingController();
  final TextEditingController _contencionController = TextEditingController();

  final TextEditingController _porque1Controller = TextEditingController();
  final TextEditingController _porque2Controller = TextEditingController();
  final TextEditingController _porque3Controller = TextEditingController();
  final TextEditingController _porque4Controller = TextEditingController();
  final TextEditingController _porque5Controller = TextEditingController();

  final TextEditingController _causaRaizController = TextEditingController();
  final TextEditingController _accionPreventivaController = TextEditingController();
  final TextEditingController _accionReactivaController = TextEditingController();

  // Acción 1
  final TextEditingController _accion1Controller = TextEditingController();
  final TextEditingController _responsable1Controller = TextEditingController();
  DateTime? _fechaPlazo1;

  // Acción 2
  final TextEditingController _accion2Controller = TextEditingController();
  final TextEditingController _responsable2Controller = TextEditingController();
  DateTime? _fechaPlazo2;

  final List<String> _turnosOpciones = ['T1', 'T2', 'T3'];

  List<String> _areasOpciones = ['CARGANDO...'];
  List<String> _piOpciones = ['CARGANDO...'];
  List<String> _supervisoresOpciones = ['CARGANDO...'];

  @override
  void initState() {
    super.initState();
    _cargarConfiguracionEInyeccion();
  }

  Future<void> _cargarConfiguracionEInyeccion() async {
    try {
      final urlSup = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/consultar/roturas/rotura_lista');
      final resSup = await http.get(urlSup, headers: {'Content-Type': 'application/json', 'x-api-key': ApiService.apiKey});

      List<String> supervisoresList = [];
      if (resSup.statusCode == 200) {
        final decodedSup = jsonDecode(resSup.body);
        List<dynamic> dataSup = [];

        // 🛡️ REGLA INTELIGENTE DE LECTURA
        if (decodedSup is List) {
          dataSup = decodedSup;
        } else if (decodedSup is Map<String, dynamic> && decodedSup['data'] != null) {
          dataSup = decodedSup['data'] is List ? decodedSup['data'] : [];
        }

        supervisoresList = dataSup
            .map((e) => (e['supervisor'] ?? '').toString())
            .where((s) => s.isNotEmpty && s.toUpperCase() != 'NO APLICA')
            .map((s) => s.replaceAll(RegExp(r'[0-9-]'), '').replaceAll(RegExp(r'\s+'), ' ').trim())
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList()..sort();
      }

      final urlListas = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/consultar/gestion/lista_5why');
      final resListas = await http.get(urlListas, headers: {'Content-Type': 'application/json', 'x-api-key': ApiService.apiKey});

      List<String> areasList = [];
      List<String> pisList = [];
      if (resListas.statusCode == 200) {
        final decodedListas = jsonDecode(resListas.body);
        List<dynamic> dataListas = [];

        // 🛡️ REGLA INTELIGENTE DE LECTURA
        if (decodedListas is List) {
          dataListas = decodedListas;
        } else if (decodedListas is Map<String, dynamic> && decodedListas['data'] != null) {
          dataListas = decodedListas['data'] is List ? decodedListas['data'] : [];
        }

        areasList = dataListas.map((e) => (e['areas'] ?? '').toString().toUpperCase().trim()).where((s) => s.isNotEmpty).toSet().toList()..sort();
        pisList = dataListas.map((e) => (e['pi'] ?? '').toString().toUpperCase().trim()).where((s) => s.isNotEmpty).toSet().toList()..sort();
      }

      if (mounted) {
        setState(() {
          _supervisoresOpciones = supervisoresList.isNotEmpty ? supervisoresList : ['SIN SUPERVISORES'];
          _selectedSupervisor = _supervisoresOpciones.first;

          _areasOpciones = areasList.isNotEmpty ? areasList : ['SIN ÁREAS'];
          _selectedArea = _areasOpciones.first;

          _piOpciones = pisList.isNotEmpty ? pisList : ['SIN PI'];
          _selectedPi = _piOpciones.first;

          if (widget.recordModificar != null) {
            final r = widget.recordModificar!;
            if (r['fecha_evento'] != null) {
              try { _fechaEvento = DateTime.parse(r['fecha_evento'].toString()); } catch (_) {}
            }

            String areaRec = (r['area'] ?? '').toString().toUpperCase().trim();
            if (_areasOpciones.contains(areaRec)) {
              _selectedArea = areaRec;
            } else if (areaRec.isNotEmpty) {
              _areasOpciones.add(areaRec);
              _selectedArea = areaRec;
            }

            String piRec = (r['pi'] ?? '').toString().toUpperCase().trim();
            if (_piOpciones.contains(piRec)) {
              _selectedPi = piRec;
            } else if (piRec.isNotEmpty) {
              _piOpciones.add(piRec);
              _selectedPi = piRec;
            }

            if (_turnosOpciones.contains(r['turno'])) _selectedTurno = r['turno'].toString();

            String supClean = (r['supervisor'] ?? '').toString().replaceAll(RegExp(r'[0-9-]'), '').trim();
            if (_supervisoresOpciones.contains(supClean)) {
              _selectedSupervisor = supClean;
            } else if (supClean.isNotEmpty) {
              _supervisoresOpciones.add(supClean);
              _selectedSupervisor = supClean;
            }

            String eq = (r['involucrados'] ?? '').toString();
            _liderController.text = _extraerMiembroEquipo(eq, 'Líder:');
            _part2Controller.text = _extraerMiembroEquipo(eq, 'P2:');
            _part3Controller.text = _extraerMiembroEquipo(eq, 'P3:');
            _part4Controller.text = _extraerMiembroEquipo(eq, 'P4:');

            _descripcionController.text = (r['descripcion'] ?? '').toString();
            _contencionController.text = (r['contencion'] ?? '').toString();
            _porque1Controller.text = (r['porque_1'] ?? '').toString();
            _porque2Controller.text = (r['porque_2'] ?? '').toString();
            _porque3Controller.text = (r['porque_3'] ?? '').toString();
            _porque4Controller.text = (r['porque_4'] ?? '').toString();
            _porque5Controller.text = (r['porque_5'] ?? '').toString();
            _causaRaizController.text = (r['causa_raiz'] ?? '').toString();
            _accionPreventivaController.text = (r['accion_preventiva'] ?? '').toString();
            _accionReactivaController.text = (r['accion_reactiva'] ?? '').toString();
            _accion1Controller.text = (r['accion_1'] ?? '').toString();
            _responsable1Controller.text = (r['responsable_1'] ?? '').toString();
            if (r['fecha_plazo'] != null) {
              try { _fechaPlazo1 = DateTime.parse(r['fecha_plazo'].toString()); } catch (_) {}
            }

            _accion2Controller.text = (r['accion_2'] ?? '').toString();
            _responsable2Controller.text = (r['responsable_2'] ?? '').toString();
            if (r['fecha_plazo_2'] != null) {
              try { _fechaPlazo2 = DateTime.parse(r['fecha_plazo_2'].toString()); } catch (_) {}
            }

            // Si hay datos cargados en Acción 2, se abre automáticamente el bloque
            if (_accion2Controller.text.isNotEmpty || _responsable2Controller.text.isNotEmpty || _fechaPlazo2 != null) {
              _mostrarAccion2 = true;
            }
          }
          _isDropdownsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _supervisoresOpciones = ['ERROR DE RED'];
          _selectedSupervisor = 'ERROR DE RED';
          _areasOpciones = ['ERROR DE RED'];
          _selectedArea = 'ERROR DE RED';
          _piOpciones = ['ERROR DE RED'];
          _selectedPi = 'ERROR DE RED';
          _isDropdownsLoading = false;
        });
      }
    }
  }

  String _extraerMiembroEquipo(String fullText, String prefix) {
    if (!fullText.contains(prefix)) return '';
    try {
      final partes = fullText.split(prefix);
      if (partes.length > 1) {
        return partes[1].split('|').first.trim();
      }
    } catch (_) {}
    return fullText;
  }

  @override
  void dispose() {
    _liderController.dispose();
    _part2Controller.dispose();
    _part3Controller.dispose();
    _part4Controller.dispose();
    _descripcionController.dispose();
    _contencionController.dispose();
    _porque1Controller.dispose();
    _porque2Controller.dispose();
    _porque3Controller.dispose();
    _porque4Controller.dispose();
    _porque5Controller.dispose();
    _causaRaizController.dispose();
    _accionPreventivaController.dispose();
    _accionReactivaController.dispose();
    _accion1Controller.dispose();
    _responsable1Controller.dispose();
    _accion2Controller.dispose();
    _responsable2Controller.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFechaPlazo1() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaPlazo1 ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _fechaPlazo1 = picked);
    }
  }

  Future<void> _seleccionarFechaPlazo2() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaPlazo2 ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _fechaPlazo2 = picked);
    }
  }

  Future<void> _seleccionarFechaEvento() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaEvento,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _fechaEvento) {
      setState(() => _fechaEvento = picked);
    }
  }

  Future<void> _procesarGuardado() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSupervisor.contains('CARGANDO') || _selectedSupervisor.contains('ERROR')) return;
    if (_selectedArea.contains('CARGANDO') || _selectedArea.contains('ERROR')) return;

    setState(() => _isSaving = true);

    try {
      String equipoConcatenado = 'Líder: ${_liderController.text.trim()}';
      if (_part2Controller.text.isNotEmpty) equipoConcatenado += ' | P2: ${_part2Controller.text.trim()}';
      if (_part3Controller.text.isNotEmpty) equipoConcatenado += ' | P3: ${_part3Controller.text.trim()}';
      if (_part4Controller.text.isNotEmpty) equipoConcatenado += ' | P4: ${_part4Controller.text.trim()}';

      final Map<String, dynamic> dataMap = {
        'fecha_evento': _fechaEvento.toString().substring(0, 10),
        'area': _selectedArea,
        'pi': _selectedPi,
        'turno': _selectedTurno,
        'descripcion': _descripcionController.text.trim(),
        'supervisor': _selectedSupervisor,
        'involucrados': equipoConcatenado,
        'contencion': _contencionController.text.trim(),
        'porque_1': _porque1Controller.text.trim(),
        'porque_2': _porque2Controller.text.trim(),
        'porque_3': _porque3Controller.text.trim(),
        'porque_4': _porque4Controller.text.trim(),
        'porque_5': _porque5Controller.text.trim(),
        'causa_raiz': _causaRaizController.text.trim(),
        'accion_preventiva': _accionPreventivaController.text.trim(),
        'accion_reactiva': _accionReactivaController.text.trim(),
        'accion_1': _accion1Controller.text.trim(),
        'responsable_1': _responsable1Controller.text.trim(),
        'fecha_plazo': _fechaPlazo1 != null ? _fechaPlazo1!.toString().substring(0, 10) : null,
        'accion_2': _mostrarAccion2 ? _accion2Controller.text.trim() : null,
        'responsable_2': _mostrarAccion2 ? _responsable2Controller.text.trim() : null,
        'fecha_plazo_2': (_mostrarAccion2 && _fechaPlazo2 != null) ? _fechaPlazo2!.toString().substring(0, 10) : null,
        'estatus': 'PENDIENTE REVISION',
      };

      if (widget.recordModificar != null) {
        final id = widget.recordModificar!['id'];
        final urlUpdate = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/actualizar/gestion/5why/$id');
        final response = await http.put(
          urlUpdate,
          headers: {'Content-Type': 'application/json', 'x-api-key': ApiService.apiKey},
          body: jsonEncode(dataMap),
        );
        if (response.statusCode != 200 && response.statusCode != 201) throw Exception('Error en el servidor');
      } else {
        final urlInsert = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/insertar/gestion/5why');
        final response = await http.post(
          urlInsert,
          headers: {'Content-Type': 'application/json', 'x-api-key': ApiService.apiKey},
          body: jsonEncode(dataMap),
        );
        if (response.statusCode != 200 && response.statusCode != 201) throw Exception('Error en el servidor');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Análisis guardado exitosamente.'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error en guardado: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool esEdicion = widget.recordModificar != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0D47A1),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(esEdicion ? 'Modificar 5 Why' : 'Nuevo Análisis 5 Why', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
      ),
      body: _isDropdownsLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1)))
          : Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            children: [
              _buildContenedorSeccion(
                titulo: 'Datos del Evento',
                icon: Icons.analytics_outlined,
                hijos: [
                  Row(
                    children: [
                      Expanded(child: _buildDatePickerInput('Fecha', _fechaEvento.toString().substring(0, 10), _seleccionarFechaEvento)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildDropdownInput('Área', _selectedArea, _areasOpciones, (v) => setState(() => _selectedArea = v!))),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _buildDropdownInput('PI', _selectedPi, _piOpciones, (v) => setState(() => _selectedPi = v!))),
                      const SizedBox(width: 12),
                      Expanded(child: _buildDropdownInput('Turno', _selectedTurno, _turnosOpciones, (v) => setState(() => _selectedTurno = v!))),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildDropdownInput('Supervisor de Operación', _selectedSupervisor, _supervisoresOpciones, (v) => setState(() => _selectedSupervisor = v!)),
                ],
              ),
              const SizedBox(height: 16),
              _buildContenedorSeccion(
                titulo: 'Equipo de Análisis',
                icon: Icons.groups_outlined,
                hijos: [
                  Row(
                    children: [
                      Expanded(child: _buildTextFieldInput(label: 'Líder', controller: _liderController, obligatorio: true)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTextFieldInput(label: 'Participante 2', controller: _part2Controller)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _buildTextFieldInput(label: 'Participante 3', controller: _part3Controller)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTextFieldInput(label: 'Participante 4', controller: _part4Controller)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildContenedorSeccion(
                titulo: 'Problema',
                icon: Icons.report_problem_outlined,
                hijos: [
                  _buildTextFieldInput(label: 'Descripción del Problema', controller: _descripcionController, maxLines: 3, obligatorio: true),
                  const SizedBox(height: 14),
                  _buildTextFieldInput(label: 'Acción de Contención (Inmediata)', controller: _contencionController, maxLines: 2, esAlerta: true, obligatorio: true),
                ],
              ),
              const SizedBox(height: 16),
              _buildContenedorSeccion(
                titulo: 'Análisis de los 5 Porqués',
                icon: Icons.psychology_alt_outlined,
                hijos: [
                  _buildTextFieldInput(label: '1. ¿Por qué? (Obligatorio)', controller: _porque1Controller, obligatorio: true),
                  const SizedBox(height: 12),
                  _buildTextFieldInput(label: '2. ¿Por qué? (Obligatorio)', controller: _porque2Controller, obligatorio: true),
                  const SizedBox(height: 12),
                  _buildTextFieldInput(label: '3. ¿Por qué? (Obligatorio)', controller: _porque3Controller, obligatorio: true),
                  const SizedBox(height: 12),
                  _buildTextFieldInput(label: '4. ¿Por qué? (Opcional)', controller: _porque4Controller),
                  const SizedBox(height: 12),
                  _buildTextFieldInput(label: '5. Causa Raíz (Opcional)', controller: _porque5Controller),
                ],
              ),
              const SizedBox(height: 16),
              _buildContenedorSeccion(
                titulo: 'Conclusión',
                icon: Icons.gavel_outlined,
                hijos: [
                  _buildTextFieldInput(label: 'Causa Raíz Definida', controller: _causaRaizController, fondoAzulado: true, obligatorio: true),
                  const SizedBox(height: 14),
                  _buildTextFieldInput(label: 'Acción Preventiva', controller: _accionPreventivaController, maxLines: 2, obligatorio: true),
                  const SizedBox(height: 14),
                  _buildTextFieldInput(label: 'Acción Reactiva', controller: _accionReactivaController, maxLines: 2, obligatorio: true),
                ],
              ),
              const SizedBox(height: 16),
              _buildContenedorSeccion(
                titulo: 'Plan de Acción Solicitado',
                icon: Icons.playlist_add_check_rounded,
                hijos: [
                  const Text('Acción 1', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D47A1))),
                  const SizedBox(height: 8),
                  _buildTextFieldInput(label: 'Qué hacer', controller: _accion1Controller, obligatorio: true),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildTextFieldInput(label: 'Responsable', controller: _responsable1Controller, obligatorio: true)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDatePickerInput(
                            'Fecha Límite',
                            _fechaPlazo1 == null ? 'yyyy-mm-dd' : _fechaPlazo1!.toString().substring(0, 10),
                            _seleccionarFechaPlazo1,
                            obligatorio: true
                        ),
                      ),
                    ],
                  ),

                  if (!_mostrarAccion2) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _mostrarAccion2 = true),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Agregar Segunda Acción', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0D47A1),
                          side: const BorderSide(color: Color(0xFF0D47A1), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],

                  if (_mostrarAccion2) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Acción 2 (Opcional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D47A1))),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                          onPressed: () {
                            setState(() {
                              _mostrarAccion2 = false;
                              _accion2Controller.clear();
                              _responsable2Controller.clear();
                              _fechaPlazo2 = null;
                            });
                          },
                        ),
                      ],
                    ),
                    _buildTextFieldInput(label: 'Qué hacer (Acción 2)', controller: _accion2Controller),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildTextFieldInput(label: 'Responsable', controller: _responsable2Controller)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDatePickerInput(
                              'Fecha Límite',
                              _fechaPlazo2 == null ? 'yyyy-mm-dd' : _fechaPlazo2!.toString().substring(0, 10),
                              _seleccionarFechaPlazo2
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              _isSaving
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1)))
                  : Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF0D47A1)]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: const Color(0xFF0D47A1).withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: ElevatedButton(
                  onPressed: _procesarGuardado,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: Text(
                      esEdicion ? 'ACTUALIZAR REGISTRO 5WHY' : 'REGISTRAR ANÁLISIS 5WHY',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.1)
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContenedorSeccion({required String titulo, required IconData icon, required List<Widget> hijos}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFE3F2FD),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              border: Border(left: BorderSide(color: Color(0xFF0D47A1), width: 4)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xFF0D47A1)),
                const SizedBox(width: 8),
                Text(titulo, style: const TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.2)),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: hijos))
        ],
      ),
    );
  }

  Widget _buildTextFieldInput({required String label, required TextEditingController controller, int maxLines = 1, bool esAlerta = false, bool fondoAzulado = false, bool obligatorio = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black45)),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: obligatorio ? (v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null : null,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: esAlerta ? const Color(0xFFFFEBEE) : (fondoAzulado ? const Color(0xFFE3F2FD) : const Color(0xFFF8F9FA)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownInput(String label, String value, List<String> opciones, ValueChanged<String?> onChanged) {
    if (!opciones.contains(value)) value = opciones.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black45)),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              isDense: true,
              style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.bold),
              items: opciones.map((String op) => DropdownMenuItem(value: op, child: Text(op, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerInput(String label, String fechaTexto, VoidCallback onTap, {bool obligatorio = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black45)),
        const SizedBox(height: 5),
        FormField<bool>(
          validator: (_) => obligatorio && fechaTexto.contains('yyyy-mm') ? 'Fecha requerida' : null,
          builder: (state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: state.hasError ? Colors.red.shade700 : Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(fechaTexto, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const Icon(Icons.calendar_today_rounded, size: 15, color: Colors.black45),
                      ],
                    ),
                  ),
                ),
                if (state.hasError) ...[
                  const SizedBox(height: 6),
                  Text(state.errorText ?? '', style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                ]
              ],
            );
          },
        ),
      ],
    );
  }
}