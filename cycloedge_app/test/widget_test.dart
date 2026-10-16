import 'package:flutter_test/flutter_test.dart';
import 'package:cycloedge_app/main.dart';

void main() {
  testWidgets('CycloEdge smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CycloEdgeApp());
    expect(find.text('KM/H'), findsOneWidget);
  });
}
