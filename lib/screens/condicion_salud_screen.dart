import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../services/api_service.dart';

class CondicionSaludScreen extends StatefulWidget {
  final Map<String, dynamic> datosEmpleado;
  const CondicionSaludScreen({super.key, required this.datosEmpleado});

  @override
  State<CondicionSaludScreen> createState() => _CondicionSaludScreenState();
}

class _CondicionSaludScreenState extends State<CondicionSaludScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // 🇨🇴 FECHA EN HORA COLOMBIA (UTC-5)
  final _fechaController = TextEditingController(
    text: DateTime.now().toUtc().subtract(const Duration(hours: 5)).toString().substring(0, 10),
  );
  final _observacionController = TextEditingController();
  String? _turnoSeleccionado;

  final List<String> _opcionesTurno = ['T1 (6:00AM-2:00PM)', 'T2 (2:00PM-10:00PM)', 'T3 (10:00PM-6:00AM)'];

  final Map<String, String> _respuestas = {};

  final List<Map<String, String>> _preguntas = [
    {'key': 'medicamento_somnolencia', 'label': '1. ¿Se encuentra libre de medicamentos que generen somnolencia?'},
    {'key': 'sintomas_enfermedad', 'label': '2. ¿Se encuentra sin signos o síntomas de enfermedad en los últimos días?'},
    {'key': 'trastorno_sueno', 'label': '3. ¿Cuenta con un descanso adecuado (ha dormido 6 horas o más)?'},
    {'key': 'incapaz_realizar_labor', 'label': '4. ¿Se siente en condiciones físicas y mentales para realizar la labor según el procedimiento?'},
    {'key': 'incidente_salud_anterior', 'label': '5. ¿Se encuentra apto de salud sin antecedentes recientes que afecten esta actividad?'},
    {'key': 'alcohol_psicoactivos_12h', 'label': '6. ¿Se encuentra libre de consumo de alcohol o sustancias psicoactivas en las últimas 12 horas?'},
    {'key': 'mas_4h_sin_alimento', 'label': '7. ¿Ha consumido alimentos en las últimas 4 horas?'},
    {'key': 'sueno_6h_antes_turno', 'label': '8. ¿Ha tenido un tiempo de sueño adecuado (mínimo 6 horas) antes de iniciar el turno?'}
  ];

  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? seleccionado = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_fechaController.text) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (seleccionado != null) {
      setState(() {
        _fechaController.text = seleccionado.toString().substring(0, 10);
      });
    }
  }

  void _marcarTodo(String valor) {
    setState(() {
      for (var p in _preguntas) {
        _respuestas[p['key']!] = valor;
      }
    });
  }

  // 📄 GENERACIÓN DEL PDF Y ENVÍO DE ALERTA POR CORREO
  Future<void> _enviarCorreoAlertaPdf(Map<String, dynamic> datos) async {
    try {
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
          List backupItems = [];
          if (decoded is List) {
            backupItems = decoded;
          } else if (decoded is Map<String, dynamic> && decoded['data'] != null) {
            backupItems = decoded['data'] is List ? decoded['data'] : [];
          }
          items = backupItems.where((e) => (e['estado'] ?? '').toString().toUpperCase() == 'ACTIVO').toList();
        }
      }

      List<String> correos = items
          .map((e) => (e['correos'] ?? e['correo'] ?? '').toString().trim())
          .where((c) => c.isNotEmpty && c != 'null')
          .toList();

      if (correos.isEmpty) return;

      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                    padding: const pw.EdgeInsets.all(20),
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.red900,
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    width: double.infinity,
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('NOTIFICACIÓN DE RIESGO DE SALUD', style: pw.TextStyle(color: PdfColors.white, fontSize: 16, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
                          pw.SizedBox(height: 4),
                          pw.Text('Sistema HSEQ - Reparación de Estibas', style: pw.TextStyle(color: PdfColors.white, fontSize: 11, fontStyle: pw.FontStyle.italic)),
                        ]
                    )
                ),
                pw.SizedBox(height: 25),

                pw.Text('1. DATOS GENERALES DEL TURNO', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
                pw.Divider(color: PdfColors.grey400, thickness: 1),
                pw.SizedBox(height: 8),
                pw.Row(
                    children: [
                      pw.Expanded(child: pw.Text('Colaborador:\n${datos['nombre']}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
                      pw.Expanded(child: pw.Text('Fecha:\n${datos['fecha']}', style: pw.TextStyle(fontSize: 11))),
                    ]
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                    children: [
                      pw.Expanded(child: pw.Text('Turno:\n${datos['turno']}', style: pw.TextStyle(fontSize: 11))),
                      pw.Expanded(child: pw.Text('Área:\n${datos['area']}', style: pw.TextStyle(fontSize: 11))),
                    ]
                ),
                pw.SizedBox(height: 30),

                pw.Text('2. EVALUACIÓN PRE-OPERACIONAL DE SALUD', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
                pw.SizedBox(height: 10),

                pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(5),
                      1: const pw.FlexColumnWidth(1.5),
                    },
                    children: [
                      pw.TableRow(
                          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Criterio Médico Evaluado', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11))),
                            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Estado', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11), textAlign: pw.TextAlign.center)),
                          ]
                      ),
                      ..._preguntas.map((p) {
                        final String colKey = p['key'] == 'incapaz_realizar_labor' ? 'incapaz_realizar_trabajo' : p['key']!;
                        final resp = datos[colKey].toString();
                        final bool esMalo = resp == 'MALO';
                        return pw.TableRow(
                            children: [
                              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(p['label']!, style: pw.TextStyle(fontSize: 10))),
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(8),
                                  child: pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: pw.BoxDecoration(
                                        color: esMalo ? PdfColors.red100 : PdfColors.green100,
                                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))
                                    ),
                                    child: pw.Text(
                                        resp,
                                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: esMalo ? PdfColors.red900 : PdfColors.green900),
                                        textAlign: pw.TextAlign.center
                                    ),
                                  )
                              ),
                            ]
                        );
                      }).toList(),
                    ]
                ),
                pw.SizedBox(height: 30),

                pw.Text('3. DETALLE DE OBSERVACIONES Y NOVEDADES', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
                pw.Divider(color: PdfColors.grey400, thickness: 1),
                pw.SizedBox(height: 8),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                      color: PdfColors.red50,
                      border: pw.Border.all(color: PdfColors.red200),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))
                  ),
                  child: pw.Text(datos['observacion'].toString(), style: pw.TextStyle(fontSize: 11, color: PdfColors.red900, fontWeight: pw.FontWeight.bold)),
                ),
              ],
            );
          },
        ),
      );

      final Uint8List pdfBytes = await pdf.save();
      final String pdfBase64 = base64Encode(pdfBytes);

      String htmlString = '''
      <!DOCTYPE html>
      <html>
      <head><meta charset="utf-8"></head>
      <body style="font-family: Arial, sans-serif; background-color: #f8fafc; margin: 0; padding: 20px;">
        <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; border: 1px solid #e2e8f0;">
          <div style="background-color: #DC2626; padding: 20px; text-align: center;">
            <h1 style="color: #ffffff; margin: 0; font-size: 18px;">⚠️ ALERTA CRÍTICA DE SALUD PRE-TURNO</h1>
          </div>
          <div style="padding: 24px;">
            <p>Se ha detectado un registro <b>NO APTO</b> en la encuesta de condición de salud del colaborador <b>${datos['nombre']}</b>.</p>
            <p>Se adjunta el reporte oficial en formato PDF con el desglose técnico.</p>
          </div>
        </div>
      </body>
      </html>
      ''';

      await ApiService.enviarCorreo(
        esquemaCredenciales: 'administrador_principal',
        tablaCredenciales: 'smtp',
        para: correos.join(', '),
        asunto: '🚨 ALERTA CRÍTICA: Condición de Salud - ${datos['nombre']}',
        html: htmlString,
        adjuntoBase64: pdfBase64,
      );
    } catch (e) {
      debugPrint('Error enviando correo de salud: $e');
    }
  }

  Future<void> _enviarEncuesta() async {
    if (!_formKey.currentState!.validate()) {
      _mostrarAlerta('Por favor completa todos los campos requeridos.');
      return;
    }

    if (_respuestas.length < _preguntas.length) {
      _mostrarAlerta('Debes responder las ${_preguntas.length} preguntas antes de guardar.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final nombreEmpleado = (widget.datosEmpleado['nombre'] ??
          widget.datosEmpleado['Nombre'] ??
          widget.datosEmpleado['usuario'] ??
          'OPERADOR')
          .toString()
          .toUpperCase();

      final Map<String, dynamic> datosInsertar = {
        'fecha': _fechaController.text,
        'nombre': nombreEmpleado,
        'turno': _turnoSeleccionado ?? 'T1',
        'area': 'REPARACION DE ESTIBAS',
        'medicamento_somnolencia': _respuestas['medicamento_somnolencia'] ?? 'BUENO',
        'sintomas_enfermedad': _respuestas['sintomas_enfermedad'] ?? 'BUENO',
        'trastorno_sueno': _respuestas['trastorno_sueno'] ?? 'BUENO',
        'incapaz_realizar_trabajo': _respuestas['incapaz_realizar_labor'] ?? 'BUENO',
        'incidente_salud_anterior': _respuestas['incidente_salud_anterior'] ?? 'BUENO',
        'alcohol_psicoactivos_12h': _respuestas['alcohol_psicoactivos_12h'] ?? 'BUENO',
        'mas_4h_sin_alimento': _respuestas['mas_4h_sin_alimento'] ?? 'BUENO',
        'sueno_6h_antes_turno': _respuestas['sueno_6h_antes_turno'] ?? 'BUENO',
        'observacion': _observacionController.text.trim().isEmpty ? 'VACÍO' : _observacionController.text.trim(),
      };

      final urlInsert = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/insertar/gestion/condicion_de_salud');
      final response = await http.post(
        urlInsert,
        headers: {'Content-Type': 'application/json', 'x-api-key': ApiService.apiKey},
        body: jsonEncode(datosInsertar),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }

      bool tieneMalo = _respuestas.values.contains('MALO');
      if (tieneMalo) {
        await _enviarCorreoAlertaPdf(datosInsertar);
      }

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.medical_information, color: Colors.green, size: 60),
              const SizedBox(height: 20),
              const Text('¡Encuesta Guardada!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text('Tus condiciones de salud se registraron con éxito.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  child: const Text('Aceptar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error guardando salud: $e');
      _mostrarAlerta('Error al guardar en la base de datos: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarAlerta(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombreEmpleado = (widget.datosEmpleado['nombre'] ??
        widget.datosEmpleado['Nombre'] ??
        widget.datosEmpleado['usuario'] ??
        'OPERADOR')
        .toString()
        .toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text('Condición de Salud', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange.shade300),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(Icons.health_and_safety, color: Colors.orange.shade800, size: 30),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        'Esta encuesta es obligatoria para garantizar tu bienestar y seguridad antes de iniciar la operación.',
                        style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.w600, fontSize: 12.5),
                      ),
                    )
                  ],
                ),
              ),

              // ENCABEZADO
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100, width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6)]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.assignment_ind, color: Color(0xFF0D47A1), size: 20),
                      SizedBox(width: 8),
                      Text('Información General', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)))
                    ]),
                    const Divider(height: 25),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Fecha', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                              const SizedBox(height: 5),
                              TextFormField(
                                controller: _fechaController,
                                readOnly: true,
                                onTap: () => _seleccionarFecha(context),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  filled: true,
                                  fillColor: Colors.white,
                                  suffixIcon: const Icon(Icons.calendar_month, size: 16, color: Colors.grey),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _turnoSeleccionado,
                            decoration: InputDecoration(
                                labelText: 'Turno', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: Colors.white),
                            items: _opcionesTurno.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 11)))).toList(),
                            onChanged: (val) => setState(() => _turnoSeleccionado = val),
                            validator: (val) => val == null ? 'Requerido' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    _CampoEstatico(label: 'Colaborador', valor: nombreEmpleado),
                    const SizedBox(height: 15),
                    const _CampoEstatico(label: 'Área', valor: 'REPARACION DE ESTIBAS'),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // CUESTIONARIO MÉDICO
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6)]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Cuestionario Médico', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF263238))),
                        TextButton.icon(
                          style: TextButton.styleFrom(foregroundColor: Colors.green),
                          icon: const Icon(Icons.done_all, size: 18),
                          label: const Text('Todo Bueno', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () => _marcarTodo('BUENO'),
                        )
                      ],
                    ),
                    const Divider(height: 20),
                    ..._preguntas.map((p) {
                      final key = p['key']!;
                      final valor = _respuestas[key];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p['label']!, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF37474F), height: 1.3)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setState(() => _respuestas[key] = 'BUENO'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: valor == 'BUENO' ? Colors.green.shade50 : Colors.white,
                                        border: Border.all(color: valor == 'BUENO' ? Colors.green : Colors.grey.shade300, width: 1.5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                          child: Text('BUENO',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: valor == 'BUENO' ? Colors.green.shade700 : Colors.grey))),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setState(() => _respuestas[key] = 'MALO'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: valor == 'MALO' ? Colors.red.shade50 : Colors.white,
                                        border: Border.all(color: valor == 'MALO' ? Colors.red : Colors.grey.shade300, width: 1.5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                          child: Text('MALO',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: valor == 'MALO' ? Colors.red.shade700 : Colors.grey))),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // OBSERVACIÓN
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6)]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Observaciones', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF263238))),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _observacionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Obligatorio si marcaste "MALO" en alguna pregunta...',
                        hintStyle: const TextStyle(fontSize: 13),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: const Color(0xFFF8F9FA),
                      ),
                      validator: (value) {
                        bool tieneMalo = _respuestas.values.contains('MALO');
                        if (tieneMalo && (value == null || value.trim().isEmpty)) {
                          return 'La observación es estrictamente obligatoria si hay anomalías.';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                  ),
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('ENVIAR ENCUESTA DE SALUD', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  onPressed: _enviarEncuesta,
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fechaController.dispose();
    _observacionController.dispose();
    super.dispose();
  }
}

class _CampoEstatico extends StatelessWidget {
  final String label;
  final String valor;
  const _CampoEstatico({required this.label, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 5),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(color: Colors.grey.shade100, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
          child: Text(valor, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF37474F), fontSize: 13), overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}