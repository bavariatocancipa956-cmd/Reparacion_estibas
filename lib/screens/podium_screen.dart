import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';

class PodiumScreen extends StatefulWidget {
  final Map<String, dynamic> datosEmpleado;
  const PodiumScreen({super.key, required this.datosEmpleado});

  @override
  State<PodiumScreen> createState() => _PodiumScreenState();
}

class _PodiumScreenState extends State<PodiumScreen> {
  bool _isLoading = true;
  DateTime _mesSeleccionado = DateTime.now();

  List<Map<String, dynamic>> _ranking = [];
  Map<String, String> _fotosOperarios = {};

  int _umbralDias = 5;

  int _pInt(dynamic v) => (v as num?)?.toInt() ?? int.tryParse(v?.toString() ?? '') ?? 0;

  @override
  void initState() {
    super.initState();
    _cargarDatosPodio();
  }

  Future<void> _cargarDatosPodio() async {
    setState(() => _isLoading = true);
    try {
      final primerDiaStr = DateTime(_mesSeleccionado.year, _mesSeleccionado.month, 1).toString().substring(0, 10);
      final ultimoDiaStr = DateTime(_mesSeleccionado.year, _mesSeleccionado.month + 1, 0).toString().substring(0, 10);

      // 1. CONSULTA A LA API REST (TABLA: reparacion_estibas)
      final url = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/consultar/${ApiService.schema}/reparacion_estibas');

      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'x-api-key': ApiService.apiKey,
      });

      if (response.statusCode != 200) {
        throw Exception('Error del servidor: ${response.statusCode}');
      }

      final resData = jsonDecode(response.body);
      List<dynamic> todosLosRegistros = [];

      // 🛡️ REGLA INTELIGENTE DE LECTURA
      if (resData is List) {
        todosLosRegistros = resData;
      } else if (resData is Map<String, dynamic> && resData['data'] != null) {
        todosLosRegistros = resData['data'] is List ? resData['data'] : [];
      }

      // 2. FILTRAR Y AGRUPAR POR MES Y OPERARIO
      Map<String, Map<String, dynamic>> agrupado = {};

      for (var row in todosLosRegistros) {
        String fechaRaw = (row['fecha'] ?? row['fecha_registro'] ?? '').toString().trim();
        String fechaRow = fechaRaw.length >= 10 ? fechaRaw.substring(0, 10) : '';

        if (fechaRow.isEmpty || fechaRow.compareTo(primerDiaStr) < 0 || fechaRow.compareTo(ultimoDiaStr) > 0) {
          continue; // Fuera del mes seleccionado
        }

        String op = (row['operario'] ?? '').toString().trim();
        if (op.isEmpty) continue;

        int clasif = _pInt(row['clasificadas']);
        int rep = _pInt(row['reparadas']);
        String causal = (row['causal'] ?? '').toString().toLowerCase();

        // Ausentismos o registros en cero no suman día efectivo
        if ((clasif + rep) == 0 || causal.contains('ausentismo')) {
          continue;
        }

        if (!agrupado.containsKey(op)) {
          agrupado[op] = {'nombre': op, 'clasif': 0, 'rep': 0, 'diasLab': 0};
        }
        agrupado[op]!['clasif'] += clasif;
        agrupado[op]!['rep'] += rep;
        agrupado[op]!['diasLab'] += 1;
      }

      // 3. CALCULAR PRODUCTIVIDAD Y UMBRAL DE DÍAS
      List<Map<String, dynamic>> rankingTemp = [];
      List<String> nombresOperarios = [];
      int maxDiasLabDelMes = 0;

      for (var op in agrupado.values) {
        int total = op['clasif'] + op['rep'];
        int meta = op['diasLab'] * 100;
        double productividad = meta > 0 ? (total / meta) * 100 : 0.0;

        int dias = op['diasLab'];
        if (dias > maxDiasLabDelMes) maxDiasLabDelMes = dias;

        rankingTemp.add({
          'nombre': op['nombre'],
          'clasif': op['clasif'],
          'rep': op['rep'],
          'diasLab': dias,
          'productividad': productividad,
        });
        nombresOperarios.add(op['nombre']);
      }

      int umbralCalculado = (maxDiasLabDelMes * 0.6).floor();
      if (umbralCalculado < 5) umbralCalculado = 5;

      // 4. ORDENAR POR CUMPLIMIENTO DE DÍAS Y PRODUCTIVIDAD
      rankingTemp.sort((a, b) {
        bool aCumpleDias = a['diasLab'] >= umbralCalculado;
        bool bCumpleDias = b['diasLab'] >= umbralCalculado;

        if (aCumpleDias && !bCumpleDias) return -1;
        if (!aCumpleDias && bCumpleDias) return 1;

        return (b['productividad'] as double).compareTo(a['productividad'] as double);
      });

