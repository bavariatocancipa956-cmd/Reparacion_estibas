import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';

class Dashboard5SBavariaScreen extends StatefulWidget {
  final Map<String, dynamic> datosEmpleado;

  const Dashboard5SBavariaScreen({super.key, required this.datosEmpleado});

  @override
  State<Dashboard5SBavariaScreen> createState() => _Dashboard5SBavariaScreenState();
}

class _Dashboard5SBavariaScreenState extends State<Dashboard5SBavariaScreen> {
  bool _isLoading = true;

  // Repositorio de datos desde la API
  List<Map<String, dynamic>> _allAuditorias = [];
  List<Map<String, dynamic>> _allAreasResponsables = [];

  // Listas y mapas calculados dinámicamente según filtros
  List<Map<String, dynamic>> _auditoriasFiltradas = [];
  List<MapEntry<String, double>> _semanasData = [];
  List<MapEntry<String, double>> _areasData = [];
  List<MapEntry<String, int>> _oportunidadesData = [];
  List<MapEntry<String, int>> _hallazgosData = [];
  Map<String, dynamic>? _duenoActual;

  // Variables de control de selectores
  String _selectedAnio = DateTime.now().year.toString();
  String _selectedSemana = 'Todas';
  String _selectedMes = 'Todas';
  String _selectedArea = 'Todas';

  List<String> _anios = ['Todos'];
  List<String> _semanas = ['Todas'];
  final List<String> _meses = [
    'Todas', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
  ];
  List<String> _areas = ['Todas'];

  final double _metaCumplimiento = 90.0;
  double _promedioGeneral = 0.0;

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  // 📌 MÉTODOS DE EXTRACCIÓN CON PRIORIDAD EN COLUMNAS CLAVE
  String _obtenerFecha(Map<String, dynamic> row) {
    return (row['fecha_auditoria'] ?? row['datetime_performed'] ?? row['expected_date'] ?? '').toString().trim();
  }

  String _obtenerZona(Map<String, dynamic> row) {
    String val = (row['zona_auditoria'] ?? row['seccion_territorio'] ?? row['location'] ?? '').toString().trim();
    return val.isEmpty ? 'Zona General' : val;
  }

  Future<void> _cargarDatosIniciales() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // 1. Cargar Auditorías 5S Bavaria
      final urlAuditorias = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/consultar/gestion/5S_bavaria');
      final resAuditorias = await http.get(urlAuditorias, headers: {'Content-Type': 'application/json', 'x-api-key': ApiService.apiKey});

      if (resAuditorias.statusCode == 200) {
        final decoded = jsonDecode(resAuditorias.body);
        List<dynamic> data = [];

        // 🛡️ REGLA INTELIGENTE DE LECTURA (Auditorías)
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map<String, dynamic> && decoded['data'] != null) {
          data = decoded['data'] is List ? decoded['data'] : [];
        }

