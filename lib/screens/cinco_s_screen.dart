import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';

class CincoSScreen extends StatefulWidget {
  final Map<String, dynamic> datosEmpleado;
  const CincoSScreen({super.key, required this.datosEmpleado});

  @override
  State<CincoSScreen> createState() => _CincoSScreenState();
}

class _CincoSScreenState extends State<CincoSScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _subiendoEvidencia = false;
  List<String> _listaSupervisores = [];

  final _fechaController = TextEditingController(text: DateTime.now().toUtc().subtract(const Duration(hours: 5)).toString().substring(0, 10));
  final _areaController = TextEditingController(text: 'REPARACIÓN DE ESTIBAS');
  final _supervisorController = TextEditingController();
  final _observacionesController = TextEditingController();

  String? _turnoSeleccionado;
  String? _evidenciaUrl;

  final List<String> _opcionesTurno = ['T1', 'T2', 'T3'];

  final List<Map<String, String>> _criterios5S = [
    {'key': 'tablero_actualizado', 'num': '1', 'label': 'Tablero actualizado.'},
    {'key': 'areas_libres_obstaculos', 'num': '2', 'label': 'Las áreas están libres de elementos innecesarios que interfieran con el tráfico normal.'},
    {'key': 'sin_equipos_danados', 'num': '3', 'label': 'No existen equipos dañados (por ejemplo: herramientas, EPP, etc.).'},
    {'key': 'items_delimitados_bloqueados', 'num': '4', 'label': 'En caso de existir ítems innecesarios, estos están delimitados y bloqueados apropiadamente.'},
    {'key': 'lugar_elementos_personales', 'num': '5', 'label': 'Existe un lugar definido para los elementos personales (ropa, maletines, EPP, etc.).'},
    {'key': 'sitios_importantes_delimitados', 'num': '6', 'label': 'Los pasos cebra, equipos y otros sitios importantes están claramente delimitados.'},
    {'key': 'contenedores_residuos_estandar', 'num': '7', 'label': 'El área tiene cajas y contenedores adecuadamente estandarizados para poner los desechos y residuos.'},
    {'key': 'cumple_estandar_layout', 'num': '8', 'label': 'El estándar de layout se cumple.'},
    {'key': 'cumple_estandar_limpieza', 'num': '9', 'label': '¿Se cuenta con un estándar de orden y limpieza del sector? ¿Se evidencia cumplimiento del mismo?'},
    {'key': 'layout_duenos_claros', 'num': '10', 'label': 'Existe un layout con dueños claros para cada área.'},
    {'key': 'equipos_rotos_danados', 'num': '11', 'label': '¿Existe algún equipo roto / dañado? Ej.: Puerta, silla, PCs, etc.'},
    {'key': 'dueno_area_divulgado', 'num': '12', 'label': '¿El dueño de cada área está definido y divulgado?'},
  ];

  final Map<String, String> _respuestas = {};

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

  void _marcarTodoBueno() {
    setState(() {
      for (var c in _criterios5S) {
        _respuestas[c['key']!] = 'BUENO';
      }
    });
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

  // 📸 CAPTURA DE FOTO CON COMPRESIÓN ESTRICTA ≤ 30 KB
  Future<void> _tomarFotoEvidencia() async {
    final ImagePicker picker = ImagePicker();
    final XFile? imagen = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 350,
      maxHeight: 350,
      imageQuality: 15,
    );

    if (imagen == null) return;

    final File archivoImagen = File(imagen.path);
    final int pesoBytes = await archivoImagen.length();
    final double pesoKB = pesoBytes / 1024;

    setState(() => _subiendoEvidencia = true);

    try {
      final urlSubida = Uri.parse('${ApiService.baseUrl}/archivos/subir');
      var request = http.MultipartRequest('POST', urlSubida);
      request.headers['x-api-key'] = ApiService.apiKey;
      request.files.add(await http.MultipartFile.fromPath('evidencia_area', archivoImagen.path));

      var responseStream = await request.send();
      var response = await http.Response.fromStream(responseStream);

      String urlFinal = archivoImagen.path;

      if (response.statusCode == 200) {
        final resJson = jsonDecode(response.body);
        if (resJson['exito'] == true && resJson['urls'] != null) {
          urlFinal = resJson['urls']['evidencia_area'] ?? archivoImagen.path;
        }
      }

      setState(() => _evidenciaUrl = urlFinal);

      _mostrarAlerta('Foto capturada (${pesoKB.toStringAsFixed(1)} KB)', Colors.green.shade700);
    } catch (e) {
      _mostrarAlerta('Error subiendo foto de evidencia: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _subiendoEvidencia = false);
    }
  }

  Future<void> _guardarAuditoria5S() async {
    if (!_formKey.currentState!.validate()) {
      _mostrarAlerta('Revisa los campos obligatorios de información general.', Colors.red.shade700);
      return;
    }
    if (_respuestas.length < _criterios5S.length) {
      _mostrarAlerta('Debes evaluar los 12 criterios de la auditoría 5S.', Colors.orange.shade800);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final nombreAuditor = (widget.datosEmpleado['nombre'] ??
          widget.datosEmpleado['Nombre'] ??
          widget.datosEmpleado['usuario'] ??
          'AUDITOR')
          .toString();

      final Map<String, dynamic> payload = {
        'fecha': _fechaController.text.trim(),
        'nombre': nombreAuditor,
        'area': _areaController.text.trim(),
        'supervisor': _supervisorController.text.trim(),
        'turno': _turnoSeleccionado ?? 'T1',
        'observaciones': _observacionesController.text.trim().isEmpty
            ? 'SIN OBSERVACIONES'
            : _observacionesController.text.trim(),
        'evidencia_area': _evidenciaUrl ?? 'SIN_EVIDENCIA',
      };

      // 🔠 INYECCIÓN SIEMPRE EN MAYÚSCULAS ('BUENO' / 'MALO')
      _respuestas.forEach((key, value) {
        payload[key] = value.toUpperCase();
      });

      final urlInsert = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/insertar/gestion/5s_ol');

      final response = await http.post(
        urlInsert,
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': ApiService.apiKey,
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Error ${response.statusCode}: ${response.body}');
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
              const Icon(Icons.check_circle, color: Colors.green, size: 60),
              const SizedBox(height: 20),
              const Text('¡Auditoría Registrada!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text('El reporte 5S ha sido guardado exitosamente en el sistema.', textAlign: TextAlign.center),
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
                    Navigator.pop(context); // Vuelve a la pantalla de validación
                  },
                  child: const Text('Aceptar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      _mostrarAlerta('$e', Colors.red.shade700);
      setState(() => _isLoading = false);
    }
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
  Widget build(BuildContext context) {
    final nombreAuditor = (widget.datosEmpleado['nombre'] ??
        widget.datosEmpleado['Nombre'] ??
        widget.datosEmpleado['usuario'] ??
        'AUDITOR')
        .toString()
        .toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text('Auditoría 5S - Turno a Turno',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        elevation: 0,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: Colors.white, boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -4))
        ]),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_rounded),
                label: Text(_isLoading ? 'GUARDANDO...' : 'GUARDAR AUDITORÍA 5S',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                onPressed: _isLoading ? null : _guardarAuditoria5S,
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
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.assignment_ind_outlined, color: Color(0xFF0D47A1)),
                          const SizedBox(width: 8),
                          Text('Información General',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _fechaController,
                              readOnly: true,
                              onTap: () => _seleccionarFecha(context),
                              decoration: InputDecoration(
                                labelText: 'Fecha',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                suffixIcon: const Icon(Icons.calendar_month, size: 18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _areaController,
                              decoration: InputDecoration(
                                labelText: 'Área',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        initialValue: nombreAuditor,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Auditor Autorizado',
                          isDense: true,
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _turnoSeleccionado,
                              isDense: true,
                              decoration: InputDecoration(
                                labelText: 'Turno',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: _opcionesTurno
                                  .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12))))
                                  .toList(),
                              onChanged: (val) => setState(() => _turnoSeleccionado = val),
                              validator: (v) => v == null ? 'Requerido' : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _crearAutocomplete(_supervisorController, 'Supervisor', _listaSupervisores),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Evaluación de Criterios',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green.shade700,
                              side: BorderSide(color: Colors.green.shade600),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            onPressed: _marcarTodoBueno,
                            icon: const Icon(Icons.done_all, size: 18),
                            label: const Text('Todo Bueno', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          )
                        ],
                      ),
                      const Divider(height: 25),

                      ..._criterios5S.map((item) {
                        final val = _respuestas[item['key']];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item['num']}. ${item['label']}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF37474F)),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _BotonToggleBuenoMalo(
                                      titulo: 'BUENO',
                                      esBueno: true,
                                      activo: val == 'BUENO',
                                      onTap: () => setState(() => _respuestas[item['key']!] = 'BUENO'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _BotonToggleBuenoMalo(
                                      titulo: 'MALO',
                                      esBueno: false,
                                      activo: val == 'MALO',
                                      onTap: () => setState(() => _respuestas[item['key']!] = 'MALO'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Observaciones y Evidencia', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _observacionesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Detalle cualquier observación encontrada...',
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            foregroundColor: const Color(0xFF0D47A1),
                            side: const BorderSide(color: Color(0xFF0D47A1), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _subiendoEvidencia ? null : _tomarFotoEvidencia,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Tomar Foto de Evidencia (Máx. 30 KB)',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      if (_subiendoEvidencia)
                        const Padding(
                          padding: EdgeInsets.only(top: 15),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      if (_evidenciaUrl != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          height: 180,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green, width: 2),
                            image: DecorationImage(
                              image: _evidenciaUrl!.startsWith('http')
                                  ? NetworkImage(_evidenciaUrl!)
                                  : FileImage(File(_evidenciaUrl!)) as ImageProvider,
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                      ]
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fechaController.dispose();
    _areaController.dispose();
    _supervisorController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }
}

class _BotonToggleBuenoMalo extends StatelessWidget {
  final String titulo;
  final bool esBueno;
  final bool activo;
  final VoidCallback onTap;

  const _BotonToggleBuenoMalo({
    required this.titulo,
    required this.esBueno,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorBase = esBueno ? Colors.green : Colors.red;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 44,
        decoration: BoxDecoration(
          color: activo ? colorBase.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: activo ? colorBase.shade700 : Colors.grey.shade300,
            width: activo ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          titulo,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: activo ? colorBase.shade800 : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }
}