      // 5. INTENTAR BUSCAR FOTOS
      Map<String, String> fotosTemp = {};
      try {
        final urlFotos = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/consultar/public/people_personal');
        final resFotos = await http.get(urlFotos, headers: {
          'Content-Type': 'application/json',
          'x-api-key': ApiService.apiKey,
        });

        if (resFotos.statusCode == 200) {
          final resDataFotos = jsonDecode(resFotos.body);
          List<dynamic> fotosData = [];

          // 🛡️ REGLA INTELIGENTE DE LECTURA (Evita crash al cargar fotos)
          if (resDataFotos is List) {
            fotosData = resDataFotos;
          } else if (resDataFotos is Map<String, dynamic> && resDataFotos['data'] != null) {
            fotosData = resDataFotos['data'] is List ? resDataFotos['data'] : [];
          }

          for (var f in fotosData) {
            String nom = (f['Nombre'] ?? f['nombre'] ?? '').toString().trim();
            String foto = (f['Foto'] ?? f['foto'] ?? '').toString().trim();
            if (nom.isNotEmpty && foto.isNotEmpty) {
              fotosTemp[nom] = foto;
            }
          }
        }
      } catch (_) {
        // Silencioso si no está disponible la tabla de fotos
      }

      if (mounted) {
        setState(() {
          _ranking = rankingTemp;
          _fotosOperarios = fotosTemp;
          _umbralDias = umbralCalculado;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando podio: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _seleccionarMes() async {
    final DateTime? seleccionado = await showDatePicker(
      context: context,
      initialDate: _mesSeleccionado,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (seleccionado != null) {
      setState(() => _mesSeleccionado = seleccionado);
      _cargarDatosPodio();
    }
  }

  String _obtenerNombreMes(int mes, int anio) {
    const meses = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return '${meses[mes - 1]} $anio'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    String mesTexto = _obtenerNombreMes(_mesSeleccionado.month, _mesSeleccionado.year);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text('Podium del Mes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          // FILTRO DE MES
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('MES DE EVALUACIÓN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(mesTexto, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0D47A1))),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('Cambiar', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _seleccionarMes,
                ),
              ],
            ),
          ),

          // CONTENIDO DEL PODIO
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1)))
                : _ranking.isEmpty
                ? const Center(child: Text('No hay datos registrados para este mes.', style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)))
                : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 🏆 ZONA DEL PODIO 3D 🏆
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 30, bottom: 20, left: 10, right: 10),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.2)),
                        gradient: const RadialGradient(colors: [Color(0xFFF8FAFC), Colors.white], center: Alignment.topCenter, radius: 1.5),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))]
                    ),
                    child: Column(
                      children: [
                        const Text('🏆 MEJORES DEL MES 🏆', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E293B), letterSpacing: 1.2)),
                        const SizedBox(height: 50),

                        SizedBox(
                          height: 270,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // 🥈 SEGUNDO LUGAR
                              if (_ranking.length > 1)
                                _PilarPodio(operario: _ranking[1], posicion: 2, fotoUrl: _fotosOperarios[_ranking[1]['nombre']]),

                              // 🥇 PRIMER LUGAR
                              if (_ranking.isNotEmpty)
                                _PilarPodio(operario: _ranking[0], posicion: 1, fotoUrl: _fotosOperarios[_ranking[0]['nombre']]),

                              // 🥉 TERCER LUGAR
                              if (_ranking.length > 2)
                                _PilarPodio(operario: _ranking[2], posicion: 3, fotoUrl: _fotosOperarios[_ranking[2]['nombre']]),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // 📊 TABLA DE RANKING GENERAL
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ranking General', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 16),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.resolveWith((states) => const Color(0xFFF8F9FA)),
                            columnSpacing: 25,
                            columns: const [
                              DataColumn(label: Text('POS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                              DataColumn(label: Text('OPERARIO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                              DataColumn(label: Text('PRODUCTIVIDAD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                              DataColumn(label: Text('CLASIF.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                              DataColumn(label: Text('REP.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                              DataColumn(label: Text('DÍAS LAB.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                            ],
                            rows: _ranking.asMap().entries.map((entry) {
                              int pos = entry.key + 1;
                              var op = entry.value;
                              double prod = op['productividad'];
                              int diasLab = op['diasLab'];

                              String posStr = pos.toString();
                              if (pos == 1) posStr = '🥇';
                              if (pos == 2) posStr = '🥈';
                              if (pos == 3) posStr = '🥉';

                              Color colorBadge = prod >= 100 ? Colors.green : (prod >= 80 ? Colors.orange : Colors.red);
                              if (diasLab < _umbralDias) colorBadge = Colors.blueGrey;

                              return DataRow(
                                  color: WidgetStateProperty.resolveWith((states) => pos <= 3 ? Colors.blue.withValues(alpha: 0.03) : Colors.transparent),
                                  cells: [
                                    DataCell(Text(posStr, style: TextStyle(fontSize: pos <= 3 ? 18 : 14, fontWeight: FontWeight.bold))),
                                    DataCell(Text(op['nombre'].toString(), style: TextStyle(fontWeight: pos <= 3 ? FontWeight.bold : FontWeight.normal, color: const Color(0xFF263238)))),
                                    DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(color: colorBadge.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                                          child: Text('${prod.toStringAsFixed(1)}%', style: TextStyle(color: colorBadge, fontWeight: FontWeight.bold, fontSize: 11)),
                                        )
                                    ),
                                    DataCell(Text(op['clasif'].toString(), style: const TextStyle(color: Colors.grey))),
                                    DataCell(Text(op['rep'].toString(), style: const TextStyle(color: Colors.grey))),
                                    DataCell(
                                        Text(
                                            diasLab.toString(),
                                            style: TextStyle(
                                                color: diasLab < _umbralDias ? Colors.red : Colors.grey,
                                                fontWeight: diasLab < _umbralDias ? FontWeight.bold : FontWeight.normal
                                            )
                                        )
                                    ),
                                  ]
                              );
                            }).toList(),
                          ),
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

// ==========================================
// WIDGET DEL PILAR (3D METÁLICO)
// ==========================================
class _PilarPodio extends StatelessWidget {
  final Map<String, dynamic> operario;
  final int posicion;
  final String? fotoUrl;

  const _PilarPodio({required this.operario, required this.posicion, this.fotoUrl});

  @override
  Widget build(BuildContext context) {
    double alto;
    List<Color> gradientColors;
    Color colorScore;
    String medalla;

    if (posicion == 1) { // ORO
      alto = 220;
      medalla = '🥇';
      colorScore = const Color(0xFFB45309);
      gradientColors = const [Color(0xFFD4AF37), Color(0xFFFFDF73), Color(0xFFAA7700), Color(0xFFE6B800)];
    } else if (posicion == 2) { // PLATA
      alto = 175;
      medalla = '🥈';
      colorScore = const Color(0xFF334155);
      gradientColors = const [Color(0xFFA8B2BD), Color(0xFFE2E8F0), Color(0xFF718096), Color(0xFFCBD5E1)];
    } else { // BRONCE
      alto = 145;
      medalla = '🥉';
      colorScore = const Color(0xFF7C2D12);
      gradientColors = const [Color(0xFFCD7F32), Color(0xFFFFBDA1), Color(0xFF8C4A16), Color(0xFFD68752)];
    }

    List<String> nombres = operario['nombre'].toString().split(' ');
    String nombreCorto = nombres[0];
    if (nombres.length > 1) {
      nombreCorto += ' ${nombres[1]}';
    }

    return Container(
      width: 105,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            height: alto,
            width: double.infinity,
            padding: const EdgeInsets.only(top: 45, left: 4, right: 4),
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1),
                boxShadow: [
                  BoxShadow(color: gradientColors.last.withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 10))
                ]
            ),
            child: Column(
              children: [
                Text(nombreCorto, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, height: 1.1, shadows: [Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(0, 1))])),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(20)),
                  child: Text('${(operario['productividad'] as double).toStringAsFixed(1)}%', style: TextStyle(color: colorScore, fontWeight: FontWeight.w900, fontSize: 11)),
                ),
                const Spacer(),
                Text('${operario['clasif']} Clasif.\n${operario['rep']} Rep.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(0, 1))])),
                const SizedBox(height: 8),
              ],
            ),
          ),
          Positioned(
            top: -38,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: fotoUrl != null && fotoUrl!.isNotEmpty
                  ? ClipOval(
                child: Image.network(
                  fotoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: Colors.grey, size: 38),
                ),
              )
                  : const Icon(Icons.person, color: Colors.grey, size: 38),
            ),
          ),
          Positioned(
            top: 18,
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 5)],
              ),
              child: Text(medalla, style: const TextStyle(fontSize: 12)),
            ),
          )
        ],
      ),
    );
  }
}