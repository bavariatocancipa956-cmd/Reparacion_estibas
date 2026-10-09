import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:signature/signature.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../services/api_service.dart';

class PreoHManualesScreen extends StatefulWidget {
  final Map<String, dynamic> datosEmpleado;
  const PreoHManualesScreen({super.key, required this.datosEmpleado});

  @override
  State<PreoHManualesScreen> createState() => _PreoHManualesScreenState();
}

class _PreoHManualesScreenState extends State<PreoHManualesScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  List<String> _listaSupervisores = [];

  // 🇨🇴 FECHA FIJADA A HORA COLOMBIA (UTC-5)
  final _fechaController = TextEditingController(
    text: DateTime.now().toUtc().subtract(const Duration(hours: 5)).toString().substring(0, 10),
  );

  final _supervisorController = TextEditingController();
  final _observacionController = TextEditingController();

  String? _turnoSeleccionado;
  final List<String> _opcionesTurno = ['T1', 'T2', 'T3'];

  final SignatureController _firmaAuxiliar = SignatureController(
    penStrokeWidth: 1.5,
    penColor: Colors.black,
    exportBackgroundColor: Colors.transparent,
  );

  final Map<String, String> _respuestas = {};

  final List<Map<String, String>> _itemsMartillo = [
    {'key': 'martillo_limpio_buen_estado', 'label': '¿La herramienta se encuentra limpia y en buen estado físico general?'},
    {'key': 'martillo_mango_sin_grietas', 'label': '¿El mango está en buenas condiciones estructurales, completamente libre de grietas o astillas?'},
    {'key': 'martillo_empunadura_fija', 'label': '¿La empuñadura o recubrimiento antideslizante se encuentra fijo, sin desgaste excesivo y en buen estado?'},
    {'key': 'martillo_cinta_mes', 'label': '¿La herramienta cuenta con la cinta de inspección visual del color correspondiente al mes actual?'},
  ];

  final List<Map<String, String>> _itemsEstibador = [
    {'key': 'estibador_limpio_operativo', 'label': '¿El equipo se encuentra limpio y en condiciones operativas adecuadas?'},
    {'key': 'estibador_timon_firme', 'label': '¿El mango de tracción (timón) está firme, libre de grietas y deformaciones?'},
    {'key': 'estibador_ruedas_giran', 'label': '¿Las ruedas directrices y los rodillos de carga están en buen estado y giran sin dificultad?'},
    {'key': 'estibador_unas_alineadas', 'label': '¿Las uñas u horquillas se encuentran alineadas, sin deformaciones ni desgaste estructural evidente?'},
    {'key': 'estibador_hidraulico_sube_baja', 'label': '¿El sistema hidráulico permite subir y bajar las uñas de manera suave, continua y sin dificultad?'},
    {'key': 'estibador_direccion_gira', 'label': '¿El sistema de dirección opera correctamente y permite girar el estibador sin atascos?'},
    {'key': 'estibador_sin_fugas', 'label': '¿El sistema hidráulico (botella y empaques) se encuentra completamente libre de fugas de aceite?'},
    {'key': 'estibador_cinta_mes', 'label': '¿El equipo cuenta con la cinta de inspección visual del color correspondiente al mes actual?'},
  ];

  final List<Map<String, String>> _itemsBarra = [
    {'key': 'barra_limpia_adecuada', 'label': '¿El estado general de la herramienta es adecuado y se encuentra limpia?'},
    {'key': 'barra_libre_grasa', 'label': '¿La herramienta está completamente libre de grasa, aceite o sustancias que impidan un agarre seguro?'},
    {'key': 'barra_unas_buen_estado', 'label': '¿Las uñas o extremos de palanca se encuentran en buen estado, sin fisuras, roturas o deformaciones?'},
    {'key': 'barra_cinta_mes', 'label': '¿La herramienta cuenta con la cinta de inspección visual del color correspondiente al mes actual?'},
  ];

  @override
  void initState() {
    super.initState();
    _cargarSupervisores();
  }

  Future<void> _cargarSupervisores() async {
    try {
      final urlSup = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/consultar/roturas/rotura_lista');
      final resSup = await http.get(urlSup, headers: {
        'Content-Type': 'application/json',
        'x-api-key': ApiService.apiKey,
      });

      if (resSup.statusCode == 200) {
        final decoded = jsonDecode(resSup.body);
        List<dynamic> data = [];

        // 🛡️ REGLA INTELIGENTE DE LECTURA
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map<String, dynamic> && decoded['data'] != null) {
          data = decoded['data'] is List ? decoded['data'] : [];
        }

        final supervisores = data
            .map((e) => (e['supervisor'] ?? e['Supervisor'] ?? '').toString())
            .where((s) => s.isNotEmpty && s.toUpperCase() != 'NO APLICA')
            .map((s) => s.replaceAll(RegExp(r'[0-9-]'), '').replaceAll(RegExp(r'\s+'), ' ').trim())
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList();

        if (mounted) {
          setState(() {
            _listaSupervisores = supervisores;
          });
        }
      }
    } catch (e) {
      debugPrint('Error cargando supervisores: $e');
    }
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? seleccionado = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_fechaController.text) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (seleccionado != null) {
      setState(() => _fechaController.text = seleccionado.toString().substring(0, 10));
    }
  }

  void _marcarTodoCumple() {
    setState(() {
      for (var p in _itemsMartillo) { _respuestas[p['key']!] = 'Cumple'; }
      for (var p in _itemsEstibador) { _respuestas[p['key']!] = 'Cumple'; }
      for (var p in _itemsBarra) { _respuestas[p['key']!] = 'Cumple'; }
    });
  }

  Future<String?> _convertirFirmaABase64(SignatureController controller) async {
    if (controller.isEmpty) return null;
    final Uint8List? firmaBytes = await controller.toPngBytes();
    if (firmaBytes == null) return null;
    return base64Encode(firmaBytes);
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

  // 📄 GENERACIÓN DEL PDF IDÉNTICO AL DEL HISTORIAL (INSPECCIÓN DE HERRAMIENTAS MANUALES CO-EL-SST-FT-44)
  Future<Uint8List> _generarPdfBytes(Map<String, dynamic> datos, String? base64Firma) async {
    final pdf = pw.Document();

    pw.ImageProvider? fAux;
    if (base64Firma != null && base64Firma != 'SIN_FIRMA' && base64Firma.isNotEmpty) {
      try {
        fAux = pw.MemoryImage(base64Decode(base64Firma));
      } catch (_) {}
    }

    pw.ImageProvider? imgLogo;
    try {
      final logoBytes = await rootBundle.load('assets/icon/app_logo.png');
      imgLogo = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {}

    final String estadoFinal = datos['estado']?.toString() ?? 'NO APTO';
    String fechaPdf = datos['fecha']?.toString() ?? '';
    if (fechaPdf.length > 10) fechaPdf = fechaPdf.substring(0, 10);

    String observaciones = datos['observacion'] ?? datos['observaciones']?.toString() ?? 'SIN OBSERVACIONES';
    if (observaciones.trim().isEmpty) observaciones = 'SIN OBSERVACIONES';

    pw.TableRow buildNestedRow(String titulo, List<Map<String, String>> preguntasBloque) {
      return pw.TableRow(
        children: [
          pw.Container(
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.all(5),
            child: pw.Text(titulo, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
          ),
          pw.Table(
            border: pw.TableBorder.symmetric(inside: const pw.BorderSide()),
            columnWidths: {0: const pw.FlexColumnWidth(5), 1: const pw.FlexColumnWidth(1.2)},
            children: preguntasBloque.map((p) {
              final valorResp = datos[p['key']]?.toString() ?? 'N/A';
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

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ENCABEZADO
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {0: const pw.FlexColumnWidth(1.5), 1: const pw.FlexColumnWidth(4), 2: const pw.FlexColumnWidth(2)},
                children: [
                  pw.TableRow(
                    children: [
                      pw.Container(
                        height: 50,
                        alignment: pw.Alignment.center,
                        child: imgLogo != null
                            ? pw.Image(imgLogo, height: 40)
                            : pw.Text('EASY LOGÍSTICA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue800, fontSize: 10)),
                      ),
                      pw.Container(
                        alignment: pw.Alignment.center,
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'SISTEMA DE GESTIÓN DE SEGURIDAD Y SALUD EN EL TRABAJO\nINSPECCIÓN DE HERRAMIENTAS MANUALES',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                        ),
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text('Código: CO-EL-SST-FT-44', style: const pw.TextStyle(fontSize: 7))),
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

              // TABLA DE DATOS GENERALES
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(children: [
                    _buildPdfCell('Turno:', true),
                    _buildPdfCell(datos['turno']?.toString() ?? ''),
                    _buildPdfCell('Área:', true),
                    _buildPdfCell(datos['area']?.toString() ?? 'REPARACIÓN ESTIBAS')
                  ]),
                  pw.TableRow(children: [
                    _buildPdfCell('Fecha:', true),
                    _buildPdfCell(fechaPdf),
                    _buildPdfCell('Auxiliar:', true),
                    _buildPdfCell(datos['auxiliar']?.toString() ?? '')
                  ]),
                  pw.TableRow(children: [
                    _buildPdfCell('Supervisor:', true),
                    _buildPdfCell(datos['supervisor']?.toString() ?? ''),
                    _buildPdfCell('', false),
                    _buildPdfCell('')
                  ]),
                ],
              ),
              pw.SizedBox(height: 10),

              // CHECKLIST DESGLOSADO
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {0: const pw.FlexColumnWidth(1.5), 1: const pw.FlexColumnWidth(6)},
                children: [
                  cabeceraTabla,
                  buildNestedRow('Martillo', _itemsMartillo),
                  buildNestedRow('Estibador Manual', _itemsEstibador),
                  buildNestedRow('Barra de Uña', _itemsBarra),
                ],
              ),
              pw.SizedBox(height: 10),

              // OBSERVACIONES
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

              // FIRMA
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(3), 2: const pw.FlexColumnWidth(3)},
                children: [
                  pw.TableRow(children: [
                    _buildPdfCell('Auxiliar Responsable:', true),
                    _buildPdfCell(datos['auxiliar']?.toString() ?? ''),
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

    return pdf.save();
  }

  // 📧 NOTIFICACIÓN POR CORREO EN CASO DE NO APTO
  Future<void> _enviarCorreoNotificacionNoApto(Map<String, dynamic> datos, String? base64Aux) async {
    try {
      debugPrint('=== 1. CONSULTANDO DESTINATARIOS DE CORREO (HERRAMIENTAS MANUALES) ===');

      Uri urlEmail = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/consultar/${ApiService.schema}/correos_seguridad');
      http.Response resEmail = await http.get(urlEmail, headers: {'Content-Type': 'application/json', 'x-api-key': ApiService.apiKey});

      List items = [];
      if (resEmail.statusCode == 200) {
        final decoded = jsonDecode(resEmail.body);
        // 🛡️ REGLA INTELIGENTE DE LECTURA
        if (decoded is List) {
          items = decoded;
        } else if (decoded is Map<String, dynamic> && decoded['data'] != null) {
          items = decoded['data'] is List ? decoded['data'] : [];
        }
      }

      if (items.isEmpty) {
        urlEmail = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/consultar/${ApiService.schema}/email');
        resEmail = await http.get(urlEmail, headers: {'Content-Type': 'application/json', 'x-api-key': ApiService.apiKey});
        if (resEmail.statusCode == 200) {
          final decoded = jsonDecode(resEmail.body);
          // 🛡️ REGLA INTELIGENTE DE LECTURA
          List fallbackItems = [];
          if (decoded is List) {
            fallbackItems = decoded;
          } else if (decoded is Map<String, dynamic> && decoded['data'] != null) {
            fallbackItems = decoded['data'] is List ? decoded['data'] : [];
          }
          items = fallbackItems.where((e) => (e['estado'] ?? '').toString().toUpperCase() == 'ACTIVO').toList();
        }
      }

      List<String> correos = items
          .map((e) => (e['correos'] ?? e['correo'] ?? '').toString().trim())
          .where((c) => c.isNotEmpty && c != 'null')
          .toList();

      if (correos.isEmpty) {
        debugPrint('❌ No se encontraron correos destinatarios.');
        return;
      }

      String destinatarios = correos.join(', ');
      debugPrint('📧 Destinatarios: $destinatarios');

      // Generar PDF ligero en memoria RAM
      final Uint8List pdfBytes = await _generarPdfBytes(datos, base64Aux);
      final String pdfBase64 = base64Encode(pdfBytes);

      String htmlString = '''
      <!DOCTYPE html>
      <html>
      <head><meta charset="utf-8"></head>
      <body style="font-family: 'Segoe UI', Arial, sans-serif; background-color: #f8fafc; margin: 0; padding: 20px;">
        <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 15px rgba(0, 0, 0, 0.08); border: 1px solid #e2e8f0;">
          <div style="background-color: #DC2626; padding: 20px; text-align: center;">
            <span style="display: inline-block; background-color: #ffffff; color: #DC2626; font-size: 11px; font-weight: bold; letter-spacing: 1px; padding: 4px 12px; border-radius: 12px; text-transform: uppercase; margin-bottom: 8px;">
              🚨 ALERTA DE SEGURIDAD
            </span>
            <h1 style="color: #ffffff; margin: 0; font-size: 20px; font-weight: 700;">
              PREOPERACIONAL H. MANUALES: NO APTO
            </h1>
          </div>
          <div style="padding: 24px;">
            <p style="color: #475569; font-size: 14px; margin-top: 0; line-height: 1.5;">
              Se ha registrado un preoperacional de herramientas manuales (Martillo / Estibador / Barra) clasificado como <b>NO APTO</b>.
            </p>

            <table style="width: 100%; border-collapse: separate; border-spacing: 0; background-color: #f1f5f9; border-radius: 8px; font-size: 13px;">
              <tr><td style="padding: 10px 14px; color: #64748b; font-weight: 600; width: 35%; border-bottom: 1px solid #e2e8f0;">Fecha:</td><td style="padding: 10px 14px; color: #1e293b; font-weight: 700; border-bottom: 1px solid #e2e8f0;">${datos['fecha']}</td></tr>
              <tr><td style="padding: 10px 14px; color: #64748b; font-weight: 600; border-bottom: 1px solid #e2e8f0;">Auxiliar:</td><td style="padding: 10px 14px; color: #1e293b; font-weight: 700; border-bottom: 1px solid #e2e8f0;">${datos['auxiliar']}</td></tr>
              <tr><td style="padding: 10px 14px; color: #64748b; font-weight: 600; border-bottom: 1px solid #e2e8f0;">Supervisor:</td><td style="padding: 10px 14px; color: #1e293b; font-weight: 700; border-bottom: 1px solid #e2e8f0;">${datos['supervisor']}</td></tr>
              <tr><td style="padding: 10px 14px; color: #64748b; font-weight: 600;">Turno:</td><td style="padding: 10px 14px; color: #1e293b; font-weight: 700;">${datos['turno']}</td></tr>
            </table>

            <div style="margin-top: 18px;">
              <span style="font-size: 12px; font-weight: 700; color: #64748b; text-transform: uppercase;">Observaciones:</span>
              <div style="background-color: #fef2f2; border-left: 4px solid #ef4444; padding: 10px 14px; border-radius: 0 6px 6px 0; color: #991b1b; font-size: 13px; margin-top: 4px;">
                "${datos['observacion']}"
              </div>
            </div>

            <p style="color: #64748b; font-size: 12px; margin-top: 20px; line-height: 1.4;">
              📎 Se adjunta el informe PDF oficial con el desglose técnico detallado.
            </p>
          </div>
          <div style="background-color: #f8fafc; padding: 12px; text-align: center; border-top: 1px solid #e2e8f0; font-size: 11px; color: #94a3b8;">
            Módulo de Seguridad SST • Notificación Automática
          </div>
        </div>
      </body>
      </html>
      ''';

      await ApiService.enviarCorreo(
        esquemaCredenciales: 'administrador_principal',
        tablaCredenciales: 'smtp',
        para: destinatarios,
        asunto: '[ALERTA SST] Preoperacional NO APTO - Herramientas Manuales: ${datos['auxiliar']}',
        html: htmlString,
        adjuntoBase64: pdfBase64,
      );

      debugPrint('✅ Correo con PDF oficial enviado exitosamente.');
    } catch (e) {
      debugPrint('❌ Error notificando correo: $e');
    }
  }

  Future<void> _guardarPreoperacional() async {
    int totalPreguntas = _itemsMartillo.length + _itemsEstibador.length + _itemsBarra.length;

    if (!_formKey.currentState!.validate()) {
      _mostrarAlerta('Revisa los campos requeridos.', Colors.red.shade700);
      return;
    }
    if (_respuestas.length < totalPreguntas) {
      _mostrarAlerta('Debes responder todas las preguntas de inspección.', Colors.orange.shade800);
      return;
    }
    if (_firmaAuxiliar.isEmpty) {
      _mostrarAlerta('La firma del auxiliar es obligatoria.', Colors.red.shade700);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final base64Aux = await _convertirFirmaABase64(_firmaAuxiliar);

      bool tieneNoCumple = _respuestas.values.any((val) => val.toString().trim().toLowerCase() == 'no cumple');
      String estadoCalculado = tieneNoCumple ? 'NO APTO' : 'APTO';

      final nombreAuxiliar = (widget.datosEmpleado['nombre'] ?? widget.datosEmpleado['Nombre'] ?? widget.datosEmpleado['usuario'] ?? 'OPERADOR').toString();

      final Map<String, dynamic> datosBase = {
        'id': DateTime.now().millisecondsSinceEpoch % 2147483647,
        'fecha': _fechaController.text,
        'auxiliar': nombreAuxiliar,
        'supervisor': _supervisorController.text.trim(),
        'turno': _turnoSeleccionado ?? 'T1',
        'observacion': _observacionController.text.trim().isEmpty ? 'SIN OBSERVACIONES' : _observacionController.text.trim(),
        'firma': base64Aux ?? 'SIN_FIRMA',
        'estado': estadoCalculado,
        'evidencia': 'SIN_EVIDENCIA',
      };

      // Inyectar respuestas de ítems
      _respuestas.forEach((key, value) => datosBase[key] = value);

      final urlInsert = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/insertar/${ApiService.schema}/estibas_herramientas_manuales');

      final response = await http.post(
        urlInsert,
        headers: {'Content-Type': 'application/json', 'x-api-key': ApiService.apiKey},
        body: jsonEncode(datosBase),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        String detalleError = 'Error ${response.statusCode}: ${response.body}';
        try {
          final errJson = jsonDecode(response.body);
          if (errJson['message'] != null) detalleError = errJson['message'].toString();
          else if (errJson['error'] != null) detalleError = errJson['error'].toString();
        } catch (_) {}
        throw Exception(detalleError);
      }

      if (tieneNoCumple) {
        await _enviarCorreoNotificacionNoApto(datosBase, base64Aux);
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                tieneNoCumple ? Icons.warning_amber_rounded : Icons.check_circle,
                color: tieneNoCumple ? Colors.orange.shade800 : Colors.green,
                size: 60,
              ),
              const SizedBox(height: 20),
              const Text('¡Inspección Registrada!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(
                'Estado: $estadoCalculado',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: tieneNoCumple ? Colors.red.shade700 : Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (tieneNoCumple) ...[
                const SizedBox(height: 8),
                const Text('Se ha enviado reporte PDF a Seguridad SST.', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w500)),
              ],
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  child: const Text('Aceptar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );

      _limpiarFormulario();
    } catch (e) {
      _mostrarAlerta('$e', Colors.red.shade700);
      setState(() => _isLoading = false);
    }
  }

  void _limpiarFormulario() {
    setState(() {
      _respuestas.clear();
      _firmaAuxiliar.clear();
      _observacionController.clear();
      _turnoSeleccionado = null;
    });
  }

  void _mostrarAlerta(String mensaje, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombreEmpleado = (widget.datosEmpleado['nombre'] ?? widget.datosEmpleado['Nombre'] ?? widget.datosEmpleado['usuario'] ?? 'OPERADOR').toString().toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFE8ECEF),
      appBar: AppBar(
        title: const Text('Preoperacional Herramientas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        centerTitle: true,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 15, offset: const Offset(0, -5))]),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: SizedBox(
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.cloud_upload_rounded),
                label: Text(_isLoading ? 'PROCESANDO...' : 'GUARDAR INSPECCIÓN', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5)),
                onPressed: _isLoading ? null : _guardarPreoperacional,
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(15),
                      color: Colors.blue.shade50,
                      child: Row(children: [Icon(Icons.assignment_ind, color: Colors.blue.shade800), const SizedBox(width: 10), Text('Información General', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue.shade900))]),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(children: [
                            Expanded(child: TextFormField(controller: _fechaController, readOnly: true, onTap: () => _seleccionarFecha(context), decoration: InputDecoration(labelText: 'Fecha', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: Colors.grey.shade50, suffixIcon: const Icon(Icons.calendar_month, size: 20)))),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _turnoSeleccionado,
                                decoration: InputDecoration(labelText: 'Turno', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: Colors.grey.shade50),
                                items: _opcionesTurno.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)))).toList(),
                                onChanged: (val) => setState(() => _turnoSeleccionado = val),
                                validator: (v) => v == null ? 'Requerido' : null,
                              ),
                            ),
                          ]),
                          const SizedBox(height: 15),
                          TextFormField(initialValue: nombreEmpleado, readOnly: true, decoration: InputDecoration(labelText: 'Auxiliar', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: Colors.grey.shade100)),
                          const SizedBox(height: 15),
                          _crearAutocomplete(_supervisorController, 'Supervisor', _listaSupervisores),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(backgroundColor: Colors.green.shade50, side: BorderSide(color: Colors.green.shade600), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                onPressed: _marcarTodoCumple,
                icon: const Icon(Icons.done_all, color: Colors.green),
                label: const Text('Marcar Todo como Cumple', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 15),

              _buildHerramientaCard(titulo: 'Martillo', colorFondo: Colors.orange.shade50, colorTexto: Colors.orange.shade900, icono: Icons.gavel_rounded, items: _itemsMartillo),
              const SizedBox(height: 20),

              _buildHerramientaCard(titulo: 'Estibador Manual', colorFondo: Colors.purple.shade50, colorTexto: Colors.purple.shade900, icono: Icons.local_shipping_rounded, items: _itemsEstibador),
              const SizedBox(height: 20),

              _buildHerramientaCard(titulo: 'Barra de Uña', colorFondo: Colors.teal.shade50, colorTexto: Colors.teal.shade900, icono: Icons.architecture_rounded, items: _itemsBarra),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Observaciones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _observacionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Detalle cualquier novedad observada...',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(15),
                      color: Colors.green.shade50,
                      child: Row(children: [Icon(Icons.draw, color: Colors.green.shade800), const SizedBox(width: 10), Text('Firma Digital', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green.shade900))]),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: _CajaFirma(titulo: 'Firma Auxiliar', controlador: _firmaAuxiliar),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHerramientaCard({required String titulo, required Color colorFondo, required Color colorTexto, required IconData icono, required List<Map<String, String>> items}) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            color: colorFondo,
            child: Row(children: [Icon(icono, color: colorTexto), const SizedBox(width: 10), Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: colorTexto))]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: items.map((p) {
                final valor = _respuestas[p['key']];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p['label']!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Color(0xFF37474F))),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            _BotonCheck(titulo: 'Cumple', colorActivo: Colors.green, activo: valor == 'Cumple', onTap: () => setState(() => _respuestas[p['key']!] = 'Cumple')),
                            _BotonCheck(titulo: 'No Cumple', colorActivo: Colors.red, activo: valor == 'No Cumple', onTap: () => setState(() => _respuestas[p['key']!] = 'No Cumple')),
                            _BotonCheck(titulo: 'N/A', colorActivo: Colors.blueGrey, activo: valor == 'N/A', onTap: () => setState(() => _respuestas[p['key']!] = 'N/A')),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _crearAutocomplete(TextEditingController ctrl, String label, List<String> lista) {
    return Autocomplete<String>(
      optionsBuilder: (text) => text.text.isEmpty ? lista : lista.where((o) => o.toLowerCase().contains(text.text.toLowerCase())),
      onSelected: (selection) { ctrl.text = selection; FocusScope.of(context).unfocus(); },
      fieldViewBuilder: (ctx, fieldCtrl, focus, onEdit) {
        if (fieldCtrl.text != ctrl.text && !focus.hasFocus) fieldCtrl.text = ctrl.text;
        fieldCtrl.addListener(() => ctrl.text = fieldCtrl.text);
        return TextFormField(
          controller: fieldCtrl,
          focusNode: focus,
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: Colors.white,
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          validator: (v) => v!.isEmpty ? 'Requerido' : null,
        );
      },
    );
  }

  @override
  void dispose() {
    _fechaController.dispose();
    _supervisorController.dispose();
    _observacionController.dispose();
    _firmaAuxiliar.dispose();
    super.dispose();
  }
}

class _BotonCheck extends StatelessWidget {
  final String titulo; final Color colorActivo; final bool activo; final VoidCallback onTap;
  const _BotonCheck({required this.titulo, required this.colorActivo, required this.activo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: activo ? colorActivo : Colors.transparent, borderRadius: BorderRadius.circular(30)),
          alignment: Alignment.center,
          child: Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, color: activo ? Colors.white : Colors.grey.shade600, fontSize: 11)),
        ),
      ),
    );
  }
}

class _CajaFirma extends StatelessWidget {
  final String titulo; final SignatureController controlador;
  const _CajaFirma({required this.titulo, required this.controlador});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.blue.shade100, width: 2)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800, fontSize: 12)),
                InkWell(
                  onTap: () => controlador.clear(),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                    child: Icon(Icons.delete_outline, color: Colors.red.shade700, size: 15),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 0, thickness: 1),
          ClipRRect(
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
            child: Signature(controller: controlador, height: 110, backgroundColor: const Color(0xFFF9FBFF)),
          ),
        ],
      ),
    );
  }
}