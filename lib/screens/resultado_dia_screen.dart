import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

class ResultadoDiaScreen extends StatefulWidget {
  final Map<String, dynamic> datosEmpleado;
  const ResultadoDiaScreen({super.key, required this.datosEmpleado});

  @override
  State<ResultadoDiaScreen> createState() => _ResultadoDiaScreenState();
}

class _StatTurno {
  String nombre;
  int real = 0;
  int meta = 0;
  _StatTurno({required this.nombre});
}

class _StatSupervisor {
  String nombre;
  int real = 0;
  int meta = 0;
  _StatSupervisor({required this.nombre});
}

class _StatOperario {
  String nombre;
  String turno;
  int real;
  int meta;
  _StatOperario({
    required this.nombre,
    required this.turno,
    required this.real,
    required this.meta,
  });
}

class _ResultadoDiaScreenState extends State<ResultadoDiaScreen> {
  bool _isLoading = false;

  DateTime _fechaDesde = DateTime.now();
  DateTime _fechaHasta = DateTime.now();
  String _turnoSeleccionado = 'Todos';

  final List<String> _opcionesTurno = ['Todos', 'T1', 'T2', 'T3'];

  // KPIs
  int _totalClasificadas = 0;
  int _totalReparadas = 0;
  int _totalEstibas = 0;
  int _totalTipoC = 0;
  double _prodGlobal = 0.0;

  // Gráficos y Tablas
  Map<String, _StatSupervisor> _statsSupervisor = {};
  Map<String, _StatTurno> _statsTurno = {};
  List<_StatOperario> _topOperarios = [];

