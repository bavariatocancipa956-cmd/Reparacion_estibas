import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // ⚙️ SERVIDOR PRINCIPAL Y LLAVE DE SEGURIDAD
  static const String baseUrl = 'https://plantatocancipa.site/api/v1';
  static const String apiKey = 'PlantaLogistica2026*';

  // 🗄️ PARÁMETROS DINÁMICOS POR APK
  static const String database = 'db_logistica';
  static const String schema = 'estibas';
  static const String table = 'reparacion_estibas';

  // 🎯 RUTAS EXACTAS SEGÚN TU SERVER.JS
  static String get _endpointConsultar  => '$baseUrl/$database/consultar/$schema/$table';
  static String get _endpointInsertar   => '$baseUrl/$database/insertar/$schema/$table';
  static String get _endpointActualizar => '$baseUrl/$database/actualizar/$schema/$table';
  static String get _endpointBorrar     => '$baseUrl/$database/borrar/$schema/$table';

  // 🔒 HEADERS DE AUTENTICACIÓN
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'x-api-key': apiKey,
  };

  // 🧹 FUNCIÓN PARA LIMPIAR NÚMEROS Y GUIONES DE LOS NOMBRES
  static String _limpiarTexto(String texto) {
    return texto.replaceAll(RegExp(r'[0-9\-]'), '').trim();
  }

  // 📧 FUNCIÓN PARA ENVIAR CORREOS MEDIANTE LA API (SOPORTA ADJUNTO INDIVIDUAL Y LISTA DE ADJUNTOS)
  static Future<void> enviarCorreo({
    required String esquemaCredenciales,
    required String tablaCredenciales,
    required String para,
    required String asunto,
    String? mensaje,
    String? html,
    String? adjuntoBase64,
    List<dynamic>? adjuntos,
  }) async {
    final url = Uri.parse('$baseUrl/$database/$esquemaCredenciales/$tablaCredenciales/enviar');

    final Map<String, dynamic> bodyPayload = {
      'para': para,
      'asunto': asunto,
    };

    if (mensaje != null) bodyPayload['mensaje'] = mensaje;
    if (html != null) bodyPayload['html'] = html;
    if (adjuntoBase64 != null) bodyPayload['adjuntoBase64'] = adjuntoBase64;
    if (adjuntos != null) bodyPayload['adjuntos'] = adjuntos;

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
        },
        body: jsonEncode(bodyPayload),
      );

      debugPrint('=== RESPUESTA SERVIDOR CORREO === [Código: ${response.statusCode}]');

      if (response.statusCode != 200 && response.statusCode != 201) {
        debugPrint('❌ Error en servidor de correo: ${response.body}');
        throw Exception('Fallo al enviar correo (${response.statusCode})');
      } else {
        debugPrint('✅ Correo enviado correctamente.');
      }
    } catch (e) {
      debugPrint('❌ Excepción al enviar correo: $e');
      rethrow;
    }
  }

  // ==========================================
  // 1️⃣ SUBIR FOTOGRAFÍA AL SERVIDOR WEB
  // ==========================================
  static Future<String?> subirFoto(File foto) async {
    final url = Uri.parse('$baseUrl/archivos/subir');
    try {
      final request = http.MultipartRequest('POST', url);
      request.headers['x-api-key'] = apiKey;
      request.files.add(await http.MultipartFile.fromPath('archivo', foto.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['exito'] == true && data['urls'] != null) {
          return data['urls']['archivo'];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ==========================================
  // 2️⃣ OBTENER (GET) REGISTROS
  // ==========================================
  static Future<List<dynamic>> obtenerRegistros() async {
    final url = Uri.parse(_endpointConsultar);
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['exito'] == true && data['data'] != null) {
          return data['data'];
        }
        if (data is List) return data;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<dynamic>> obtenerProductividad() => obtenerRegistros();

  // ==========================================
  // 3️⃣ GUARDAR (POST) REGISTRO
  // ==========================================
  static Future<bool> guardarRegistro(Map<String, dynamic> datos) async {
    final url = Uri.parse(_endpointInsertar);
    final datosLimpios = Map<String, dynamic>.from(datos)..removeWhere((key, value) => value == null);

    try {
      final response = await http.post(url, headers: _headers, body: jsonEncode(datosLimpios));
      if (response.statusCode == 200 || response.statusCode == 201) {
        final resJson = jsonDecode(response.body);
        return resJson['exito'] == true || resJson['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> guardarProductividad(Map<String, dynamic> datos) => guardarRegistro(datos);

  // ==========================================
  // 4️⃣ ACTUALIZAR (PUT) REGISTRO
  // ==========================================
  static Future<bool> actualizarRegistro(dynamic id, Map<String, dynamic> datos) async {
    final url = Uri.parse('$_endpointActualizar/$id');
    try {
      final response = await http.put(url, headers: _headers, body: jsonEncode(datos));
      if (response.statusCode == 200) {
        final resJson = jsonDecode(response.body);
        return resJson['exito'] == true || resJson['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> actualizarProductividad(dynamic id, Map<String, dynamic> datos) => actualizarRegistro(id, datos);

  // ==========================================
  // 5️⃣ ELIMINAR (DELETE) REGISTRO
  // ==========================================
  static Future<bool> eliminarRegistro(dynamic id) async {
    final url = Uri.parse('$_endpointBorrar/$id');
    try {
      final response = await http.delete(url, headers: _headers);
      if (response.statusCode == 200) {
        final resJson = jsonDecode(response.body);
        return resJson['exito'] == true || resJson['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> eliminarProductividad(dynamic id) => eliminarRegistro(id);

  // ==========================================
  // 6️⃣ OBTENER OPERARIOS (estibas -> estibas_usaurios -> nombre)
  // ==========================================
  static Future<List<String>> obtenerOperarios() async {
    final url = Uri.parse('$baseUrl/$database/consultar/estibas/estibas_usaurios');
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List items = data['data'] ?? (data is List ? data : []);
        return items
            .map((e) => _limpiarTexto((e['nombre'] ?? '').toString()))
            .where((n) => n.isNotEmpty)
            .toSet()
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error Operarios: $e');
      return [];
    }
  }

  // ==========================================
  // 7️⃣ OBTENER SUPERVISORES (roturas -> rotura_lista -> supervisor)
  // ==========================================
  static Future<List<String>> obtenerSupervisores() async {
    final url = Uri.parse('$baseUrl/$database/consultar/roturas/rotura_lista');
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List items = data['data'] ?? (data is List ? data : []);
        return items
            .map((e) => _limpiarTexto((e['supervisor'] ?? '').toString()))
            .where((n) => n.isNotEmpty && n != 'NO APLICA')
            .toSet()
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ==========================================
  // 8️⃣ OBTENER OPM (roturas -> rotura_lista -> personal)
  // ==========================================
  static Future<List<String>> obtenerOpm() async {
    final url = Uri.parse('$baseUrl/$database/consultar/roturas/rotura_lista');
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List items = data['data'] ?? (data is List ? data : []);
        return items
            .map((e) => _limpiarTexto((e['personal'] ?? '').toString()))
            .where((n) => n.isNotEmpty)
            .toSet()
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error OPM: $e');
      return [];
    }
  }
}