        _allAuditorias = List<Map<String, dynamic>>.from(data);
      }

      // 2. Cargar Dueños 5S
      final tablaDuenos = Uri.encodeComponent('Dueños 5S');
      final urlDuenos = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/consultar/gestion/$tablaDuenos');
      final resDuenos = await http.get(urlDuenos, headers: {'Content-Type': 'application/json', 'x-api-key': ApiService.apiKey});

      if (resDuenos.statusCode == 200) {
        final decoded = jsonDecode(resDuenos.body);
        List<dynamic> data = [];

        // 🛡️ REGLA INTELIGENTE DE LECTURA (Dueños)
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map<String, dynamic> && decoded['data'] != null) {
          data = decoded['data'] is List ? decoded['data'] : [];
        }

        _allAreasResponsables = List<Map<String, dynamic>>.from(data);
      }

      _inicializarListasFiltros();
      _actualizarSemanasDisponibles();
      _aplicarFiltrosYCalculos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al conectar con la base de datos: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Cálculo de semana ISO-8601
  int _getWeekNumber(DateTime date) {
    DateTime thursday = date.add(Duration(days: 4 - date.weekday));
    DateTime firstThursday = DateTime(thursday.year, 1, 4);
    firstThursday = firstThursday.add(Duration(days: 4 - firstThursday.weekday));
    return 1 + thursday.difference(firstThursday).inDays ~/ 7;
  }

  void _inicializarListasFiltros() {
    final setAreas = <String>{'Todas'};
    final setAnios = <String>{DateTime.now().year.toString()};

    for (var aud in _allAuditorias) {
      String loc = _obtenerZona(aud);
      String fechaStr = _obtenerFecha(aud);

      if (loc.isNotEmpty && loc != 'Zona General') setAreas.add(loc);
      if (fechaStr.length >= 4) {
        setAnios.add(fechaStr.substring(0, 4));
      }
    }

    _areas = setAreas.toList()..sort();
    _anios = setAnios.toList()..sort((a, b) => b.compareTo(a));
    if (!_anios.contains(_selectedAnio)) _selectedAnio = _anios.first;
  }

  void _actualizarSemanasDisponibles() {
    final setSemanas = <String>{'Todas'};

    for (var aud in _allAuditorias) {
      String fechaStr = _obtenerFecha(aud);
      if (fechaStr.isEmpty || !fechaStr.contains(_selectedAnio)) continue;

      try {
        DateTime f = DateTime.parse(fechaStr);
        if (_selectedMes != 'Todas' && _meses[f.month] != _selectedMes) continue;

        setSemanas.add(_getWeekNumber(f).toString());
      } catch (_) {}
    }

    _semanas = setSemanas.toList()..sort((a, b) {
      if (a == 'Todas') return -1;
      if (b == 'Todas') return 1;
      return int.parse(a).compareTo(int.parse(b));
    });

    if (!_semanas.contains(_selectedSemana)) {
      _selectedSemana = 'Todas';
    }
  }

  void _aplicarFiltrosYCalculos() {
    if (!mounted) return;
    setState(() {
      _auditoriasFiltradas = _allAuditorias.where((aud) {
        String fechaStr = _obtenerFecha(aud);
        if (fechaStr.isEmpty || !fechaStr.contains(_selectedAnio)) return false;

        if (_selectedArea != 'Todas') {
          String loc = _obtenerZona(aud).toLowerCase();
          String target = _selectedArea.toLowerCase();
          if (!loc.contains(target)) return false;
        }

        if (_selectedMes != 'Todas') {
          try {
            DateTime f = DateTime.parse(fechaStr);
            if (_meses[f.month] != _selectedMes) return false;
          } catch (_) { return false; }
        }

        if (_selectedSemana != 'Todas') {
          try {
            DateTime f = DateTime.parse(fechaStr);
            if (_getWeekNumber(f).toString() != _selectedSemana) return false;
          } catch (_) { return false; }
        }
        return true;
      }).toList();

      if (_auditoriasFiltradas.isNotEmpty) {
        double suma = 0.0;
        for (var aud in _auditoriasFiltradas) {
          suma += double.tryParse(aud['compliance_percentage']?.toString() ?? '0') ?? 0.0;
        }
        _promedioGeneral = suma / _auditoriasFiltradas.length;
      } else {
        _promedioGeneral = 0.0;
      }

      Map<String, List<double>> pSemanas = {};
      int mesActualSistema = DateTime.now().month;

      for (var aud in _allAuditorias) {
        String fechaStr = _obtenerFecha(aud);
        if (fechaStr.isEmpty || !fechaStr.contains(_selectedAnio)) continue;
        DateTime f;
        try { f = DateTime.parse(fechaStr); } catch (_) { continue; }

        if (_selectedMes == 'Todas') {
          if (f.month != mesActualSistema) continue;
        } else {
          if (_meses[f.month] != _selectedMes) continue;
        }

        if (_selectedArea != 'Todas') {
          String loc = _obtenerZona(aud).toLowerCase();
          if (!loc.contains(_selectedArea.toLowerCase())) continue;
        }

        String wKey = 'Sem ${_getWeekNumber(f)}';
        double pct = double.tryParse(aud['compliance_percentage']?.toString() ?? '0') ?? 0.0;
        pSemanas.putIfAbsent(wKey, () => []).add(pct);
      }
      _semanasData = pSemanas.entries.map((e) => MapEntry(e.key, e.value.reduce((a, b) => a + b) / e.value.length)).toList()..sort((a, b) => a.key.compareTo(b.key));

      Map<String, List<double>> pAreas = {};
      for (var aud in _allAuditorias) {
        String fechaStr = _obtenerFecha(aud);
        if (fechaStr.isEmpty || !fechaStr.contains(_selectedAnio)) continue;

        DateTime f;
        try { f = DateTime.parse(fechaStr); } catch (_) { continue; }

        if (_selectedMes != 'Todas' && _meses[f.month] != _selectedMes) continue;
        if (_selectedSemana != 'Todas' && _getWeekNumber(f).toString() != _selectedSemana) continue;

        String areaName = _obtenerZona(aud);
        double pct = double.tryParse(aud['compliance_percentage']?.toString() ?? '0') ?? 0.0;
        pAreas.putIfAbsent(areaName, () => []).add(pct);
      }
      _areasData = pAreas.entries.map((e) => MapEntry(e.key, e.value.reduce((a, b) => a + b) / e.value.length)).toList()..sort((a, b) => b.value.compareTo(a.value));

      Map<String, int> pOportunidades = {};
      for (var aud in _allAuditorias) {
        String fechaStr = _obtenerFecha(aud);
        if (fechaStr.isEmpty || !fechaStr.contains(_selectedAnio)) continue;

        double pct = double.tryParse(aud['compliance_percentage']?.toString() ?? '0') ?? 0.0;
        if (pct < _metaCumplimiento) {
          String areaName = _obtenerZona(aud);
          pOportunidades[areaName] = (pOportunidades[areaName] ?? 0) + 1;
        }
      }
      _oportunidadesData = pOportunidades.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

      Map<String, int> pHallazgos = {
        '¿Exceso de pertenencias personales/EPP en zona?': 0,
        '¿Materiales, repuestos o papeles innecesarios?': 0,
        '¿Archivos, carpetas o armarios sin rotular?': 0,
      };
      for (var aud in _auditoriasFiltradas) {
        if (aud['exceso_pertenencias']?.toString().toLowerCase() == 'no' || aud['exceso_pertenencias']?.toString() == '0') {
          pHallazgos['¿Exceso de pertenencias personales/EPP en zona?'] = pHallazgos['¿Exceso de pertenencias personales/EPP en zona?']! + 1;
        }
        if (aud['area_libre_materiales']?.toString().toLowerCase() == 'no' || aud['area_libre_materiales']?.toString() == '0') {
          pHallazgos['¿Materiales, repuestos o papeles innecesarios?'] = pHallazgos['¿Materiales, repuestos o papeles innecesarios?']! + 1;
        }
        if (aud['archivos_identificados']?.toString().toLowerCase() == 'no' || aud['archivos_identificados']?.toString() == '0') {
          pHallazgos['¿Archivos, carpetas o armarios sin rotular?'] = pHallazgos['¿Archivos, carpetas o armarios sin rotular?']! + 1;
        }
      }
      _hallazgosData = pHallazgos.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

      if (_selectedArea == 'Todas') {
        _duenoActual = _allAreasResponsables.isNotEmpty ? _allAreasResponsables.first : null;
      } else {
        try {
          _duenoActual = _allAreasResponsables.firstWhere((element) =>
              (element['territorio'] ?? element['sub_area'] ?? '').toString().toLowerCase().contains(_selectedArea.toLowerCase())
          );
        } catch (_) {
          _duenoActual = _allAreasResponsables.isNotEmpty ? _allAreasResponsables.first : null;
        }
      }
    });
  }

  Widget _buildMarcadorGlobalCard() {
    Color mainColor = _getColorCumplimiento(_promedioGeneral);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _getBgColorCumplimiento(_promedioGeneral),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: mainColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('INDICADOR GENERAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black54, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text('META 90%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: mainColor)),
                  const SizedBox(width: 6),
                  Icon(_promedioGeneral >= _metaCumplimiento ? Icons.check_circle_rounded : Icons.error_rounded, color: mainColor, size: 16),
                ],
              ),
            ],
          ),
          Text(
            '${_promedioGeneral.toStringAsFixed(1)}%',
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: mainColor, letterSpacing: -0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionFiltrosGrid() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, size: 18, color: Color(0xFF0D47A1)),
              SizedBox(width: 8),
              Text('Filtros de Auditoría', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.3,
            children: [
              _buildComponenteSelector('Año', _selectedAnio, _anios, (v) {
                _selectedAnio = v!;
                _actualizarSemanasDisponibles();
                _aplicarFiltrosYCalculos();
              }),
              _buildComponenteSelector('Semana', _selectedSemana, _semanas, (v) {
                _selectedSemana = v!;
                _aplicarFiltrosYCalculos();
              }),
              _buildComponenteSelector('Mes', _selectedMes, _meses, (v) {
                _selectedMes = v!;
                _actualizarSemanasDisponibles();
                _aplicarFiltrosYCalculos();
              }),
              _buildComponenteSelector('Zona / Territorio', _selectedArea, _areas, (v) {
                _selectedArea = v!;
                _aplicarFiltrosYCalculos();
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComponenteSelector(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    if (!items.contains(value)) value = items.isNotEmpty ? items.first : value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black45)),
        const SizedBox(height: 4),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: const Color(0xFFF1F3F5), borderRadius: BorderRadius.circular(10)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.bold),
                items: items.map((String op) => DropdownMenuItem(value: op, child: Text(op, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildSeccionDuenosFijos() {
    if (_duenoActual == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: const Center(child: Text('Sin dueños asignados para esta selección', style: TextStyle(color: Colors.black38))),
      );
    }

    String fotoAbi = _formatearUrlDrive(_duenoActual!['foto_abi']?.toString());
    String fotoOl = _formatearUrlDrive(_duenoActual!['foto_ol']?.toString());
    String nameAbi = (_duenoActual!['responsable_abi'] ?? 'No Asignado').toString();
    String nameOl = (_duenoActual!['ol'] ?? 'No Asignado').toString();
    String currentAreaName = (_duenoActual!['territorio'] ?? _duenoActual!['sub_area'] ?? 'Zona General').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('RESPONSABLES DIRECTOS: $currentAreaName', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black45, letterSpacing: 0.5)),
        ),
        Row(
          children: [
            Expanded(child: _buildTarjetaDuenioIndividual('DUEÑO ABI', nameAbi, fotoAbi)),
            const SizedBox(width: 12),
            Expanded(child: _buildTarjetaDuenioIndividual('DUEÑO OL', nameOl, fotoOl)),
          ],
        )
      ],
    );
  }

  Widget _buildTarjetaDuenioIndividual(String cargo, String nombre, String urlFoto) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFF0D47A1), borderRadius: BorderRadius.circular(4)),
            child: Text(cargo, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          Container(
            width: 65,
            height: 65,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF0D47A1), width: 2),
            ),
            child: ClipOval(
              child: urlFoto.isNotEmpty
                  ? Image.network(urlFoto, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 35, color: Colors.grey))
                  : const Icon(Icons.person, size: 35, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            nombre.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildCardGraficaSemanal() {
    String subetiquetaContexto = _selectedMes == 'Todas' ? 'MES ACTUAL' : _selectedMes.toUpperCase();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('EVOLUCIÓN SEMANAL - $subetiquetaContexto', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 18),
          SizedBox(
            height: 130,
            child: _semanasData.isEmpty
                ? const Center(child: Text('No hay auditorías registradas en este período', style: TextStyle(fontSize: 12, color: Colors.black38)))
                : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _semanasData.map((entry) {
                double compliance = entry.value;
                Color barColor = _getColorCumplimiento(compliance);
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('${compliance.toStringAsFixed(0)}%', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: barColor)),
                      const SizedBox(height: 4),
                      Container(
                        width: 24,
                        height: (compliance * 0.85),
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(entry.key, style: const TextStyle(fontSize: 9, color: Colors.black45, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }).toList(),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCardTablaAreasCompleta() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('RENDIMIENTO COMPARATIVO POR TERRITORIO', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 14),
          _areasData.isEmpty
              ? const Center(child: Text('Sin datos que procesar', style: TextStyle(fontSize: 12, color: Colors.black38)))
              : Table(
            columnWidths: const {
              0: FlexColumnWidth(2.5),
              1: FlexColumnWidth(1.0),
            },
            border: TableBorder(horizontalInside: BorderSide(color: Colors.grey.shade100, width: 1)),
            children: [
              const TableRow(
                decoration: BoxDecoration(color: Color(0xFFF1F3F5)),
                children: [
                  Padding(padding: EdgeInsets.all(8.0), child: Text('TERRITORIO / ZONA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54))),
                  Padding(padding: EdgeInsets.all(8.0), child: Text('RESULTADO', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54))),
                ],
              ),
              ..._areasData.map((entry) {
                double valor = entry.value;
                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
                      child: Text(entry.key.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black87)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getBgColorCumplimiento(valor),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${valor.toStringAsFixed(0)}%',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _getColorCumplimiento(valor)),
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
    );
  }

  Widget _buildSeccionDeficienciasYHallazgos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ZONAS CON MAYOR MEJORA REQUERIDA', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _oportunidadesData.isEmpty
                    ? [const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('Todas las zonas superan la meta', style: TextStyle(fontSize: 12, color: Colors.black38)))]
                    : _oportunidadesData.take(4).map((entry) => _buildIndicadorOportunidadVertical(entry.key, entry.value)).toList(),
              )
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TOP HALLAZGOS DETECTADOS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 10),
              ..._hallazgosData.map((entry) => _buildFilaItemHallazgo(entry.key, entry.value)),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildIndicadorOportunidadVertical(String label, int count) {
    return Column(
      children: [
        Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
        const SizedBox(height: 4),
        Container(
          width: 20,
          height: (count * 25.0 > 80.0 ? 80.0 : count * 25.0),
          decoration: BoxDecoration(color: Colors.deepOrange.shade600, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(height: 6),
        SizedBox(width: 65, child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.black54))),
      ],
    );
  }

  Widget _buildFilaItemHallazgo(String descriptor, int alertCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        children: [
          Expanded(child: Text(descriptor, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500))),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: alertCount > 0 ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(20)),
            child: Text('$alertCount', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: alertCount > 0 ? const Color(0xFFC62828) : const Color(0xFF1B5E20))),
          )
        ],
      ),
    );
  }

  Widget _buildTablaDetalleCompleto() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('HISTÓRICO RECIENTE DE AUDITORÍAS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),
          _auditoriasFiltradas.isEmpty
              ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text('No hay datos con los filtros seleccionados', style: TextStyle(fontSize: 12, color: Colors.black38))),
          )
              : ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _auditoriasFiltradas.length > 8 ? 8 : _auditoriasFiltradas.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F3F5)),
            itemBuilder: (context, i) {
              final row = _auditoriasFiltradas[i];
              double res = double.tryParse(row['compliance_percentage']?.toString() ?? '0') ?? 0.0;

              int numeroSemanaCalculada = 0;
              String fechaStr = _obtenerFecha(row);
              if (fechaStr.isNotEmpty) {
                try {
                  numeroSemanaCalculada = _getWeekNumber(DateTime.parse(fechaStr));
                } catch (_) {}
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_obtenerZona(row).toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                          const SizedBox(height: 2),
                          Text('Semana $numeroSemanaCalculada • Auditor: ${row['users'] ?? 'N/A'}', style: const TextStyle(fontSize: 11, color: Colors.black45, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: _getBgColorCumplimiento(res), borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        '${res.toStringAsFixed(0)}%',
                        style: TextStyle(color: _getColorCumplimiento(res), fontSize: 12, fontWeight: FontWeight.w900),
                      ),
                    )
                  ],
                ),
              );
            },
          )
        ],
      ),
    );
  }

  Color _getColorCumplimiento(double valor) {
    return valor >= _metaCumplimiento ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C);
  }

  Color _getBgColorCumplimiento(double valor) {
    return valor >= _metaCumplimiento ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);
  }

  String _formatearUrlDrive(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.contains('drive.google.com')) {
      final regex = RegExp(r'id=([a-zA-Z0-9_-]+)');
      final match = regex.firstMatch(url);
      if (match != null) {
        return 'https://drive.google.com/uc?export=view&id=${match.group(1)}';
      }
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0D47A1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Dashboard 5S Bavaria', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1)))
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMarcadorGlobalCard(),
            const SizedBox(height: 16),
            _buildSeccionFiltrosGrid(),
            const SizedBox(height: 16),
            _buildSeccionDuenosFijos(),
            const SizedBox(height: 16),
            _buildCardGraficaSemanal(),
            const SizedBox(height: 16),
            _buildCardTablaAreasCompleta(),
            const SizedBox(height: 16),
            _buildSeccionDeficienciasYHallazgos(),
            const SizedBox(height: 16),
            _buildTablaDetalleCompleto(),
          ],
        ),
      ),
    );
  }
}