  int _pInt(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      // 🛡️ PETICIÓN DIRECTA CON LECTURA INTELIGENTE (Bypassea el error de ApiService)
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

      final String desdeStr = _fechaDesde.toString().substring(0, 10);
      final String hastaStr = _fechaHasta.toString().substring(0, 10);

      final data = dataCompleta.where((row) {
        // 🛡️ CORRECCIÓN DE CRASH FATAL: Lectura segura de fechas para evitar RangeError
        final String fechaRaw = (row['fecha'] ?? row['fecha_registro'] ?? '').toString().trim();
        final String fechaRow = fechaRaw.length >= 10 ? fechaRaw.substring(0, 10) : '';

        // Si la fecha es inválida o vacía, la descartamos sin romper la aplicación
        if (fechaRow.isEmpty) return false;

        final String turnoRow = (row['turno'] ?? '').toString().trim();

        bool coincideFecha = fechaRow.compareTo(desdeStr) >= 0 && fechaRow.compareTo(hastaStr) <= 0;
        bool coincideTurno = _turnoSeleccionado == 'Todos' || turnoRow == _turnoSeleccionado;

        return coincideFecha && coincideTurno;
      }).toList();

      int tClasif = 0, tRep = 0, tTipoC = 0, tMeta = 0;
      Map<String, _StatSupervisor> supMap = {};
      Map<String, _StatTurno> turnoMap = {};
      List<_StatOperario> opList = [];

      for (var row in data) {
        int cl = _pInt(row['clasificadas']);
        int rp = _pInt(row['reparadas']);
        int tc = _pInt(row['tipo_c']);
        int metaRow = _pInt(row['meta']) > 0 ? _pInt(row['meta']) : 160;

        String sup = (row['supervisor'] ?? 'SIN SUPERVISOR').toString().toUpperCase();
        String turnoBD = (row['turno'] ?? 'N/A').toString().trim();
        if (turnoBD.isEmpty) turnoBD = 'N/A';

        String op = (row['operario'] ?? 'DESCONOCIDO').toString().toUpperCase();

        int real = cl + rp;

        tClasif += cl;
        tRep += rp;
        tTipoC += tc;
        tMeta += metaRow;

        var sData = supMap.putIfAbsent(sup, () => _StatSupervisor(nombre: sup));
        sData.real += real;
        sData.meta += metaRow;

        var tData = turnoMap.putIfAbsent(turnoBD, () => _StatTurno(nombre: turnoBD));
        tData.real += real;
        tData.meta += metaRow;

        opList.add(_StatOperario(
          nombre: op,
          turno: turnoBD,
          real: real,
          meta: metaRow,
        ));
      }

      opList.sort((a, b) => b.real.compareTo(a.real));

      if (mounted) {
        setState(() {
          _totalClasificadas = tClasif;
          _totalReparadas = tRep;
          _totalEstibas = tClasif + tRep;
          _totalTipoC = tTipoC;
          _prodGlobal = tMeta > 0 ? (_totalEstibas / tMeta) * 100 : 0.0;
          _statsSupervisor = supMap;
          _statsTurno = turnoMap;
          _topOperarios = opList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error en ResultadoDiaScreen: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _seleccionarFecha(BuildContext context, bool isDesde) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isDesde ? _fechaDesde : _fechaHasta,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF0D47A1)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isDesde) {
          _fechaDesde = picked;
        } else {
          _fechaHasta = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Generar Resumen Diario', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 🔎 BARRA DE FILTROS SUPERIOR
            _buildFiltrosSuperiores(),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 50.0),
                child: Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1))),
              )
            else
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // 🏷️ TÍTULO Y RANGO DE FECHAS
                    _buildHeaderBanner(),
                    const SizedBox(height: 16),

                    // 📊 TARJETAS KPIS (3 Arriba, 2 Abajo)
                    _buildKpisGrid(),
                    const SizedBox(height: 20),

                    // 📈 GRÁFICO POR SUPERVISOR
                    _buildGraficoSupervisores(),
                    const SizedBox(height: 20),

                    // ⏰ TABLA POR TURNO
                    _buildTablaTurnos(),
                    const SizedBox(height: 20),

                    // 🏆 TABLA TOP OPERARIOS
                    _buildTablaTopOperarios(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 1️⃣ FILTROS SUPERIORES
  Widget _buildFiltrosSuperiores() {
    final desdeStr = _fechaDesde.toString().substring(0, 10);
    final hastaStr = _fechaHasta.toString().substring(0, 10);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DESDE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _seleccionarFecha(context, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(desdeStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const Icon(Icons.calendar_month, size: 18, color: Color(0xFF0D47A1)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('HASTA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _seleccionarFecha(context, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(hastaStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const Icon(Icons.calendar_month, size: 18, color: Color(0xFF0D47A1)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TURNO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _turnoSeleccionado,
                          isExpanded: true,
                          items: _opcionesTurno.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _turnoSeleccionado = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  icon: const Icon(Icons.search, color: Colors.white, size: 20),
                  label: const Text('Buscar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  onPressed: _cargarDatos,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2️⃣ BANNER DE ENCABEZADO Y RANGO DE FECHA
  Widget _buildHeaderBanner() {
    final desdeStr = _fechaDesde.toString().substring(0, 10);
    final hastaStr = _fechaHasta.toString().substring(0, 10);

    return Column(
      children: [
        const Text(
          'REPORTE DE PRODUCTIVIDAD',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E3A8A), letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$desdeStr al $hastaStr',
            style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ],
    );
  }

  // 3️⃣ KPIS GRID
  Widget _buildKpisGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildKpiCard('CLASIF.', _totalClasificadas.toString(), Icons.inventory_2, const Color(0xFF1E3A8A))),
            const SizedBox(width: 8),
            Expanded(child: _buildKpiCard('REPARADAS', _totalReparadas.toString(), Icons.build_rounded, const Color(0xFFF59E0B))),
            const SizedBox(width: 8),
            Expanded(child: _buildKpiCard('TOTAL', _totalEstibas.toString(), Icons.layers_rounded, const Color(0xFF2563EB))),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildKpiCard('TIPO C (MALA)', _totalTipoC.toString(), Icons.delete_outline_rounded, const Color(0xFF4B5563))),
            const SizedBox(width: 8),
            Expanded(
              child: _buildKpiCard(
                'PRODUCTIVIDAD',
                '${_prodGlobal.toStringAsFixed(1)}%',
                Icons.show_chart_rounded,
                _prodGlobal >= 100 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCard(String titulo, String valor, IconData icono, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      height: 85,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -5,
            bottom: -5,
            child: Icon(icono, size: 48, color: Colors.white.withOpacity(0.2)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(titulo, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(valor, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 4️⃣ GRÁFICO BARRAS SUPERVISORES
  Widget _buildGraficoSupervisores() {
    if (_statsSupervisor.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.bar_chart_rounded, color: Color(0xFF1E3A8A)),
                SizedBox(width: 8),
                Text('Productividad por Supervisor (%)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E3A8A))),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 180,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _statsSupervisor.entries.map((e) {
                  final double pct = e.value.meta > 0 ? (e.value.real / e.value.meta) * 100 : 0.0;
                  final bool esBueno = pct >= 100;
                  final Color barColor = esBueno ? const Color(0xFF10B981) : const Color(0xFFEF4444);
                  final double alturaVisual = (pct / 120 * 130).clamp(15.0, 130.0);

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${pct.toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: barColor),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 45,
                        height: alturaVisual,
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 65,
                        child: Text(
                          e.key,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black87),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 5️⃣ TABLA "POR TURNO" (Muestra T1, T2, T3...)
  Widget _buildTablaTurnos() {
    if (_statsTurno.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.pie_chart_outline_rounded, color: Color(0xFF1E3A8A)),
                SizedBox(width: 8),
                Text('Por Turno', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
              ],
            ),
            const SizedBox(height: 12),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1.8),
                1: FlexColumnWidth(1.2),
                2: FlexColumnWidth(1.2),
                3: FlexColumnWidth(1.2),
              },
              children: [
                const TableRow(
                  children: [
                    Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('TURNO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                    Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('REAL', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                    Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('META', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                    Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('PROD %', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                  ],
                ),
                ..._statsTurno.entries.map((e) {
                  final double pct = e.value.meta > 0 ? (e.value.real / e.value.meta) * 100 : 0.0;
                  final bool esBueno = pct >= 100;

                  return TableRow(
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E3A8A))),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text('${e.value.real}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text('${e.value.meta}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Align(
                          alignment: Alignment.center,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: esBueno ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${pct.toStringAsFixed(1)}%',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: esBueno ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 6️⃣ TABLA "TOP OPERARIOS" (Muestra T1, T2, T3 en la insignia oscura)
  Widget _buildTablaTopOperarios() {
    if (_topOperarios.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.emoji_events_rounded, color: Color(0xFFF59E0B)),
                SizedBox(width: 8),
                Text('Top Operarios', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                horizontalMargin: 0,
                headingRowHeight: 35,
                dataRowHeight: 45,
                columns: const [
                  DataColumn(label: Text('OPERARIO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                  DataColumn(label: Text('TURNO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                  DataColumn(label: Text('REAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                  DataColumn(label: Text('META', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                  DataColumn(label: Text('PROD %', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                ],
                rows: _topOperarios.map((op) {
                  final double pct = op.meta > 0 ? (op.real / op.meta) * 100 : 0.0;
                  final bool esBueno = pct >= 100;

                  return DataRow(
                    cells: [
                      DataCell(Text(op.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87))),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2937),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(op.turno, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      DataCell(Text('${op.real}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E3A8A)))),
                      DataCell(Text('${op.meta}', style: const TextStyle(color: Colors.grey, fontSize: 12))),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: esBueno ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${pct.toStringAsFixed(1)}%',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: esBueno ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}