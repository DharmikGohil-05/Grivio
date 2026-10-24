import 'package:flutter_test/flutter_test.dart';

import 'package:grivio_mobile/main.dart';
import 'package:grivio_mobile/screens/splash_screen.dart';

void main() {
  testWidgets('Grivio app boots through splash then into login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const GrivioApp());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    // Auth is resolved, but the splash is still held for its minimum
    // brand duration (repeating animations — pump fixed steps, never settle).
    expect(find.byType(SplashScreen), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
