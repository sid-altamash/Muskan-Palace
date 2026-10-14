import 'package:flutter_test/flutter_test.dart';
import 'package:muskan_palace/main.dart';

void main() {
  testWidgets('App renders correctly smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MuskanPalaceApp());
    expect(find.text('Performance Dashboard'), findsOneWidget);
  });
}
