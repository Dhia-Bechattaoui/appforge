import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appforge/appforge.dart';

void main() {
  group('Step 12: Theme Harmonizer & Contrast Engine (AppThemeHarmonizer)', () {
    test('W3C Contrast Ratio Calculation matches official mathematical formula',
        () {
      final ratioBlackWhite =
          AppThemeHarmonizer.contrastRatio(Colors.black, Colors.white);
      expect(ratioBlackWhite, closeTo(21.0, 0.1));

      final ratioIdentical =
          AppThemeHarmonizer.contrastRatio(Colors.white, Colors.white);
      expect(ratioIdentical, closeTo(1.0, 0.01));

      final ratioDarkNavyOnDarkBg = AppThemeHarmonizer.contrastRatio(
        const Color(0xFF041C4E),
        const Color(0xFF0A0F1D),
      );
      // Navy on dark background is low contrast (< 2.0)
      expect(ratioDarkNavyOnDarkBg < 3.0, isTrue);
    });

    test('ensureContrast shifts luminance to guarantee WCAG AA 4.5:1 ratio',
        () {
      const darkBackground = Color(0xFF0A0F1D);
      const lowContrastNavy = Color(0xFF041C4E);

      final elevated = AppThemeHarmonizer.ensureContrast(
        foreground: lowContrastNavy,
        background: darkBackground,
        minRatio: 4.5,
      );

      final contrastAfter =
          AppThemeHarmonizer.contrastRatio(elevated, darkBackground);
      expect(contrastAfter >= 4.5, isTrue);

      const lightBackground = Color(0xFFF8FAFC);
      const lowContrastYellow = Color(0xFFFEF08A);

      final deepened = AppThemeHarmonizer.ensureContrast(
        foreground: lowContrastYellow,
        background: lightBackground,
        minRatio: 4.5,
      );

      final contrastAfterLight =
          AppThemeHarmonizer.contrastRatio(deepened, lightBackground);
      expect(contrastAfterLight >= 4.5, isTrue);
    });

    test(
        'deriveDark creates a high-contrast dark theme from light theme without dark text on dark surfaces',
        () {
      final lightTheme = ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF041C4E), // Deep Navy
          primary: const Color(0xFF041C4E),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      );

      final derivedDark = AppThemeHarmonizer.deriveDark(lightTheme);

      expect(derivedDark.brightness, Brightness.dark);
      expect(
          derivedDark.scaffoldBackgroundColor.computeLuminance() < 0.1, isTrue);

      // Verify that primary color has been elevated for visibility
      final primaryContrast = AppThemeHarmonizer.contrastRatio(
        derivedDark.colorScheme.primary,
        derivedDark.scaffoldBackgroundColor,
      );
      expect(primaryContrast >= 4.5, isTrue);

      // Verify bodyMedium text has high contrast on dark background
      final bodyTextColor =
          derivedDark.textTheme.bodyMedium?.color ?? Colors.white;
      final textContrast = AppThemeHarmonizer.contrastRatio(
        bodyTextColor,
        derivedDark.scaffoldBackgroundColor,
      );
      expect(textContrast >= 4.5, isTrue);
    });

    test(
        'deriveLight creates a high-contrast light theme from dark theme without light text on light surfaces',
        () {
      final darkTheme = ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          surface: Color(0xFF131B2E),
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0F1D),
      );

      final derivedLight = AppThemeHarmonizer.deriveLight(darkTheme);

      expect(derivedLight.brightness, Brightness.light);
      expect(derivedLight.scaffoldBackgroundColor.computeLuminance() > 0.8,
          isTrue);

      // Verify bodyMedium text has high contrast on light background
      final bodyTextColor =
          derivedLight.textTheme.bodyMedium?.color ?? const Color(0xFF0F172A);
      final textContrast = AppThemeHarmonizer.contrastRatio(
        bodyTextColor,
        derivedLight.scaffoldBackgroundColor,
      );
      expect(textContrast >= 4.5, isTrue);
    });

    testWidgets(
        'MasterApp with only theme derives darkTheme and applies it in dark mode',
        (tester) async {
      final customLightTheme = ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF041C4E),
          primary: const Color(0xFF041C4E),
        ),
      );

      await tester.pumpWidget(
        MasterApp(
          theme: customLightTheme,
          // darkTheme is intentionally omitted
          themeMode: ThemeMode.dark,
          home: Builder(
            builder: (context) {
              final activeTheme = Theme.of(context);
              return Scaffold(
                backgroundColor: activeTheme.scaffoldBackgroundColor,
                body: Text(
                  'DARK_MODE_CONTENT',
                  style: activeTheme.textTheme.bodyMedium,
                ),
              );
            },
          ),
        ),
      );

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      final scaffoldBg = scaffold.backgroundColor!;
      expect(scaffoldBg.computeLuminance() < 0.1, isTrue);

      final text = tester.widget<Text>(find.byType(Text));
      final textColor = text.style!.color!;
      // Guaranteed contrast ratio >= 4.5
      expect(AppThemeHarmonizer.contrastRatio(textColor, scaffoldBg) >= 4.5,
          isTrue);
    });

    testWidgets(
        'MasterApp with both theme and darkTheme performs ZERO MUTATION',
        (tester) async {
      final explicitLight = ThemeData(
        scaffoldBackgroundColor: const Color(0xFF112233),
      );
      final explicitDark = ThemeData(
        scaffoldBackgroundColor: const Color(0xFF445566),
      );

      await tester.pumpWidget(
        MasterApp(
          theme: explicitLight,
          darkTheme: explicitDark,
          themeMode: ThemeMode.dark,
          home: const Scaffold(body: Text('CONTENT')),
        ),
      );

      final BuildContext context = tester.element(find.text('CONTENT'));
      // Exactly the developer's custom color without mutation
      expect(
          Theme.of(context).scaffoldBackgroundColor, const Color(0xFF445566));
    });

    testWidgets(
        'Context and Color extensions provide ergonomic contrast calculation',
        (tester) async {
      await tester.pumpWidget(
        const MasterApp(
          home: Scaffold(body: Text('EXTENSIONS')),
        ),
      );

      final BuildContext context = tester.element(find.text('EXTENSIONS'));

      const darkCard = Color(0xFF0A0F1D);
      const lightCard = Color(0xFFF8FAFC);

      expect(context.contrastColor(darkCard), Colors.white);
      expect(context.contrastColor(lightCard), const Color(0xFF0F172A));

      const navy = Color(0xFF041C4E);
      expect(navy.hasAccessibleContrast(darkCard), isFalse);
      final fixed = navy.ensureContrast(against: darkCard);
      expect(fixed.hasAccessibleContrast(darkCard), isTrue);
    });

    testWidgets(
        'Bottom navigation selected item color is 100% AUTOMATIC in dark mode with ZERO developer parameters',
        (tester) async {
      await tester.pumpWidget(
        MasterApp(
          harmonizeTheme: true,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF041C4E), // Deep navy
              primary: const Color(0xFF041C4E),
            ),
          ),
          themeMode: ThemeMode.dark,
          home: Scaffold(
            bottomNavigationBar: BottomNavigationBar(
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.settings), label: 'Settings'),
              ],
            ),
          ),
        ),
      );

      final BuildContext context =
          tester.element(find.byType(BottomNavigationBar));
      final theme = Theme.of(context);
      final navTheme = theme.bottomNavigationBarTheme;
      final autoSelectedColor =
          navTheme.selectedItemColor ?? theme.colorScheme.primary;

      // Automatically elevated to high contrast against dark surface without ANY manual developer code!
      expect(
          AppThemeHarmonizer.contrastRatio(
                  autoSelectedColor, theme.scaffoldBackgroundColor) >=
              4.5,
          isTrue);
      // Assert it is NOT the dark navy (0xFF041C4E)
      expect(autoSelectedColor != const Color(0xFF041C4E), isTrue);
    });

    test('deriveDark automatically harmonizes chipTheme and button themes', () {
      final lightTheme = ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF041C4E),
          primary: const Color(0xFF041C4E),
        ),
      );

      final darkTheme = AppThemeHarmonizer.deriveDark(lightTheme);

      // Chip theme should have dark background, NOT light white
      expect(darkTheme.chipTheme.backgroundColor, const Color(0xFF1E293B));
      // Selected chip should use elevated vibrant primary
      expect(darkTheme.chipTheme.selectedColor, darkTheme.colorScheme.primary);
      // Contrast of unselected chip text against dark chip background >= 4.5:1
      expect(
        AppThemeHarmonizer.contrastRatio(
              darkTheme.chipTheme.labelStyle!.color!,
              darkTheme.chipTheme.backgroundColor!,
            ) >=
            4.5,
        isTrue,
      );

      // Buttons should use elevated vibrant primary
      expect(
        darkTheme.filledButtonTheme.style?.backgroundColor?.resolve({}),
        darkTheme.colorScheme.primary,
      );

      // Input decoration should automatically have dark surface fillColor, NOT white!
      expect(darkTheme.inputDecorationTheme.filled, isTrue);
      expect(darkTheme.inputDecorationTheme.fillColor, const Color(0xFF131B2E));
      expect(
        AppThemeHarmonizer.contrastRatio(
              darkTheme.inputDecorationTheme.hintStyle!.color!,
              darkTheme.inputDecorationTheme.fillColor!,
            ) >=
            4.5,
        isTrue,
      );
    });

    testWidgets(
        'TextField has automatic dark surface and readable hint in dark mode with ZERO parameters',
        (tester) async {
      await tester.pumpWidget(
        MasterApp(
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF041C4E),
              primary: const Color(0xFF041C4E),
            ),
          ),
          themeMode: ThemeMode.dark,
          home: const Scaffold(
            body: TextField(
              decoration: InputDecoration(
                hintText: 'Type something...',
              ),
            ),
          ),
        ),
      );

      final BuildContext context = tester.element(find.byType(TextField));
      final theme = Theme.of(context);
      final inputTheme = theme.inputDecorationTheme;

      // Dark surface, NOT white!
      expect(inputTheme.fillColor, const Color(0xFF131B2E));
      // Hint text has high contrast
      expect(inputTheme.hintStyle?.color, const Color(0xFF94A3B8));
    });
  });
}
