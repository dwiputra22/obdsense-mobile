import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rushsenseai/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // We wrap it in ProviderScope because RushSenseApp uses Riverpod.
    await tester.pumpWidget(
      const ProviderScope(
        child: RushSenseApp(),
      ),
    );

    // Verify that the app pumps successfully.
    expect(find.byType(RushSenseApp), findsOneWidget);
  });
}
