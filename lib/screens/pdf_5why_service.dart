import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class Pdf5WhyService {
  // 🚀 ABRE LA PANTALLA DEL VISOR
  static void abrirVisorPdf(BuildContext context, Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VisorPdfScreen(item: item),
      ),
    );
  }

  // 🚀 CONSTRUYE EL DOCUMENTO PDF
  static Future<Uint8List> generarPdf(Map<String, dynamic> item) async {
    final pdf = pw.Document();

    final String fecha = (item['fecha_evento'] ?? '').toString();
    final String turno = (item['turno'] ?? '').toString().toUpperCase();
    final String area = (item['area'] ?? '').toString().toUpperCase();
    final String pi = (item['pi'] ?? '').toString().toUpperCase();
    final String supervisor = (item['supervisor'] ?? '').toString().toUpperCase();

    final String disparador = (item['disparador'] ?? '').toString().toUpperCase();
    final String participantes = (item['involucrados'] ?? item['equipo'] ?? '').toString().replaceAll('Líder:', '').replaceAll('|', '-').toUpperCase();
    final String contencion = (item['contencion'] ?? '').toString().toUpperCase();
    final String descripcion = (item['descripcion'] ?? item['problema'] ?? '').toString().toUpperCase();

    final String p1 = (item['porque_1'] ?? '').toString().toUpperCase();
    final String p2 = (item['porque_2'] ?? '').toString().toUpperCase();
    final String p3 = (item['porque_3'] ?? '').toString().toUpperCase();
    final String p4 = (item['porque_4'] ?? '').toString().toUpperCase();
    final String p5 = (item['porque_5'] ?? '').toString().toUpperCase();

    final String causaRaiz = (item['causa_raiz'] ?? '').toString().toUpperCase();
    final String accPreventiva = (item['accion_preventiva'] ?? '').toString().toUpperCase();
    final String accCorrectiva = (item['accion_reactiva'] ?? item['accion_correctiva'] ?? '').toString().toUpperCase();

    final String accionFila = (item['accion_1'] ?? '').toString().toUpperCase();
    final String respFila = (item['responsable_1'] ?? item['responsable_accion_1'] ?? '').toString().toUpperCase();
    final String cierreFila = (item['fecha_plazo'] ?? item['fecha_plazo_1'] ?? '').toString();

    final String estatus = (item['estatus'] ?? 'PENDIENTE').toString().toUpperCase();

    // 🛡️ REGLA INTELIGENTE DE COLORES: Uso de Hex para evitar fallos de compilación en el paquete PDF
    PdfColor statusColor = PdfColor.fromHex('#F57C00'); // Naranja 700
    if (estatus.contains('APROBADO')) statusColor = PdfColor.fromHex('#388E3C'); // Verde 700
    if (estatus.contains('RECHAZADO')) statusColor = PdfColor.fromHex('#D32F2F'); // Rojo 700

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            pw.Container(
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1)),
                child: pw.Row(
                    children: [
                      pw.Expanded(
                          flex: 6,
                          child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                              children: [
                                pw.Row(
                                    children: [
                                      pw.Expanded(child: _buildHeaderCell('FECHA:', fecha, borderRight: true, borderBottom: true)),
                                      pw.Expanded(child: _buildHeaderCell('TURNO:', turno, borderBottom: true)),
                                    ]
                                ),
                                pw.Row(
                                    children: [
                                      pw.Expanded(child: _buildHeaderCell('AREA:', area, borderRight: true, borderBottom: true)),
                                      pw.Expanded(child: _buildHeaderCell('PI:', pi, borderBottom: true)),
                                    ]
                                ),
                                _buildHeaderCell('SUPERVISOR:', supervisor),
                              ]
                          )
                      ),
                      pw.Container(width: 1, color: PdfColors.black),
                      pw.Expanded(
                          flex: 4,
                          child: pw.Container(
                              padding: const pw.EdgeInsets.all(10),
                              alignment: pw.Alignment.center,
                              child: pw.RichText(
                                  textAlign: pw.TextAlign.center,
                                  text: pw.TextSpan(children: [
                                    pw.TextSpan(text: 'EASY\n', style: pw.TextStyle(color: PdfColor.fromHex('#455A64'), fontWeight: pw.FontWeight.bold, fontSize: 18)),
                                    pw.TextSpan(text: 'LOGÍSTICA', style: pw.TextStyle(color: PdfColor.fromHex('#90A4AE'), fontWeight: pw.FontWeight.bold, fontSize: 10, letterSpacing: 1.5)),
                                  ])
                              )
                          )
                      )
                    ]
                )
            ),
            pw.Table(
                border: const pw.TableBorder(
                  left: pw.BorderSide(width: 1), right: pw.BorderSide(width: 1), bottom: pw.BorderSide(width: 1),
                  verticalInside: pw.BorderSide(width: 1), horizontalInside: pw.BorderSide(width: 1),
                ),
                columnWidths: {0: const pw.FlexColumnWidth(3.5), 1: const pw.FlexColumnWidth(6.5)},
                children: [
                  _buildTableRow('PLANTA:', 'PLANTA DE OPERACIONES', isContentBold: true),
                  _buildTableRow('DISPARADOR ACTIVADO:', disparador.isEmpty ? '-' : disparador),
                  _buildTableRow('PARTICIPANTES:', participantes.isEmpty ? '-' : participantes),
                  _buildTableRow('COMO SE CONTUVO:', contencion.isEmpty ? '-' : contencion),
                  _buildTableRow('DESCRIPCIÓN DEL EVENTO:', descripcion.isEmpty ? '-' : descripcion),
                ]
            ),
            pw.SizedBox(height: 12),
            pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                decoration: pw.BoxDecoration(color: PdfColor.fromHex('#D3D3D3'), border: pw.Border.all(width: 1)),
                child: pw.Text('Análisis de 5 porqués: ¿Cuál es la causa raíz del problema?', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))
            ),
            pw.SizedBox(height: 10),
            pw.Table(
                border: pw.TableBorder.all(width: 1),
                columnWidths: {0: const pw.FlexColumnWidth(2.5), 1: const pw.FlexColumnWidth(7.5)},
                children: [
                  _buildWhyRow('1. ¿PORQUÉ?', p1),
                  _buildWhyRow('2. ¿PORQUÉ?', p2),
                  _buildWhyRow('3. ¿PORQUÉ?', p3),
                  _buildWhyRow('4. ¿PORQUÉ?', p4.isEmpty ? '-' : p4),
                  _buildWhyRow('5. ¿PORQUÉ?', p5.isEmpty ? '-' : p5),
                ]
            ),
            pw.SizedBox(height: 15),
            pw.Table(
                border: pw.TableBorder.all(width: 1),
                columnWidths: {0: const pw.FlexColumnWidth(3.5), 1: const pw.FlexColumnWidth(6.5)},
                children: [_buildTableRow('CAUSA RAÍZ:', causaRaiz.isEmpty ? '-' : causaRaiz)]
            ),
            pw.SizedBox(height: 10),
            pw.Table(
                border: pw.TableBorder.all(width: 1),
                columnWidths: {0: const pw.FlexColumnWidth(3.5), 1: const pw.FlexColumnWidth(6.5)},
                children: [
                  _buildTableRow('ACCIÓN\nPREVENTIVA:', accPreventiva.isEmpty ? '-' : accPreventiva),
                  _buildTableRow('ACCIÓN\nCORRECTIVA:', accCorrectiva.isEmpty ? '-' : accCorrectiva),
                ]
            ),
            pw.SizedBox(height: 15),
            pw.Table(
                border: pw.TableBorder.all(width: 1),
                columnWidths: {0: const pw.FlexColumnWidth(5), 1: const pw.FlexColumnWidth(3), 2: const pw.FlexColumnWidth(2)},
                children: [
                  pw.TableRow(children: [_buildActionHeader('ACCIÓN PREVENTIVA/CORRECTIVA'), _buildActionHeader('RESPONSABLE'), _buildActionHeader('FECHA DE\nCIERRE')]),
                  pw.TableRow(children: [_buildActionBody(accionFila.isEmpty ? '-' : accionFila), _buildActionBody(respFila.isEmpty ? '-' : respFila, center: true), _buildActionBody(cierreFila.isEmpty ? '-' : cierreFila, center: true)]),
                  pw.TableRow(children: [_buildActionBody('-'), _buildActionBody('-', center: true), _buildActionBody('-', center: true)]),
                ]
            ),
            pw.SizedBox(height: 35),
            pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: statusColor, width: 2), borderRadius: pw.BorderRadius.circular(4)),
                    child: pw.Column(
                        children: [
                          pw.Text('ESTADO DEL DOCUMENTO', style: pw.TextStyle(fontSize: 8, color: statusColor)),
                          pw.SizedBox(height: 4),
                          pw.Text(estatus, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: statusColor, letterSpacing: 2)),
                        ]
                    )
                )
            )
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeaderCell(String title, String value, {bool borderRight = false, bool borderBottom = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(border: pw.Border(right: borderRight ? const pw.BorderSide(width: 1) : pw.BorderSide.none, bottom: borderBottom ? const pw.BorderSide(width: 1) : pw.BorderSide.none)),
      child: pw.RichText(text: pw.TextSpan(children: [pw.TextSpan(text: '$title ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)), pw.TextSpan(text: value, style: const pw.TextStyle(fontSize: 10))])),
    );
  }

  static pw.TableRow _buildTableRow(String title, String content, {bool isContentBold = false}) {
    return pw.TableRow(children: [
      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(content.isEmpty ? '-' : content, style: pw.TextStyle(fontWeight: isContentBold ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: 10))),
    ]);
  }

  static pw.TableRow _buildWhyRow(String title, String content) {
    return pw.TableRow(children: [
      pw.Container(constraints: const pw.BoxConstraints(minHeight: 45), padding: const pw.EdgeInsets.all(6), child: pw.Text(title, style: const pw.TextStyle(fontSize: 10))),
      pw.Container(constraints: const pw.BoxConstraints(minHeight: 45), padding: const pw.EdgeInsets.all(6), child: pw.Text(content.isEmpty ? '-' : content, style: const pw.TextStyle(fontSize: 10))),
    ]);
  }

  static pw.Widget _buildActionHeader(String text) {
    return pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(text, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)));
  }

  static pw.Widget _buildActionBody(String text, {bool center = false}) {
    return pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(text, textAlign: center ? pw.TextAlign.center : pw.TextAlign.left, style: const pw.TextStyle(fontSize: 9)));
  }
}

// 🚀 PANTALLA VISOR DE PDF
class VisorPdfScreen extends StatelessWidget {
  final Map<String, dynamic> item;
  const VisorPdfScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final area = (item['area'] ?? 'N/A').toString();
    final fecha = (item['fecha_evento'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(
        title: Text('Visor 5W - $area ($fecha)', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: PdfPreview(
        build: (format) => Pdf5WhyService.generarPdf(item),
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
      ),
    );
  }
}