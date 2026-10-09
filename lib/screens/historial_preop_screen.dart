import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../services/api_service.dart';

class HistorialPreopScreen extends StatefulWidget {
  final Map<String, dynamic> datosEmpleado;
  const HistorialPreopScreen({super.key, required this.datosEmpleado});

  @override
  State<HistorialPreopScreen> createState() => _HistorialPreopScreenState();
}

class _HistorialPreopScreenState extends State<HistorialPreopScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoadingPistola = true;
  bool _isLoadingManuales = true;
  bool _isLoadingBomba = true;
  bool _isLoadingNeumatica = true;

  List<dynamic> _registrosPistola = [];
  List<dynamic> _registrosManuales = [];
  List<dynamic> _registrosBomba = [];
  List<dynamic> _registrosNeumatica = [];

  // 🔍 CONTROLADORES PARA FILTROS GLOBALIZADOS
  int? _mesSeleccionado;
  String? _turnoSeleccionado;
  final _operarioController = TextEditingController();

  final List<String> _opcionesTurno = ['T1', 'T2', 'T3', '6:00AM-2:00PM', '2:00PM-10:00PM', '10:00PM-6:00AM'];
  final List<Map<String, dynamic>> _listaMeses = [
    {'id': 1, 'nombre': 'Enero'}, {'id': 2, 'nombre': 'Febrero'}, {'id': 3, 'nombre': 'Marzo'},
    {'id': 4, 'nombre': 'Abril'}, {'id': 5, 'nombre': 'Mayo'}, {'id': 6, 'nombre': 'Junio'},
    {'id': 7, 'nombre': 'Julio'}, {'id': 8, 'nombre': 'Agosto'}, {'id': 9, 'nombre': 'Septiembre'},
    {'id': 10, 'nombre': 'Octubre'}, {'id': 11, 'nombre': 'Noviembre'}, {'id': 12, 'nombre': 'Diciembre'},
  ];

  final List<Map<String, String>> _preguntasPistola = [
    {'key': 'registro_personal_autorizado', 'label': 'Listado / registro de personal autorizado'},
    {'key': 'uso_epp_requeridos', 'label': 'Uso de Elementos de Protección Personal (EPP)'},
    {'key': 'mango_sujecion_seguro', 'label': 'Mango de sujeción seguro y sin daños'},
    {'key': 'tornilleria_completa_ajustada', 'label': 'Tornillería completa, ajustada y en buen estado'},
    {'key': 'gatillo_funciona_suave', 'label': 'Gatillo funciona suave y sin atascos'},
    {'key': 'mangueras_optimo_estado', 'label': 'Mangueras en óptimo estado (sin cortes/grietas)'},
    {'key': 'abrazaderas_instaladas_correctamente', 'label': 'Abrazaderas (inicio/final) correctamente instaladas'},
    {'key': 'acoples_operativos_condiciones', 'label': 'Dos acoples operativos y en buen estado'},
    {'key': 'libres_fugas', 'label': 'Herramienta y líneas totalmente libres de fugas'},
    {'key': 'opera_presiones_indicadas', 'label': 'Opera a presiones indicadas (80 - 120 PSI)'},
    {'key': 'herramienta_despresurizada_correctamente', 'label': 'Herramienta descargada / despresurizada al terminar'},
    {'key': 'clavadoras_limpias_almacenadas', 'label': 'Clavadoras neumáticas limpias y almacenadas'},
  ];

  final List<Map<String, String>> _preguntasNeumatica = [
    {'key': 'carcasa_tornillos_ajustados', 'label': 'Carcasa y tornillos ajustados'},
    {'key': 'gatillo_seguro_suave', 'label': 'Gatillo y seguro funcionamiento suave'},
    {'key': 'sin_fugas_aire_cuerpo', 'label': 'Sin fugas de aire en el cuerpo'},
    {'key': 'lubricacion_adecuada', 'label': 'Lubricación adecuada'},
    {'key': 'manguera_sin_cortes', 'label': 'Manguera sin cortes o grietas'},
    {'key': 'acoples_rapidos_bien', 'label': 'Acoples rápidos ajustan bien'},
    {'key': 'sin_fugas_conexiones', 'label': 'Sin fugas en conexiones'},
  ];

  final List<Map<String, String>> _preguntasManuales = [
    {'key': 'martillo_limpio_buen_estado', 'label': 'Estado general y limpieza'},
    {'key': 'martillo_mango_sin_grietas', 'label': 'Mango libre de grietas'},
    {'key': 'martillo_empunadura_fija', 'label': 'Uñas / Empuñadura fija'},
    {'key': 'martillo_cinta_mes', 'label': 'Cuenta con cinta color del mes'},

    {'key': 'estibador_limpio_operativo', 'label': 'Estado general y limpieza'},
    {'key': 'estibador_timon_firme', 'label': 'Timón firme y seguro'},
    {'key': 'estibador_ruedas_giran', 'label': 'Ruedas giran sin dificultad'},
    {'key': 'estibador_unas_alineadas', 'label': 'Uñas alineadas y en buen estado'},
    {'key': 'estibador_hidraulico_sube_baja', 'label': 'El estibador sube y baja sin dificultad'},
    {'key': 'estibador_direccion_gira', 'label': 'El estibador gira sin dificultad'},
    {'key': 'estibador_sin_fugas', 'label': 'No se detectan fugas de aceite'},
    {'key': 'estibador_cinta_mes', 'label': 'Cuenta con cinta color del mes'},

    {'key': 'barra_limpia_adecuada', 'label': 'Estado general y limpieza'},
    {'key': 'barra_libre_grasa', 'label': 'Libre de grasa'},
    {'key': 'barra_unas_buen_estado', 'label': 'Uñas en buen estado'},
    {'key': 'barra_cinta_mes', 'label': 'Cuenta con cinta color del mes'},
  ];

  final List<Map<String, String>> _preguntasBomba = [
    {'key': 'carcasa_optimo_estado', 'label': 'Carcasa del equipo en óptimo estado físico'},
    {'key': 'guardas_seguridad_optimas', 'label': 'Guardas de seguridad instaladas y óptimas'},
    {'key': 'cable_tierra_seguros', 'label': 'Cable de puesta a tierra y seguros en buen estado'},
    {'key': 'limitador_aire_funcional', 'label': 'Limitador de aire plenamente funcional'},
    {'key': 'libre_fugas_fluidos', 'label': 'Libre de fugas de fluidos o aceite'},
    {'key': 'certificado_mantenimiento_vigente', 'label': 'Certificado de mantenimiento preventivo vigente'},
    {'key': 'dispositivo_bloqueo_operativo', 'label': 'Dispositivo de bloqueo opera correctamente'},
    {'key': 'interruptor_encendido_correcto', 'label': 'Interruptor encendido/apagado funciona'},
    {'key': 'manometro_presion_optima', 'label': 'Manómetro de presión en rango óptimo'},
    {'key': 'mangueras_boquillas_buen_estado', 'label': 'Mangueras y boquillas sin cortes o desgaste'},
    {'key': 'tanque_sin_corrosion', 'label': 'Tanque libre de corrosión o daños'},
    {'key': 'acople_pistola_sin_fugas', 'label': 'Acople de pistola sin fugas'},
    {'key': 'valvula_alivio_adecuada', 'label': 'Válvula de alivio en estado adecuado'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _ejecutarConsultasFiltradas();
  }

  void _ejecutarConsultasFiltradas() {
    setState(() {
      _isLoadingPistola = true;
      _isLoadingManuales = true;
      _isLoadingBomba = true;
      _isLoadingNeumatica = true;
    });
    _cargarHistorialPistola();
    _cargarHistorialManuales();
    _cargarHistorialBomba();
    _cargarHistorialNeumatica();
  }

  Future<void> _cargarHistorialPistola() async {
    try {
      final url = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/consultar/${ApiService.schema}/estibas_pistolas');
      final response = await http.get(url, headers: {'Content-Type': 'application/json', 'x-api-key': ApiService.apiKey});

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> data = [];

        // 🛡️ REGLA INTELIGENTE DE LECTURA
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map<String, dynamic> && decoded['data'] != null) {
          data = decoded['data'] is List ? decoded['data'] : [];
        }

        final filtrados = _filtrarYOrdenar(data);
        if (mounted) setState(() { _registrosPistola = filtrados; _isLoadingPistola = false; });
      } else {
        if (mounted) setState(() => _isLoadingPistola = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingPistola = false);
    }
  }

  Future<void> _cargarHistorialNeumatica() async {
    try {
      final url = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/consultar/${ApiService.schema}/reparacion_estibas_preo_neumatica');
      final response = await http.get(url, headers: {'Content-Type': 'application/json', 'x-api-key': ApiService.apiKey});

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> data = [];

        // 🛡️ REGLA INTELIGENTE DE LECTURA
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map<String, dynamic> && decoded['data'] != null) {
          data = decoded['data'] is List ? decoded['data'] : [];
        }

        final filtrados = _filtrarYOrdenar(data);
        if (mounted) setState(() { _registrosNeumatica = filtrados; _isLoadingNeumatica = false; });
      } else {
        if (mounted) setState(() => _isLoadingNeumatica = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingNeumatica = false);
    }
  }

  Future<void> _cargarHistorialManuales() async {
    try {
      final url = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/consultar/${ApiService.schema}/estibas_herramientas_manuales');
      final response = await http.get(url, headers: {'Content-Type': 'application/json', 'x-api-key': ApiService.apiKey});

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> data = [];

        // 🛡️ REGLA INTELIGENTE DE LECTURA
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map<String, dynamic> && decoded['data'] != null) {
          data = decoded['data'] is List ? decoded['data'] : [];
        }

        final filtrados = _filtrarYOrdenar(data);
        if (mounted) setState(() { _registrosManuales = filtrados; _isLoadingManuales = false; });
      } else {
        if (mounted) setState(() => _isLoadingManuales = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingManuales = false);
    }
  }

  Future<void> _cargarHistorialBomba() async {
    try {
      final url = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/consultar/${ApiService.schema}/estibas_bomba');
      final response = await http.get(url, headers: {'Content-Type': 'application/json', 'x-api-key': ApiService.apiKey});

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> data = [];

        // 🛡️ REGLA INTELIGENTE DE LECTURA
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map<String, dynamic> && decoded['data'] != null) {
          data = decoded['data'] is List ? decoded['data'] : [];
        }

        final filtrados = _filtrarYOrdenar(data);
        if (mounted) setState(() { _registrosBomba = filtrados; _isLoadingBomba = false; });
      } else {
        if (mounted) setState(() => _isLoadingBomba = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingBomba = false);
    }
  }

  List<dynamic> _filtrarYOrdenar(List<dynamic> registros) {
    var resultados = registros.where((row) {
      bool pasaOperario = true;
      bool pasaTurno = true;
      bool pasaMes = true;

      if (_operarioController.text.trim().isNotEmpty) {
        final op = (row['auxiliar'] ?? '').toString().toLowerCase();
        pasaOperario = op.contains(_operarioController.text.trim().toLowerCase());
      }

      if (_turnoSeleccionado != null) {
        pasaTurno = (row['turno'] ?? '') == _turnoSeleccionado;
      }

      if (_mesSeleccionado != null) {
        final fecha = row['fecha']?.toString() ?? '';
        if (fecha.length >= 7) {
          int mesRow = int.tryParse(fecha.substring(5, 7)) ?? 0;
          int anioRow = int.tryParse(fecha.substring(0, 4)) ?? 0;
          int anioActual = DateTime.now().year;
          pasaMes = (mesRow == _mesSeleccionado && anioRow == anioActual);
        } else {
          pasaMes = false;
        }
      }

      return pasaOperario && pasaTurno && pasaMes;
    }).toList();

    resultados.sort((a, b) => (b['fecha'] ?? '').toString().compareTo((a['fecha'] ?? '').toString()));
    if (resultados.length > 50) resultados = resultados.sublist(0, 50);

    return resultados;
  }

  void _limpiarFiltros() {
    setState(() {
      _mesSeleccionado = null;
      _turnoSeleccionado = null;
      _operarioController.clear();
    });
    _ejecutarConsultasFiltradas();
  }

  pw.ImageProvider? _obtenerFirmaPdf(String? base64Str) {
    if (base64Str == null || base64Str.isEmpty || base64Str == 'null' || base64Str == 'SIN_FIRMA') return null;
    try {
      return pw.MemoryImage(base64Decode(base64Str));
    } catch (e) {
      return null;
    }
  }

  Future<pw.ImageProvider?> _cargarImagenLocal(String path) async {
    try {
      final data = await rootBundle.load(path);
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (e) { return null; }
  }

  Future<void> _procesarYMostrarPdf(Map<String, dynamic> registro, String tipoModulo) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF0D47A1)),
                SizedBox(height: 15),
                Text('Generando documento\nPDF oficial...', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final fAux = _obtenerFirmaPdf(registro['firma'] ?? registro['firma_auxiliar']);
      final imgLogo = await _cargarImagenLocal('assets/icon/app_logo.png');

      final Map<String, pw.ImageProvider?> iconosHerramientas = {
        'pistola': null, 'martillo': null, 'estibador': null, 'barra': null, 'bomba': null,
      };

      final pdf = pw.Document();

      List<Map<String, String>> preguntas;
      String tituloFormato;
      String codigoFormato;

      if (tipoModulo == 'pistola') {
        preguntas = _preguntasPistola;
        tituloFormato = 'INSPECCIÓN PREOPERACIONAL PISTOLA DE IMPACTO / CLAVADORA';
        codigoFormato = 'CO-EL-SST-FT-48';
      } else if (tipoModulo == 'neumatica') {
        preguntas = _preguntasNeumatica;
        tituloFormato = 'INSPECCIÓN PREOPERACIONAL PISTOLA DE IMPACTO NEUMÁTICA';
        codigoFormato = 'CO-EL-SST-FT-48';
      } else if (tipoModulo == 'bomba') {
        preguntas = _preguntasBomba;
        tituloFormato = 'INSPECCIÓN PREOPERACIONAL BOMBA DE PINTURA';
        codigoFormato = 'CO-EL-SST-FT-49';
      } else {
        preguntas = _preguntasManuales;
        tituloFormato = 'SISTEMA DE GESTIÓN DE SEGURIDAD Y SALUD EN EL TRABAJO\nINSPECCIÓN DE HERRAMIENTAS MANUALES';
        codigoFormato = 'CO-EL-SST-FT-44';
      }

      bool tieneNoCumple = preguntas.any((p) {
        final val = registro[p['key']]?.toString().trim().toLowerCase() ?? '';
        return val == 'no cumple' || val == 'malo';
      });

      String estadoFinal = registro['estado']?.toString() ?? (tieneNoCumple ? 'NO APTO' : 'APTO');

      // Formatear fecha para el PDF
      String fechaPdf = registro['fecha']?.toString() ?? '';
      if (fechaPdf.length > 10) fechaPdf = fechaPdf.substring(0, 10);

      // Evaluar observaciones
      String observaciones = registro['observacion'] ?? registro['observaciones']?.toString() ?? 'SIN OBSERVACIONES';
      if (observaciones.trim().isEmpty) observaciones = 'SIN OBSERVACIONES';

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Table(
                  border: pw.TableBorder.all(),
                  columnWidths: {0: const pw.FlexColumnWidth(1.5), 1: const pw.FlexColumnWidth(4), 2: const pw.FlexColumnWidth(2)},
                  children: [
                    pw.TableRow(
                      children: [
                        pw.Container(
                          height: 50,
                          alignment: pw.Alignment.center,
                          child: imgLogo != null ? pw.Image(imgLogo, height: 40) : pw.Text('EASY LOGÍSTICA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue800, fontSize: 10)),
                        ),
                        pw.Container(
                          alignment: pw.Alignment.center,
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(tituloFormato, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text('Código: $codigoFormato', style: const pw.TextStyle(fontSize: 7))),
                            pw.Divider(height: 0, thickness: 0.5),
                            pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text('Versión: 03', style: const pw.TextStyle(fontSize: 7))),
                            pw.Divider(height: 0, thickness: 0.5),
                            pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text('Fecha: 25/03/2025', style: const pw.TextStyle(fontSize: 7))),
                          ],
                        )
                      ],
                    )
                  ],
                ),
                pw.SizedBox(height: 10),

                // TABLA DE DATOS DEL FORMULARIO
                pw.Table(
                  border: pw.TableBorder.all(),
                  children: [
                    pw.TableRow(children: [
                      _buildPdfCell('Turno:', true),
                      _buildPdfCell(registro['turno']?.toString() ?? ''),
                      _buildPdfCell('Área:', true),
                      _buildPdfCell(registro['area']?.toString() ?? 'REPARACIÓN ESTIBAS')
                    ]),
                    pw.TableRow(children: [
                      _buildPdfCell('Fecha:', true),
                      _buildPdfCell(fechaPdf),
                      _buildPdfCell('Auxiliar:', true),
                      _buildPdfCell(registro['auxiliar']?.toString() ?? '')
                    ]),
                    pw.TableRow(children: [
                      _buildPdfCell('Supervisor:', true),
                      _buildPdfCell(registro['supervisor']?.toString() ?? ''),
                      if (tipoModulo == 'pistola' || tipoModulo == 'neumatica' || tipoModulo == 'bomba') ...[
                        _buildPdfCell('Serie Equipo:', true),
                        _buildPdfCell(registro['serie']?.toString() ?? '')
                      ] else ...[
                        _buildPdfCell('', false),
                        _buildPdfCell('')
                      ]
                    ]),
                  ],
                ),
                pw.SizedBox(height: 10),

                _buildChecklistTable(tipoModulo, preguntas, registro, iconosHerramientas),
                pw.SizedBox(height: 10),

                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(border: pw.Border.all()),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Observación: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                      pw.Expanded(child: pw.Text(observaciones, style: const pw.TextStyle(fontSize: 8))),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),

                // TABLA DE FIRMA
                pw.Table(
                  border: pw.TableBorder.all(),
                  columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(3), 2: const pw.FlexColumnWidth(3)},
                  children: [
                    pw.TableRow(children: [
                      _buildPdfCell('Auxiliar Responsable:', true),
                      _buildPdfCell(registro['auxiliar']?.toString() ?? ''),
                      pw.Container(
                        height: 45,
                        alignment: pw.Alignment.center,
                        child: fAux != null
                            ? pw.Image(fAux)
                            : pw.Text('Sin firma', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                      )
                    ]),
                  ],
                ),
                pw.SizedBox(height: 12),

                pw.Center(
                  child: pw.Text(
                    'ESTADO OPERACIONAL: $estadoFinal',
                    style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: estadoFinal == 'APTO' ? PdfColors.green800 : PdfColors.red800),
                  ),
                ),
              ],
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();
      if (!mounted) return;
      Navigator.pop(context);
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdfBytes);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al generar reporte: $e'), backgroundColor: Colors.red));
    }
  }

  pw.Widget _buildChecklistTable(String tipoModulo, List<Map<String, String>> preguntas, Map<String, dynamic> registro, Map<String, pw.ImageProvider?> iconos) {
    pw.TableRow buildNestedRow(String titulo, pw.ImageProvider? icono, List<Map<String, String>> preguntasBloque) {
      return pw.TableRow(
        children: [
          pw.Container(
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.all(5),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                if (icono != null) pw.Image(icono, height: 40),
                pw.SizedBox(height: 5),
                pw.Text(titulo, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
              ],
            ),
          ),
          pw.Table(
            border: pw.TableBorder.symmetric(inside: const pw.BorderSide()),
            columnWidths: {0: const pw.FlexColumnWidth(5), 1: const pw.FlexColumnWidth(1.2)},
            children: preguntasBloque.map((p) {
              final valorResp = registro[p['key']]?.toString() ?? 'N/A';
              final valLower = valorResp.trim().toLowerCase();

              PdfColor colorResp = PdfColors.black;
              if (valLower == 'cumple' || valLower == 'bueno') {
                colorResp = PdfColors.green800;
              } else if (valLower == 'no cumple' || valLower == 'malo') {
                colorResp = PdfColors.red800;
              }

              return pw.TableRow(
                children: [
                  _buildPdfCell(p['label']!),
                  pw.Container(
                    alignment: pw.Alignment.center,
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      valorResp,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: colorResp, fontSize: 8),
                    ),
                  )
                ],
              );
            }).toList(),
          )
        ],
      );
    }

    final cabeceraTabla = pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: [
        _buildPdfCell('Módulo', true, true),
        pw.Table(
          columnWidths: {0: const pw.FlexColumnWidth(5), 1: const pw.FlexColumnWidth(1.2)},
          children: [
            pw.TableRow(children: [_buildPdfCell('Criterio Técnico Evaluado', true), _buildPdfCell('Estado', true, true)])
          ],
        )
      ],
    );

    if (tipoModulo == 'pistola') {
      return pw.Table(
        border: pw.TableBorder.all(),
        columnWidths: {0: const pw.FlexColumnWidth(1.5), 1: const pw.FlexColumnWidth(6)},
        children: [cabeceraTabla, buildNestedRow('Pistola Neumática', iconos['pistola'], preguntas)],
      );
    } else if (tipoModulo == 'neumatica') {
      return pw.Table(
        border: pw.TableBorder.all(),
        columnWidths: {0: const pw.FlexColumnWidth(1.5), 1: const pw.FlexColumnWidth(6)},
        children: [cabeceraTabla, buildNestedRow('Pistola Neumática', iconos['pistola'], preguntas)],
      );
    } else if (tipoModulo == 'bomba') {
      return pw.Table(
        border: pw.TableBorder.all(),
        columnWidths: {0: const pw.FlexColumnWidth(1.5), 1: const pw.FlexColumnWidth(6)},
        children: [cabeceraTabla, buildNestedRow('Bomba de Pintura', iconos['bomba'], preguntas)],
      );
    } else {
      final pMartillo = preguntas.where((p) => p['key']!.startsWith('martillo')).toList();
      final pEstibador = preguntas.where((p) => p['key']!.startsWith('estibador')).toList();
      final pBarra = preguntas.where((p) => p['key']!.startsWith('barra')).toList();

      return pw.Table(
        border: pw.TableBorder.all(),
        columnWidths: {0: const pw.FlexColumnWidth(1.5), 1: const pw.FlexColumnWidth(6)},
        children: [
          cabeceraTabla,
          buildNestedRow('Martillo', iconos['martillo'], pMartillo),
          buildNestedRow('Estibador Manual', iconos['estibador'], pEstibador),
          buildNestedRow('Barra de Uña', iconos['barra'], pBarra),
        ],
      );
    }
  }

  pw.Widget _buildPdfCell(String text, [bool isBold = false, bool isCenter = false]) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        textAlign: isCenter ? pw.TextAlign.center : pw.TextAlign.left,
        style: pw.TextStyle(fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Historial de Preoperacionales', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          tabs: const [
            Tab(icon: Icon(Icons.hardware), text: 'Pistola'),
            Tab(icon: Icon(Icons.handyman), text: 'H. Manuales'),
            Tab(icon: Icon(Icons.invert_colors), text: 'Bomba'),
            Tab(icon: Icon(Icons.build_outlined), text: 'Neumática (Ant.)'),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _mesSeleccionado,
                        isDense: true,
                        decoration: InputDecoration(
                          labelText: 'Mes',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: [
                          const DropdownMenuItem<int>(value: null, child: Text('Todos', style: TextStyle(fontSize: 13))),
                          ..._listaMeses.map((m) => DropdownMenuItem<int>(value: m['id'], child: Text(m['nombre'], style: const TextStyle(fontSize: 13)))).toList()
                        ],
                        onChanged: (val) => setState(() => _mesSeleccionado = val),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _turnoSeleccionado,
                        isDense: true,
                        decoration: InputDecoration(
                          labelText: 'Turno',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('Todos', style: TextStyle(fontSize: 13))),
                          ..._opcionesTurno.map((t) => DropdownMenuItem<String>(value: t, child: Text(t, style: const TextStyle(fontSize: 11)))).toList()
                        ],
                        onChanged: (val) => setState(() => _turnoSeleccionado = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: TextField(
                          controller: _operarioController,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'Nombre Operario',
                            prefixIcon: const Icon(Icons.person, size: 18),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D47A1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onPressed: _ejecutarConsultasFiltradas,
                      child: const Icon(Icons.search, size: 18),
                    ),
                    const SizedBox(width: 5),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.grey),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onPressed: _limpiarFiltros,
                      child: const Icon(Icons.refresh, size: 18, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildListadoTab(_isLoadingPistola, _registrosPistola, 'pistola', _cargarHistorialPistola),
                _buildListadoTab(_isLoadingManuales, _registrosManuales, 'manuales', _cargarHistorialManuales),
                _buildListadoTab(_isLoadingBomba, _registrosBomba, 'bomba', _cargarHistorialBomba),
                _buildListadoTab(_isLoadingNeumatica, _registrosNeumatica, 'neumatica', _cargarHistorialNeumatica),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListadoTab(bool isLoading, List<dynamic> registros, String tipoModulo, Future<void> Function() onRefresh) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1)));
    }
    if (registros.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_outlined, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 15),
            const Text('Sin resultados para esta búsqueda', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey)),
            const Text('Prueba cambiando los filtros superiores.', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: const Color(0xFF0D47A1),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: registros.length,
        itemBuilder: (context, i) {
          final reg = registros[i];

          // Formatear la fecha para la lista visible (cortar la T y zona horaria)
          String fechaLimpia = reg['fecha']?.toString() ?? 'S/F';
          if (fechaLimpia.length > 10) {
            fechaLimpia = fechaLimpia.substring(0, 10);
          }

          final String turno = reg['turno']?.toString() ?? 'S/T';
          final String auxiliar = reg['auxiliar']?.toString() ?? 'OPERADOR';

          List<Map<String, String>> preguntas;
          if (tipoModulo == 'pistola') preguntas = _preguntasPistola;
          else if (tipoModulo == 'neumatica') preguntas = _preguntasNeumatica;
          else if (tipoModulo == 'bomba') preguntas = _preguntasBomba;
          else preguntas = _preguntasManuales;

          bool tieneNoCumple = preguntas.any((p) {
            final val = reg[p['key']]?.toString().trim().toLowerCase() ?? '';
            return val == 'no cumple' || val == 'malo';
          });

          final String estado = reg['estado']?.toString() ?? (tieneNoCumple ? 'NO APTO' : 'APTO');
          final bool esApto = estado == 'APTO';

          return Card(
            color: Colors.white,
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                if (i == 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_done_outlined, size: 13, color: Colors.blue.shade800),
                        const SizedBox(width: 5),
                        Text('Mostrando resultados más recientes (Máx. 50)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
                      ],
                    ),
                  ),

                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: i == 0 ? const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)) : BorderRadius.circular(12),
                    border: Border(left: BorderSide(color: esApto ? Colors.green : Colors.red, width: 6)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(fechaLimpia, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF263238))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: esApto ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: esApto ? Colors.green : Colors.red, width: 0.5),
                          ),
                          child: Text(
                            estado,
                            style: TextStyle(color: esApto ? Colors.green.shade700 : Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        )
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Responsable: $auxiliar', style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text('Turno: $turno', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          if ((tipoModulo == 'pistola' || tipoModulo == 'neumatica' || tipoModulo == 'bomba') && reg['serie'] != null)
                            Text('Serie de Equipo: ${reg['serie']}', style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade700, fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                    trailing: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D47A1),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.picture_as_pdf, size: 16),
                      label: const Text('PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () => _procesarYMostrarPdf(reg, tipoModulo),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _operarioController.dispose();
    super.dispose();
  }
}