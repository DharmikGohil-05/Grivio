import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grivio_mobile/core/theme/app_theme.dart';
import 'package:grivio_mobile/core/theme/theme_controller.dart';
import 'package:grivio_mobile/widgets/neumorphic.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GRIVIO Design System & Theme Tests', () {
    test('Light theme tokens are configured properly', () {
      final light = buildLightTheme();
      expect(light.brightness, Brightness.light);
      expect(light.colorScheme.primary, AppColors.lightAccent);
      expect(light.scaffoldBackgroundColor, AppColors.lightBackground);
    });

    test('Dark theme tokens are configured properly', () {
      final dark = buildDarkTheme();
      expect(dark.brightness, Brightness.dark);
      expect(dark.colorScheme.primary, AppColors.darkAccent);
      expect(dark.scaffoldBackgroundColor, AppColors.darkBackground);
    });

    test('ThemeController switches modes and notifies listeners', () async {
      final controller = ThemeController.instance;
      ThemeMode? observed;
      controller.addListener(() {
        observed = controller.themeMode;
      });

      await controller.setThemeMode(ThemeMode.dark);
      expect(controller.themeMode, ThemeMode.dark);
      expect(observed, ThemeMode.dark);

      await controller.setThemeMode(ThemeMode.light);
      expect(controller.themeMode, ThemeMode.light);
      expect(observed, ThemeMode.light);

      await controller.setThemeMode(ThemeMode.system);
      expect(controller.themeMode, ThemeMode.system);
      expect(observed, ThemeMode.system);
    });

    testWidgets(
      'Neumorphic widget renders children in both light and dark contexts',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: ThemeMode.light,
            home: const Scaffold(body: Neumorphic(child: Text('Tactile Card'))),
          ),
        );

        expect(find.text('Tactile Card'), findsOneWidget);

        await tester.pumpWidget(
          MaterialApp(
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: ThemeMode.dark,
            home: const Scaffold(body: Neumorphic(child: Text('Tactile Card'))),
          ),
        );

        expect(find.text('Tactile Card'), findsOneWidget);
      },
    );

    testWidgets('ThemeSelector widget renders segmented options', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(body: ThemeSelector()),
        ),
      );

      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
    });
  });
}
