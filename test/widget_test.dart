import 'package:flutter_test/flutter_test.dart';
import 'package:reparacion_estibas/main.dart';

void main() {
  testWidgets('Carga la pantalla inicial correctamente', (WidgetTester tester) async {
    await tester.pumpWidget(const ReparacionEstibasApp());
    expect(find.text('Planta Tocancipá - Estibas'), findsOneWidget);
  });
}