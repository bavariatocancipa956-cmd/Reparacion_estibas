import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';

class Dashboard5SScreen extends StatefulWidget {
  final Map<String, dynamic> datosEmpleado;

  const Dashboard5SScreen({super.key, required this.datosEmpleado});

  @override
  State<Dashboard5SScreen> createState() => _Dashboard5SScreenState();
}

class _Dashboard5SScreenState extends State<Dashboard5SScreen> {
  bool _isLoading = true;

  List<Map<String, dynamic>> _rawData = [];

  // Estado de Filtros Activos
  String _filtroAno = 'Todos';
  String _filtroMes = 'Todos';
  String _filtroDia = 'Todos';
  String _filtroSemana = 'Todas';
  String _filtroArea = 'Todas';

  // Listas de Opciones de Filtros (Dinámicas en Cascada)
  List<String> _opcionesAno = ['Todos'];
  List<String> _opcionesMes = ['Todos'];
  List<String> _opcionesDia = ['Todos'];
  List<String> _opcionesSemana = ['Todas'];
  List<String> _opcionesArea = ['Todas'];

  // Variables de Resultados y Métricas
  double _promedioGeneral = 0.0;
  Map<String, double> _evolucionSemanal = {};
  Map<String, double> _rendimientoTerritorio = {};
  Map<String, int> _topHallazgos = {};
  List<Map<String, dynamic>> _historicoReciente = [];

  final List<String> _mesesNombres = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  // 📋 COLUMNAS EXACTAS DE LA TABLA gestion.5s_ol
  final List<String> _columnasEvaluacion = [
    'tablero_actualizado',
    'areas_libres_obstaculos',
    'sin_equipos_danados',
    'items_delimitados_bloqueados',
    'lugar_elementos_personales',
    'sitios_importantes_delimitados',
    'contenedores_residuos_estandar',
    'cumple_estandar_layout',
    'cumple_estandar_limpieza',
    'layout_duenos_claros',
    'equipos_rotos_danados',
    'dueno_area_divulgado'
  ];

