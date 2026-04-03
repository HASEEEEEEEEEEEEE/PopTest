import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:poptest/app.dart';

void main() {
  testWidgets('App smoke test – renders without crashing', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: PopTestApp()),
    );

    // The Home screen title should be visible on startup.
    expect(find.text('Home'), findsOneWidget);
  });
}
