import 'package:flutter_test/flutter_test.dart';
import 'package:au_insights/main.dart';

void main() {
  testWidgets('AU Insights smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AuInsightsApp());

    // Simple sanity check: app bar title present
    expect(find.text('AU Insights'), findsOneWidget);
  });
}