  final Map<String, String> _nombresPreguntas = {
    'tablero_actualizado': '¿Tablero de territorio actualizado?',
    'areas_libres_obstaculos': '¿Áreas libres de elementos innecesarios?',
    'sin_equipos_danados': '¿Herramientas y EPP sin daños?',
    'items_delimitados_bloqueados': '¿Ítems innecesarios delimitados?',
    'lugar_elementos_personales': '¿Lugar definido para elementos personales?',
    'sitios_importantes_delimitados': '¿Pasos cebra y sitios delimitados?',
    'contenedores_residuos_estandar': '¿Cajas y contenedores de desechos estándar?',
    'cumple_estandar_layout': '¿Se cumple el estándar de Layout?',
    'cumple_estandar_limpieza': '¿Se cumple el orden y limpieza del sector?',
    'layout_duenos_claros': '¿Layout con dueños claros por área?',
    'equipos_rotos_danados': '¿Sin equipos o muebles rotos / dañados?',
    'dueno_area_divulgado': '¿Dueño de área definido y divulgado?',
  };

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  int _obtenerNumeroSemana(DateTime date) {
    int dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays + 1;
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/consultar/gestion/5s_ol');
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'x-api-key': ApiService.apiKey,
      });

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> data = [];

        // 🛡️ REGLA INTELIGENTE DE LECTURA (Evita el choque fatal)
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map<String, dynamic> && decoded['data'] != null) {
          data = decoded['data'] is List ? decoded['data'] : [];
        }

        _rawData = List<Map<String, dynamic>>.from(data);
      } else {
        _rawData = [];
      }

      _actualizarFiltrosYCalcular();
    } catch (e) {
      debugPrint('Error cargando datos en Dashboard 5S: $e');
      setState(() => _isLoading = false);
    }
  }

  // ✨ FILTROS EN CASCADA INTELIGENTES
  void _actualizarFiltrosYCalcular() {
    Set<String> anos = {'Todos'};
    Set<String> areas = {'Todas'};
    Set<String> meses = {'Todos'};
    Set<String> dias = {'Todos'};
    Set<String> semanas = {'Todas'};

    for (var row in _rawData) {
      String fechaStr = (row['fecha_creacion'] ?? row['fecha'] ?? '').toString();
      if (fechaStr.isNotEmpty) {
        try {
          DateTime f = DateTime.parse(fechaStr);
          anos.add(f.year.toString());
        } catch (_) {}
      }
      String areaVal = (row['area'] ?? row['areas'] ?? '').toString().toUpperCase().trim();
      if (areaVal.isNotEmpty) areas.add(areaVal);
    }

    _opcionesAno = anos.toList()..sort();
    _opcionesArea = areas.toList()..sort();

    if (!_opcionesAno.contains(_filtroAno)) _filtroAno = 'Todos';
    if (!_opcionesArea.contains(_filtroArea)) _filtroArea = 'Todas';

    for (var row in _rawData) {
      String fechaStr = (row['fecha_creacion'] ?? row['fecha'] ?? '').toString();
      if (fechaStr.isEmpty) continue;
      try {
        DateTime f = DateTime.parse(fechaStr);
        String anoF = f.year.toString();

        if (_filtroAno != 'Todos' && anoF != _filtroAno) continue;
        meses.add(_mesesNombres[f.month - 1]);
      } catch (_) {}
    }

    List<String> mesesSorted = meses.toList()..remove('Todos');
    mesesSorted.sort((a, b) => _mesesNombres.indexOf(a).compareTo(_mesesNombres.indexOf(b)));
    _opcionesMes = ['Todos', ...mesesSorted];

    if (!_opcionesMes.contains(_filtroMes)) _filtroMes = 'Todos';

    for (var row in _rawData) {
      String fechaStr = (row['fecha_creacion'] ?? row['fecha'] ?? '').toString();
      if (fechaStr.isEmpty) continue;
      try {
        DateTime f = DateTime.parse(fechaStr);
        String anoF = f.year.toString();
        String mesNombreF = _mesesNombres[f.month - 1];

        if (_filtroAno != 'Todos' && anoF != _filtroAno) continue;
        if (_filtroMes != 'Todos' && mesNombreF != _filtroMes) continue;

        dias.add(f.day.toString().padLeft(2, '0'));
        semanas.add('Sem ${_obtenerNumeroSemana(f)}');
      } catch (_) {}
    }

    _opcionesDia = dias.toList()..sort();

    List<String> semanasSorted = semanas.toList()..remove('Todas');
    semanasSorted.sort((a, b) {
      try {
        int numA = int.parse(a.replaceAll(RegExp(r'[^0-9]'), ''));
        int numB = int.parse(b.replaceAll(RegExp(r'[^0-9]'), ''));
        return numA.compareTo(numB);
      } catch (_) {
        return a.compareTo(b);
      }
    });
    _opcionesSemana = ['Todas', ...semanasSorted];

    if (!_opcionesDia.contains(_filtroDia)) _filtroDia = 'Todos';
    if (!_opcionesSemana.contains(_filtroSemana)) _filtroSemana = 'Todas';

    _ejecutarCalculosMetricas();
  }

  void _ejecutarCalculosMetricas() {
    double sumaTotalPuntos = 0;
    int totalRespuestas = 0;

    Map<String, List<double>> calcEvolucion = {};
    Map<String, List<double>> calcTerritorio = {};
    Map<String, int> conteoHallazgos = {};
    List<Map<String, dynamic>> historicoTemp = [];

    for (var row in _rawData) {
      DateTime? f;
      String anoF = '';
      String mesNombreF = '';
      String diaF = '';
      String semF = '';

      String fechaStr = (row['fecha_creacion'] ?? row['fecha'] ?? '').toString();
      if (fechaStr.isNotEmpty) {
        try {
          f = DateTime.parse(fechaStr);
          anoF = f.year.toString();
          mesNombreF = _mesesNombres[f.month - 1];
          diaF = f.day.toString().padLeft(2, '0');
          semF = 'Sem ${_obtenerNumeroSemana(f)}';
        } catch (_) {}
      }

      String areaR = (row['area'] ?? row['areas'] ?? 'OTROS').toString().toUpperCase().trim();

      if (_filtroAno != 'Todos' && anoF != _filtroAno) continue;
      if (_filtroMes != 'Todos' && mesNombreF != _filtroMes) continue;
      if (_filtroDia != 'Todos' && diaF != _filtroDia) continue;
      if (_filtroSemana != 'Todas' && semF != _filtroSemana) continue;
      if (_filtroArea != 'Todas' && areaR != _filtroArea) continue;

      int buenosDeEstaAuditoria = 0;
      int evaluadosDeEstaAuditoria = 0;

      for (var c in _columnasEvaluacion) {
        final respondido = row[c]?.toString().toUpperCase().trim();
        if (respondido == 'BUENO' || respondido == 'MALO') {
          evaluadosDeEstaAuditoria++;
          if (respondido == 'BUENO') {
            buenosDeEstaAuditoria++;
            sumaTotalPuntos++;
          } else if (respondido == 'MALO') {
            conteoHallazgos[c] = (conteoHallazgos[c] ?? 0) + 1;
          }
          totalRespuestas++;
        }
      }

      if (evaluadosDeEstaAuditoria > 0) {
        double prodAuditoria = (buenosDeEstaAuditoria / evaluadosDeEstaAuditoria) * 100;

        historicoTemp.add({
          'area': areaR,
          'semana': semF,
          'auditor': (row['nombre'] ?? '').toString().toUpperCase().trim(),
          'score': prodAuditoria
        });

        if (!calcTerritorio.containsKey(areaR)) calcTerritorio[areaR] = [0, 0];
        calcTerritorio[areaR]![0] += buenosDeEstaAuditoria;
        calcTerritorio[areaR]![1] += evaluadosDeEstaAuditoria;

        if (semF.isNotEmpty) {
          if (!calcEvolucion.containsKey(semF)) calcEvolucion[semF] = [0, 0];
          calcEvolucion[semF]![0] += buenosDeEstaAuditoria;
          calcEvolucion[semF]![1] += evaluadosDeEstaAuditoria;
        }
      }
    }

    _promedioGeneral = totalRespuestas > 0 ? (sumaTotalPuntos / totalRespuestas) * 100 : 0.0;

    _evolucionSemanal.clear();
    calcEvolucion.forEach((k, v) => _evolucionSemanal[k] = (v[0] / v[1]) * 100);

    _rendimientoTerritorio.clear();
    calcTerritorio.forEach((k, v) => _rendimientoTerritorio[k] = (v[0] / v[1]) * 100);
    _rendimientoTerritorio = Map.fromEntries(_rendimientoTerritorio.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));

    _topHallazgos = Map.fromEntries(conteoHallazgos.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
    _historicoReciente = historicoTemp.toList();

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Panel de Control 5S', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIndicadorGeneral(),
            const SizedBox(height: 16),
            _buildFiltros(),
            const SizedBox(height: 16),
            _buildEvolucionSemanal(),
            const SizedBox(height: 16),
            _buildRendimientoTerritorio(),
            const SizedBox(height: 16),
            _buildTopHallazgos(),
            const SizedBox(height: 16),
            _buildHistoricoReciente(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildCardBase({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.03), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: child,
    );
  }

  Widget _buildBadge(double score) {
    bool cumpleMeta = score >= 90.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cumpleMeta ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${score.toStringAsFixed(0)}%',
        style: TextStyle(color: cumpleMeta ? Colors.green.shade800 : Colors.red.shade800, fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }

  Widget _buildIndicadorGeneral() {
    bool cumpleMeta = _promedioGeneral >= 90.0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cumpleMeta ? const Color(0xFFEAF5EB) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cumpleMeta ? Colors.green.shade400 : Colors.red.shade400, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('INDICADOR GENERAL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.black54)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text('META 90%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: cumpleMeta ? Colors.green.shade800 : Colors.red.shade800)),
                  const SizedBox(width: 4),
                  Icon(cumpleMeta ? Icons.check_circle : Icons.cancel_rounded, size: 14, color: cumpleMeta ? Colors.green.shade800 : Colors.red.shade800),
                ],
              )
            ],
          ),
          Text(
            '${_promedioGeneral.toStringAsFixed(1)}%',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 34, color: cumpleMeta ? Colors.green.shade900 : Colors.red.shade900, letterSpacing: -1),
          )
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return _buildCardBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, color: Color(0xFF0D47A1), size: 18),
              SizedBox(width: 8),
              Text('Filtros Dinámicos de Auditoría', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildDropdown('Año', _filtroAno, _opcionesAno, (v) => setState(() { _filtroAno = v!; _actualizarFiltrosYCalcular(); }))),
              const SizedBox(width: 8),
              Expanded(child: _buildDropdown('Mes', _filtroMes, _opcionesMes, (v) => setState(() { _filtroMes = v!; _actualizarFiltrosYCalcular(); }))),
              const SizedBox(width: 8),
              Expanded(child: _buildDropdown('Día', _filtroDia, _opcionesDia, (v) => setState(() { _filtroDia = v!; _ejecutarCalculosMetricas(); }))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildDropdown('Semana', _filtroSemana, _opcionesSemana, (v) => setState(() { _filtroSemana = v!; _ejecutarCalculosMetricas(); }))),
              const SizedBox(width: 12),
              Expanded(child: _buildDropdown('Área / Zona', _filtroArea, _opcionesArea, (v) => setState(() { _filtroArea = v!; _ejecutarCalculosMetricas(); }))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    if (!items.contains(value)) value = items.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black45)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: const Color(0xFFF4F6F8), borderRadius: BorderRadius.circular(8)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.black54),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEvolucionSemanal() {
    return _buildCardBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('EVOLUCIÓN SEMANAL DEL PERÍODO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
          const SizedBox(height: 24),
          SizedBox(
            height: 120,
            child: _evolucionSemanal.isEmpty
                ? const Center(child: Text('Sin datos registrados', style: TextStyle(fontSize: 12, color: Colors.grey)))
                : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _evolucionSemanal.entries.map((e) {
                  double h = (e.value / 100) * 80;
                  bool cumpleMeta = e.value >= 90.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${e.value.toStringAsFixed(0)}%', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: cumpleMeta ? Colors.green.shade800 : Colors.red.shade800)),
                        const SizedBox(height: 4),
                        Container(
                            width: 25,
                            height: h > 0 ? h : 4,
                            decoration: BoxDecoration(
                                color: cumpleMeta ? Colors.green.shade800 : Colors.red.shade800,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4))
                            )
                        ),
                        const SizedBox(height: 6),
                        Text(e.key, style: const TextStyle(fontSize: 9, color: Colors.black54)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRendimientoTerritorio() {
    return _buildCardBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('RENDIMIENTO COMPARATIVO POR TERRITORIO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('TERRITORIO / LUGAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)),
                Text('RESULTADO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)),
              ],
            ),
          ),
          ..._rendimientoTerritorio.entries.map((e) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(e.key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black87))),
                  _buildBadge(e.value),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTopHallazgos() {
    var todosLosHallazgos = _topHallazgos.entries.toList();
    return _buildCardBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TOP HALLAZGOS DETECTADOS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: Scrollbar(
              thumbVisibility: true,
              trackVisibility: true,
              child: SingleChildScrollView(
                primary: true,
                padding: const EdgeInsets.only(right: 14),
                child: Column(
                  children: todosLosHallazgos.isEmpty
                      ? [
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Text('Sin hallazgos detectados', style: TextStyle(fontSize: 12, color: Colors.black45, fontWeight: FontWeight.bold)),
                      ),
                    )
                  ]
                      : todosLosHallazgos.map((e) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(child: Text(_nombresPreguntas[e.key] ?? e.key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(12)),
                            child: Text(e.value.toString(), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 11)),
                          )
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHistoricoReciente() {
    return _buildCardBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('HISTÓRICO RECIENTE DE AUDITORÍAS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
          const SizedBox(height: 12),
          SizedBox(
            height: 380,
            child: Scrollbar(
              thumbVisibility: true,
              trackVisibility: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(right: 14),
                child: Column(
                  children: _historicoReciente.isEmpty
                      ? [
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Text('Sin auditorías registradas', style: TextStyle(fontSize: 12, color: Colors.black45, fontWeight: FontWeight.bold)),
                      ),
                    )
                  ]
                      : _historicoReciente.map((e) {
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e['area'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                                const SizedBox(height: 4),
                                Text('${e['semana']} • Auditor: ${e['auditor']}', style: const TextStyle(fontSize: 9, color: Colors.black54, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          _buildBadge(e['score']),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}