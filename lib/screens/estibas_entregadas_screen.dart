import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

class EstibasEntregadasScreen extends StatefulWidget {
  final Map<String, dynamic>? datosEmpleado;
  const EstibasEntregadasScreen({super.key, this.datosEmpleado});

  @override
  State<EstibasEntregadasScreen> createState() => _EstibasEntregadasScreenState();
}

class _EstibasEntregadasScreenState extends State<EstibasEntregadasScreen> {
  bool _cargando = true;
  List<dynamic> _registros = [];

  // Lista de personal obtenida de rotura_lista (OPM)
  List<String> _listaPersonal = [];
  bool _cargandoPersonal = true;

  // URLs específicas para esta tabla según tu backend
  final String _urlConsultar = '${ApiService.baseUrl}/${ApiService.database}/consultar/roturas/estibas_reporte_linea';
  final String _urlInsertar = '${ApiService.baseUrl}/${ApiService.database}/insertar/roturas/estibas_reporte_linea';

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _cargarPersonal();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final response = await http.get(
        Uri.parse(_urlConsultar),
        headers: {'Content-Type': 'application/json', 'x-api-key': ApiService.apiKey},
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> parsedData = [];

        // 🛡️ REGLA INTELIGENTE DE LECTURA (Evita el choque fatal)
        if (decoded is List) {
          parsedData = decoded;
        } else if (decoded is Map<String, dynamic> && decoded['data'] != null) {
          parsedData = decoded['data'] is List ? decoded['data'] : [];
        }

        setState(() {
          _registros = parsedData;
        });
      } else {
        _mostrarMensaje('Error al cargar los datos', esError: true);
      }
    } catch (e) {
      _mostrarMensaje('Fallo de conexión: $e', esError: true);
    } finally {
      setState(() => _cargando = false);
    }
  }

  // Carga la lista de personal usando la misma función OPM del ApiService
  Future<void> _cargarPersonal() async {
    try {
      final lista = await ApiService.obtenerOpm();
      if (mounted) {
        setState(() {
          _listaPersonal = lista;
          _cargandoPersonal = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargandoPersonal = false);
    }
  }

  void _mostrarFormulario() {
    final TextEditingController txtCantidad = TextEditingController();
    final TextEditingController txtQuienRecibe = TextEditingController();

    // Controladores para los nuevos campos
    final TextEditingController txtFecha = TextEditingController(text: DateTime.now().toString().substring(0, 10));
    String turnoSeleccionado = 'T1';

    // Nueva variable para el área seleccionada
    String? areaSeleccionada;
    final List<String> opcionesArea = [
      'Linea 1', 'Linea 2', 'Linea 3', 'Linea 4', 'Linea 5',
      'Linea 6', 'Linea 7', 'Linea 8', 'Linea 9', 'Linea 10',
      'Tapas', 'T2', 'Maquila'
    ];

    bool guardando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
            builder: (context, setStateModal) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 20, right: 20, top: 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Nueva Entrega de Estibas',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
                      ),
                      const SizedBox(height: 20),

                      // 📅 CAMPO: FECHA
                      TextField(
                        controller: txtFecha,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Fecha',
                          prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFF0D47A1)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onTap: () async {
                          DateTime? seleccion = await showDatePicker(
                            context: context,
                            initialDate: DateTime.parse(txtFecha.text),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (seleccion != null) {
                            setStateModal(() {
                              txtFecha.text = seleccion.toString().substring(0, 10);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 15),

                      // ⏰ CAMPO: TURNO
                      DropdownButtonFormField<String>(
                        value: turnoSeleccionado,
                        decoration: InputDecoration(
                          labelText: 'Turno',
                          prefixIcon: const Icon(Icons.access_time, color: Color(0xFF0D47A1)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: ['T1', 'T2', 'T3'].map((String val) {
                          return DropdownMenuItem(value: val, child: Text(val));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setStateModal(() => turnoSeleccionado = val);
                          }
                        },
                      ),
                      const SizedBox(height: 15),

                      // 🏢 NUEVO CAMPO: ÁREA ENTREGADA (Desplegable)
                      DropdownButtonFormField<String>(
                        value: areaSeleccionada,
                        decoration: InputDecoration(
                          labelText: 'Área Entregada',
                          prefixIcon: const Icon(Icons.place, color: Color(0xFF0D47A1)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: opcionesArea.map((String val) {
                          return DropdownMenuItem(value: val, child: Text(val));
                        }).toList(),
                        onChanged: (val) {
                          setStateModal(() => areaSeleccionada = val);
                        },
                      ),
                      const SizedBox(height: 15),

                      // 🔢 CAMPO: CANTIDAD ENTREGADA
                      TextField(
                        controller: txtCantidad,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Cantidad Entregada',
                          prefixIcon: const Icon(Icons.numbers, color: Color(0xFF0D47A1)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 15),

                      // 👤 NUEVO CAMPO: NOMBRE QUIEN RECIBE (Autocomplete sin números)
                      _crearBuscadorPersonal(
                        controller: txtQuienRecibe,
                        label: 'Nombre de quien recibe',
                        icono: Icons.person,
                        opciones: _listaPersonal,
                        cargando: _cargandoPersonal,
                      ),

                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D47A1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: guardando ? null : () async {
                            if (txtCantidad.text.isEmpty || areaSeleccionada == null || txtQuienRecibe.text.isEmpty || txtFecha.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Por favor llena todos los campos'), backgroundColor: Colors.orange),
                              );
                              return;
                            }

                            setStateModal(() => guardando = true);

                            // JSON Payload
                            final payload = {
                              "fecha": txtFecha.text.trim(),
                              "turno": turnoSeleccionado,
                              "cantidad_esntregada": txtCantidad.text.trim(),
                              "area_entregada": areaSeleccionada,
                              "nombre_quien recibe": txtQuienRecibe.text.trim()
                            };

                            try {
                              final response = await http.post(
                                Uri.parse(_urlInsertar),
                                headers: {'Content-Type': 'application/json', 'x-api-key': ApiService.apiKey},
                                body: jsonEncode(payload),
                              );

                              if (response.statusCode == 200 || response.statusCode == 201) {
                                Navigator.pop(ctx);
                                _mostrarMensaje('Registro guardado con éxito');
                                _cargarDatos();
                              } else {
                                _mostrarMensaje('Error al guardar', esError: true);
                              }
                            } catch (e) {
                              _mostrarMensaje('Fallo de conexión', esError: true);
                            } finally {
                              setStateModal(() => guardando = false);
                            }
                          },
                          child: guardando
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('GUARDAR ENTREGA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            }
        );
      },
    );
  }

  // 🔍 WIDGET BUSCADOR INTELIGENTE PARA PERSONAL
  Widget _crearBuscadorPersonal({
    required TextEditingController controller,
    required String label,
    required IconData icono,
    required List<String> opciones,
    required bool cargando,
  }) {
    if (cargando) {
      return TextFormField(
        decoration: InputDecoration(
          labelText: 'Cargando personal...',
          prefixIcon: Icon(icono, color: const Color(0xFF0D47A1)),
          suffixIcon: const Padding(padding: EdgeInsets.all(14.0), child: CircularProgressIndicator(strokeWidth: 2)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[100],
        ),
        readOnly: true,
      );
    }

    return Autocomplete<String>(
      initialValue: TextEditingValue(text: controller.text),
      optionsBuilder: (text) {
        if (text.text.isEmpty) {
          return opciones.take(5); // Muestra 5 opciones al iniciar
        }
        return opciones
            .where((o) => o.toLowerCase().contains(text.text.toLowerCase()))
            .take(5);
      },
      onSelected: (selection) {
        controller.text = selection;
        FocusScope.of(context).unfocus();
      },
      fieldViewBuilder: (ctx, fieldCtrl, focus, onEdit) {
        if (fieldCtrl.text != controller.text && !focus.hasFocus) fieldCtrl.text = controller.text;
        fieldCtrl.addListener(() => controller.text = fieldCtrl.text);
        return TextFormField(
          controller: fieldCtrl,
          focusNode: focus,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icono, color: const Color(0xFF0D47A1)),
            suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (val) => val == null || val.isEmpty ? 'Selecciona una persona' : null,
        );
      },
      optionsViewBuilder: (ctx, onSelect, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 6.0,
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 220),
            width: MediaQuery.of(context).size.width - 40,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (ctx, i) => ListTile(
                leading: Icon(icono, color: const Color(0xFF0D47A1)),
                title: Text(options.elementAt(i), style: const TextStyle(fontSize: 14)),
                onTap: () => onSelect(options.elementAt(i)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarMensaje(String texto, {bool esError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: esError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estibas Entregadas', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1)))
          : _registros.isEmpty
          ? const Center(child: Text('No hay registros de estibas entregadas.'))
          : ListView.builder(
        padding: const EdgeInsets.all(15),
        itemCount: _registros.length,
        itemBuilder: (context, index) {
          final fila = _registros[index];

          final id = fila['id'] ?? 'N/A';
          final fecha = fila['fecha'] ?? 'Sin fecha';
          final turno = fila['turno'] ?? 'N/A';
          final cantidad = fila['cantidad_esntregada'] ?? '0';
          final area = fila['area_entregada'] ?? 'Desconocida';
          final quienRecibe = fila['nombre_quien recibe'] ?? 'No registrado';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(15),
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF0D47A1).withOpacity(0.1),
                child: const Icon(Icons.local_shipping, color: Color(0xFF0D47A1)),
              ),
              title: Text('Área: $area | Turno: $turno', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fecha: $fecha', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                    const SizedBox(height: 2),
                    Text('Recibe: $quienRecibe'),
                    const SizedBox(height: 4),
                    Text('Cantidad: $cantidad', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              trailing: Text('#$id', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0D47A1),
        onPressed: _mostrarFormulario,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nueva Entrega', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}