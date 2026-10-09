import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

import '../services/api_service.dart';

class DashboardOperacionScreen extends StatefulWidget {
  final Map<String, dynamic> datosEmpleado;
  const DashboardOperacionScreen({super.key, required this.datosEmpleado});

  @override
  State<DashboardOperacionScreen> createState() => _DashboardOperacionScreenState();
}

class _DiaData {
  int total = 0;
  int records = 0;
}

class _DashboardOperacionScreenState extends State<DashboardOperacionScreen> {
  bool _isLoading = true;
  List<dynamic> _registros = [];

  DateTime? _fechaDesde;
  DateTime? _fechaHasta;

  int _totalClasificadas = 0;
  int _totalReparadas = 0;
  int _totalTipoC = 0;
  double _productividadGlobal = 0.0;
  double _maxYGraficoLinea = 150.0;

  List<FlSpot> _puntosLinea = [];
  Map<String, int> _causalesDistribucion = {};
  List<double> _productividadMensual = List.filled(12, 0.0);

  int _pInt(dynamic v) => (v as num?)?.toInt() ?? int.tryParse(v?.toString() ?? '') ?? 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fechaDesde = DateTime(now.year, now.month, 1);
    _fechaHasta = DateTime(now.year, now.month + 1, 0);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);

    final String nombreEmpleado = (widget.datosEmpleado['nombre'] ?? widget.datosEmpleado['usuario'] ?? widget.datosEmpleado['Nombre'] ?? '').toString().trim().toLowerCase();

    try {
      final url = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/consultar/${ApiService.schema}/reparacion_estibas');

      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'x-api-key': ApiService.apiKey,
      });

      if (response.statusCode != 200) {
        throw Exception('Error del servidor: ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      List<dynamic> todosLosRegistros = [];

      // 🛡️ REGLA INTELIGENTE DE LECTURA (Evita el choque fatal)
      if (decoded is List) {
        todosLosRegistros = decoded;
      } else if (decoded is Map<String, dynamic> && decoded['data'] != null) {
        todosLosRegistros = decoded['data'] is List ? decoded['data'] : [];
      }

      String? desdeStr = _fechaDesde?.toString().substring(0, 10);
      String? hastaStr = _fechaHasta?.toString().substring(0, 10);
      int anioActual = _fechaDesde?.year ?? DateTime.now().year;

      List<dynamic> dataFiltrada = [];
      List<dynamic> dataAnual = [];

      for (var row in todosLosRegistros) {
        String op = (row['operario'] ?? '').toString().trim().toLowerCase();

        // 🛡️ LECTURA SEGURA DE FECHAS
        String fRaw = (row['fecha'] ?? row['fecha_registro'] ?? '').toString().trim();
        String f = fRaw.length >= 10 ? fRaw.substring(0, 10) : '';

        if (f.isEmpty) continue; // Descarta registros con fecha nula/inválida

        bool coincideOperario = nombreEmpleado.isEmpty || op.contains(nombreEmpleado) || nombreEmpleado.contains(op);

        if (coincideOperario) {
          bool cumpleDesde = desdeStr == null || f.compareTo(desdeStr) >= 0;
          bool cumpleHasta = hastaStr == null || f.compareTo(hastaStr) <= 0;
          if (cumpleDesde && cumpleHasta) {
            dataFiltrada.add(row);
          }
          if (f.startsWith('$anioActual')) {
            dataAnual.add(row);
          }
        }
      }

      int tClasificadas = 0, tReparadas = 0, tTipoC = 0;
      Map<String, _DiaData> agrupadoPorDia = {};
      Map<String, int> conteoCausales = {};
      List<dynamic> registrosValidos = [];

      for (var row in dataFiltrada) {
        int clasif = _pInt(row['clasificadas']);
        int rep = _pInt(row['reparadas']);
        int tipoC = _pInt(row['tipo_c']);
        String causal = row['causal']?.toString() ?? 'Ninguna';
        String fecha = row['fecha']?.toString().substring(0, 10) ?? '';

        if ((clasif + rep) == 0 || causal.toLowerCase().contains('ausentismo')) {
          continue;
        }

        tClasificadas += clasif;
        tReparadas += rep;
        tTipoC += tipoC;

        var diaData = agrupadoPorDia.putIfAbsent(fecha, () => _DiaData());
        diaData.total += clasif + rep;
        diaData.records += 1;

        if (causal != 'Ninguna' && causal.isNotEmpty) {
          conteoCausales[causal] = (conteoCausales[causal] ?? 0) + 1;
        }

        registrosValidos.add(row);
      }

      int totalMeta = registrosValidos.length * 100;
      double prodGlobal = totalMeta > 0 ? ((tClasificadas + tReparadas) / totalMeta) * 100 : 0.0;

      List<FlSpot> puntos = [];
      double maxValorYEncontrado = 140.0;

      agrupadoPorDia.forEach((fecha, diaData) {
        double pctDia = (diaData.records * 100) > 0 ? (diaData.total / (diaData.records * 100)) * 100 : 0;
        double diaDelMes = double.tryParse(fecha.length >= 10 ? fecha.substring(8, 10) : '0') ?? 0;
        puntos.add(FlSpot(diaDelMes, pctDia));

        if (pctDia > maxValorYEncontrado) {
          maxValorYEncontrado = pctDia;
        }
      });
      puntos.sort((a, b) => a.x.compareTo(b.x));

      List<double> prodMeses = List.filled(12, 0.0);
      List<int> sumMeses = List.filled(12, 0);
      List<int> metaMeses = List.filled(12, 0);

      for (var row in dataAnual) {
        int clasif = _pInt(row['clasificadas']);
        int rep = _pInt(row['reparadas']);
        String causal = row['causal']?.toString() ?? '';

        if ((clasif + rep) == 0 || causal.toLowerCase().contains('ausentismo')) {
          continue;
        }

        String f = row['fecha']?.toString() ?? '';
        if (f.length >= 7) {
          int mes = int.tryParse(f.substring(5, 7)) ?? 1;
          sumMeses[mes - 1] += clasif + rep;
          metaMeses[mes - 1] += 100;
        }
      }

      for (int i = 0; i < 12; i++) {
        if (metaMeses[i] > 0) prodMeses[i] = (sumMeses[i] / metaMeses[i]) * 100;
      }

      if (mounted) {
        setState(() {
          _registros = registrosValidos.reversed.toList();
          _totalClasificadas = tClasificadas;
          _totalReparadas = tReparadas;
          _totalTipoC = tTipoC;
          _productividadGlobal = prodGlobal;
          _puntosLinea = puntos;
          _maxYGraficoLinea = math.max(150.0, maxValorYEncontrado + 35.0);
          _causalesDistribucion = conteoCausales;
          _productividadMensual = prodMeses;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error en Dashboard Operación: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _seleccionarFecha(BuildContext context, bool esDesde) async {
    final DateTime? seleccion = await showDatePicker(
      context: context,
      initialDate: (esDesde ? _fechaDesde : _fechaHasta) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (seleccion != null) {
      setState(() {
        if (esDesde) _fechaDesde = seleccion;
        else _fechaHasta = seleccion;
      });
    }
  }

  void _limpiarFiltros() {
    setState(() {
      _fechaDesde = null;
      _fechaHasta = null;
    });
    _cargarDatos();
  }

  Color _getColorProductividad(double pct) {
    if (pct >= 100) return const Color(0xFF2E7D32);
    return const Color(0xFFD32F2F);
  }

  @override
  Widget build(BuildContext context) {
    final String nombreOperario = (widget.datosEmpleado['nombre'] ?? widget.datosEmpleado['usuario'] ?? 'OPERARIO').toString().toUpperCase();

    // Configuración para que la línea de datos genere sus etiquetas visibles
    final lineChartBarData = LineChartBarData(
      spots: _puntosLinea,
      isCurved: true,
      curveSmoothness: 0.3,
      color: const Color(0xFF0D47A1),
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
          radius: 4,
          color: Colors.white,
          strokeWidth: 2.5,
          strokeColor: const Color(0xFF0D47A1),
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0D47A1).withOpacity(0.18),
            const Color(0xFF0D47A1).withOpacity(0.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Mi Productividad', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 2,
      ),
      body: Column(
        children: [
          // BARRA DE FILTROS SUPERIOR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Expanded(child: _buildFiltroFecha('Desde', _fechaDesde, () => _seleccionarFecha(context, true))),
                const SizedBox(width: 8),
                Expanded(child: _buildFiltroFecha('Hasta', _fechaHasta, () => _seleccionarFecha(context, false))),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    onPressed: _cargarDatos,
                    child: const Icon(Icons.filter_alt, size: 20),
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red[700],
                      side: BorderSide(color: Colors.red[300]!),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _limpiarFiltros,
                    child: const Icon(Icons.cleaning_services_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ),

          // CONTENIDO PRINCIPAL
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1)))
                : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_pin_rounded, color: Color(0xFF0D47A1), size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Operario: $nombreOperario',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 1. TARJETAS KPI
                  GridView.count(
                    crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.4,
                    children: [
                      _KpiCardModern(
                        titulo: 'CLASIFICADAS',
                        valor: _totalClasificadas.toString(),
                        icono: Icons.inventory_2_outlined,
                        colorBase: const Color(0xFF1976D2),
                      ),
                      _KpiCardModern(
                        titulo: 'REPARADAS',
                        valor: _totalReparadas.toString(),
                        icono: Icons.build_circle_outlined,
                        colorBase: const Color(0xFF2E7D32),
                      ),
                      _KpiCardModern(
                        titulo: 'TIPO C (MALA)',
                        valor: _totalTipoC.toString(),
                        icono: Icons.warning_amber_rounded,
                        colorBase: const Color(0xFFED6C02),
                      ),
                      _KpiCardModern(
                        titulo: 'PROD. GLOBAL',
                        valor: '${_productividadGlobal.toStringAsFixed(1)}%',
                        icono: Icons.speed_rounded,
                        colorBase: _getColorProductividad(_productividadGlobal),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 2. GRÁFICO DE LÍNEAS CON ETIQUETAS PERMANENTES
                  _ContenedorCard(
                    titulo: 'Mi Productividad por Día',
                    icono: Icons.show_chart_rounded,
                    child: SizedBox(
                      height: 280,
                      child: _puntosLinea.isEmpty
                          ? const Center(child: Text('Sin datos registrados en el rango', style: TextStyle(color: Colors.grey)))
                          : LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 30,
                            getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey[200]!, strokeWidth: 1),
                          ),
                          titlesData: FlTitlesData(
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 1,
                                getTitlesWidget: (val, meta) => Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    val.toInt().toString().padLeft(2, '0'),
                                    style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 30,
                                reservedSize: 32,
                                getTitlesWidget: (val, meta) => Text(
                                  val.toInt().toString(),
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          minY: 0,
                          maxY: _maxYGraficoLinea,
                          lineBarsData: [lineChartBarData],
                          // 🏷️ ETIQUETAS FLOTANTES FIJAS EN CADA PUNTO DE LA LÍNEA
                          showingTooltipIndicators: _puntosLinea.asMap().entries.map((entry) {
                            return ShowingTooltipIndicators([
                              LineBarSpot(lineChartBarData, 0, entry.value),
                            ]);
                          }).toList(),
                          lineTouchData: LineTouchData(
                            enabled: false,
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipColor: (spot) => Colors.transparent,
                              tooltipPadding: EdgeInsets.zero,
                              tooltipMargin: 6,
                              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                                return touchedSpots.map((spot) {
                                  return LineTooltipItem(
                                    '${spot.y.toStringAsFixed(1)}%',
                                    TextStyle(
                                      color: _getColorProductividad(spot.y),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  );
                                }).toList();
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. GRÁFICO DE BARRAS CON ETIQUETAS PERMANENTES + DONA
                  LayoutBuilder(
                    builder: (context, constraints) {
                      bool esAncho = constraints.maxWidth > 750;
                      List<Widget> graficos = [
                        Expanded(
                          flex: esAncho ? 1 : 0,
                          child: _ContenedorCard(
                            titulo: 'Mi Productividad Mensual',
                            icono: Icons.bar_chart_rounded,
                            child: SizedBox(
                              height: 250,
                              child: BarChart(
                                BarChartData(
                                  alignment: BarChartAlignment.spaceAround,
                                  maxY: 135,
                                  // 🏷️ ETIQUETAS FLOTANTES FIJAS EN CADA BARRA
                                  barTouchData: BarTouchData(
                                    enabled: false,
                                    touchTooltipData: BarTouchTooltipData(
                                      getTooltipColor: (group) => Colors.transparent,
                                      tooltipPadding: EdgeInsets.zero,
                                      tooltipMargin: 4,
                                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                        return BarTooltipItem(
                                          '${rod.toY.toStringAsFixed(1)}%',
                                          TextStyle(
                                            color: _getColorProductividad(rod.toY),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  titlesData: FlTitlesData(
                                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 30, reservedSize: 30, getTitlesWidget: (val, meta) => Text(val.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.grey)))),
                                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: _getMesTitleWidget)),
                                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  ),
                                  gridData: const FlGridData(show: false),
                                  borderData: FlBorderData(show: false),
                                  barGroups: List.generate(12, (i) {
                                    return BarChartGroupData(
                                      x: i,
                                      showingTooltipIndicators: _productividadMensual[i] > 0 ? [0] : [],
                                      barRods: [
                                        BarChartRodData(
                                          toY: _productividadMensual[i],
                                          color: _getColorProductividad(_productividadMensual[i]),
                                          width: 14,
                                          borderRadius: BorderRadius.circular(4),
                                        )
                                      ],
                                    );
                                  }),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (esAncho) const SizedBox(width: 16) else const SizedBox(height: 16),
                        Expanded(
                          flex: esAncho ? 1 : 0,
                          child: _ContenedorCard(
                            titulo: 'Causales de Baja Prod.',
                            icono: Icons.pie_chart_outline_rounded,
                            child: SizedBox(
                              height: 250,
                              child: _causalesDistribucion.isEmpty
                                  ? const Center(child: Text('Sin causales registradas', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)))
                                  : Row(
                                children: [
                                  Expanded(
                                    child: PieChart(
                                      PieChartData(
                                        sectionsSpace: 2,
                                        centerSpaceRadius: 38,
                                        sections: _generarSeccionesDona(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: _generarLeyendaDona(),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                      ];

                      return esAncho ? Row(children: graficos) : Column(children: graficos);
                    },
                  ),
                  const SizedBox(height: 20),

                  // 4. TABLA DETALLE DE PRODUCTIVIDAD
                  _ContenedorCard(
                    titulo: 'Mi Detalle de Productividad',
                    icono: Icons.table_chart_outlined,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey[200]!), borderRadius: BorderRadius.circular(8)),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.resolveWith((states) => const Color(0xFFF1F5F9)),
                          horizontalMargin: 16,
                          columnSpacing: 28,
                          columns: const [
                            DataColumn(label: Text('FECHA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                            DataColumn(label: Text('CLASIF.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                            DataColumn(label: Text('REP.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                            DataColumn(label: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                            DataColumn(label: Text('META', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                            DataColumn(label: Text('% PROD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                          ],
                          rows: _registros.map((item) {
                            int cl = _pInt(item['clasificadas']);
                            int rp = _pInt(item['reparadas']);
                            int tot = cl + rp;
                            double pct = tot.toDouble();
                            Color colorAct = _getColorProductividad(pct);

                            return DataRow(cells: [
                              DataCell(Text(item['fecha'].toString().substring(0, 10), style: const TextStyle(fontSize: 12))),
                              DataCell(Text(cl.toString(), style: const TextStyle(fontSize: 12))),
                              DataCell(Text(rp.toString(), style: const TextStyle(fontSize: 12))),
                              DataCell(Text(tot.toString(), style: const TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold, fontSize: 12))),
                              DataCell(const Text('100', style: TextStyle(color: Colors.grey, fontSize: 12))),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: colorAct.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                                  child: Text('${pct.toStringAsFixed(1)}%', style: TextStyle(color: colorAct, fontWeight: FontWeight.bold, fontSize: 11)),
                                ),
                              ),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroFecha(String label, DateTime? valor, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 4),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFFF8FAFC),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  valor != null ? "${valor.day.toString().padLeft(2, '0')}/${valor.month.toString().padLeft(2, '0')}/${valor.year}" : 'Elegir',
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
                const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF0D47A1)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<PieChartSectionData> _generarSeccionesDona() {
    List<Color> paletaColores = [const Color(0xFF1976D2), const Color(0xFFD32F2F), const Color(0xFFED6C02), const Color(0xFF2E7D32), const Color(0xFF9C27B0)];
    int total = _causalesDistribucion.values.fold(0, (sum, item) => sum + item);
    int idx = 0;

    return _causalesDistribucion.entries.map((e) {
      Color c = paletaColores[idx % paletaColores.length];
      idx++;
      double porcentaje = total > 0 ? (e.value / total) * 100 : 0;

      return PieChartSectionData(
        color: c,
        value: e.value.toDouble(),
        title: '${porcentaje.toStringAsFixed(0)}%',
        radius: 32,
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }

  List<Widget> _generarLeyendaDona() {
    List<Color> paletaColores = [const Color(0xFF1976D2), const Color(0xFFD32F2F), const Color(0xFFED6C02), const Color(0xFF2E7D32), const Color(0xFF9C27B0)];
    int idx = 0;
    return _causalesDistribucion.keys.map((causal) {
      Color c = paletaColores[idx % paletaColores.length];
      idx++;
      return Padding(
        padding: const EdgeInsets.only(bottom: 6.0),
        child: Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 6),
            SizedBox(
              width: 120,
              child: Text(causal, style: const TextStyle(fontSize: 11, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
            )
          ],
        ),
      );
    }).toList();
  }

  Widget _getMesTitleWidget(double value, TitleMeta meta) {
    const meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    int idx = value.toInt();
    if (idx < 0 || idx > 11) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6.0),
      child: Text(meses[idx], style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
    );
  }
}

class _KpiCardModern extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icono;
  final Color colorBase;

  const _KpiCardModern({
    required this.titulo,
    required this.valor,
    required this.icono,
    required this.colorBase,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorBase.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: colorBase.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 0.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: colorBase.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(icono, size: 16, color: colorBase),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              valor,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: colorBase),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContenedorCard extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final Widget child;

  const _ContenedorCard({
    required this.titulo,
    required this.icono,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 18, color: const Color(0xFF0D47A1)),
              const SizedBox(width: 8),
              Text(
                titulo,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}