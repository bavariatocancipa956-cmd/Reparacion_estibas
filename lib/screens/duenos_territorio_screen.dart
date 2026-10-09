import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';

class DuenosTerritorioScreen extends StatefulWidget {
  final Map<String, dynamic> datosEmpleado;

  const DuenosTerritorioScreen({super.key, required this.datosEmpleado});

  @override
  State<DuenosTerritorioScreen> createState() => _DuenosTerritorioScreenState();
}

class _DuenosTerritorioScreenState extends State<DuenosTerritorioScreen> {
  bool _isLoading = true;
  String? _mensajeError;

  List<Map<String, dynamic>> _allDuenos = [];
  List<Map<String, dynamic>> _duenosFiltrados = [];

  String _filtroTerritorio = 'Todos';
  String _busqueda = '';

  List<String> _listaTerritorios = ['Todos'];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarDuenos();
  }

  // 🚀 CONSULTA DIRECTA A LA TABLA duenos_5s CON REGLA INTELIGENTE
  Future<void> _cargarDuenos() async {
    setState(() {
      _isLoading = true;
      _mensajeError = null;
    });

    try {
      final url = Uri.parse('${ApiService.baseUrl}/${ApiService.database}/consultar/gestion/duenos_5s');
      final res = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'x-api-key': ApiService.apiKey,
      });

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        List<dynamic> data = [];

        // 🛡️ REGLA INTELIGENTE DE LECTURA (Evita el choque fatal)
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map<String, dynamic> && decoded['data'] != null) {
          data = decoded['data'] is List ? decoded['data'] : [];
        }

        _allDuenos = List<Map<String, dynamic>>.from(data);

        final setTerritorios = <String>{'Todos'};
        for (var d in _allDuenos) {
          String terr = (d['territorio'] ?? '').toString().trim();
          if (terr.isNotEmpty) setTerritorios.add(terr);
        }

        _listaTerritorios = setTerritorios.toList()..sort();
        _aplicarFiltros();
      } else {
        _mensajeError = 'Status ${res.statusCode}: ${res.body}';
      }
    } catch (e) {
      _mensajeError = 'Error de conexión: $e';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _aplicarFiltros() {
    setState(() {
      _duenosFiltrados = _allDuenos.where((item) {
        final terr = (item['territorio'] ?? '').toString().toUpperCase();
        final subArea = (item['sub_area'] ?? '').toString().toUpperCase();
        final abi = (item['responsable_abi'] ?? '').toString().toUpperCase();
        final ol = (item['ol'] ?? '').toString().toUpperCase();
        final equipo = (item['equipo'] ?? '').toString().toUpperCase();

        final matchTerritorio = _filtroTerritorio == 'Todos' || terr == _filtroTerritorio.toUpperCase();

        final query = _busqueda.toUpperCase().trim();
        final matchQuery = query.isEmpty ||
            terr.contains(query) ||
            subArea.contains(query) ||
            abi.contains(query) ||
            ol.contains(query) ||
            equipo.contains(query);

        return matchTerritorio && matchQuery;
      }).toList();
    });
  }

  String _formatearUrlDrive(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    String link = url.trim();
    if (link.contains('drive.google.com')) {
      final regex = RegExp(r'id=([a-zA-Z0-9_-]+)');
      final match = regex.firstMatch(link);
      if (match != null) {
        return 'https://drive.google.com/uc?export=view&id=${match.group(1)}';
      }
    }
    return link;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text(
          'Dueños de Territorio 5S',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // CONTENEDOR DE BÚSQUEDA Y FILTROS
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    _busqueda = val;
                    _aplicarFiltros();
                  },
                  decoration: InputDecoration(
                    hintText: 'Buscar por territorio, sub área o nombre...',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF0D47A1)),
                    suffixIcon: _busqueda.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _busqueda = '';
                        _aplicarFiltros();
                      },
                    )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF8F9FA),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.filter_alt_outlined, color: Colors.blueGrey, size: 20),
                    const SizedBox(width: 8),
                    const Text('Territorio:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _filtroTerritorio,
                            isExpanded: true,
                            isDense: true,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                            items: _listaTerritorios.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: (v) {
                              setState(() => _filtroTerritorio = v!);
                              _aplicarFiltros();
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // VISTA PRINCIPAL
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1)))
                : _mensajeError != null
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                    const SizedBox(height: 12),
                    const Text('Error de Conexión', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(_mensajeError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1)),
                      onPressed: _cargarDuenos,
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      label: const Text('Reintentar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            )
                : _duenosFiltrados.isEmpty
                ? const Center(
              child: Text('No se encontraron asignaciones de territorio',
                  style: TextStyle(color: Colors.black38, fontWeight: FontWeight.bold, fontSize: 13)),
            )
                : RefreshIndicator(
              onRefresh: _cargarDuenos,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _duenosFiltrados.length,
                itemBuilder: (context, index) {
                  return _buildTarjetaTerritorio(_duenosFiltrados[index]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaTerritorio(Map<String, dynamic> item) {
    final territorio = (item['territorio'] ?? 'TERRITORIO GENERAL').toString().toUpperCase();
    final subArea = (item['sub_area'] ?? '').toString().toUpperCase();
    final equipo = (item['equipo'] ?? '').toString();

    final abiNombre = (item['responsable_abi'] ?? 'NO ASIGNADO').toString();
    final abiFoto = _formatearUrlDrive(item['foto_abi']?.toString());

    final olNombre = (item['ol'] ?? 'NO ASIGNADO').toString();
    final olFoto = _formatearUrlDrive(item['foto_ol']?.toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER DE TERRITORIO
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFE3F2FD),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(left: BorderSide(color: Color(0xFF0D47A1), width: 4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        territorio,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0D47A1),
                        ),
                      ),
                      if (subArea.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'SUB ÁREA: $subArea',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
                if (equipo.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      equipo,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // CONTENIDO: DUEÑO ABI vs DUEÑO OL
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildTarjetaResponsable(
                    cargo: 'DUEÑO ABI',
                    nombre: abiNombre.isEmpty ? 'NO ASIGNADO' : abiNombre,
                    urlFoto: abiFoto,
                    colorHeader: const Color(0xFF0D47A1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTarjetaResponsable(
                    cargo: 'DUEÑO OL',
                    nombre: olNombre.isEmpty ? 'NO ASIGNADO' : olNombre,
                    urlFoto: olFoto,
                    colorHeader: const Color(0xFF1565C0),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaResponsable({
    required String cargo,
    required String nombre,
    required String urlFoto,
    required Color colorHeader,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: colorHeader,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              cargo,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colorHeader, width: 2),
            ),
            child: ClipOval(
              child: urlFoto.isNotEmpty
                  ? Image.network(
                urlFoto,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 32, color: Colors.grey),
              )
                  : const Icon(Icons.person, size: 32, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            nombre.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}