import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appforge/appforge.dart';

// Sample custom theme extension for testing
class BrandColors extends ThemeExtension<BrandColors> {
  const BrandColors({required this.accentGradient, required this.goldAccent});

  final Color accentGradient;
  final Color goldAccent;

  @override
  ThemeExtension<BrandColors> copyWith(
      {Color? accentGradient, Color? goldAccent}) {
    return BrandColors(
      accentGradient: accentGradient ?? this.accentGradient,
      goldAccent: goldAccent ?? this.goldAccent,
    );
  }

  @override
  ThemeExtension<BrandColors> lerp(
      ThemeExtension<BrandColors>? other, double t) {
    if (other is! BrandColors) return this;
    return BrandColors(
      accentGradient: Color.lerp(accentGradient, other.accentGradient, t)!,
      goldAccent: Color.lerp(goldAccent, other.goldAccent, t)!,
    );
  }
}

void main() {
  group('Dynamic Theming Engine (AppThemeManager)', () {
    setUp(() {
      AppThemeManager.instance.reset();
    });

    test('Initializes with ThemeMode.system', () {
      expect(App.themeMode, equals(ThemeMode.system));
    });

    test('setThemeMode updates themeMode and triggers notifier', () {
      ThemeMode? observedMode;
      App.themeModeNotifier.addListener(() {
        observedMode = App.themeMode;
      });

      App.setThemeMode(ThemeMode.dark);
      expect(App.themeMode, equals(ThemeMode.dark));
      expect(observedMode, equals(ThemeMode.dark));
      expect(App.isDark, isTrue);
      expect(App.isLight, isFalse);

      App.setThemeMode(ThemeMode.light);
      expect(App.themeMode, equals(ThemeMode.light));
      expect(observedMode, equals(ThemeMode.light));
      expect(App.isDark, isFalse);
      expect(App.isLight, isTrue);
    });

    test('toggleTheme alternates between dark and light', () {
      App.setThemeMode(ThemeMode.light);
      App.toggleTheme();
      expect(App.themeMode, equals(ThemeMode.dark));

      App.toggleTheme();
      expect(App.themeMode, equals(ThemeMode.light));
    });

    testWidgets(
        'AppThemeContextExtension provides context shortcuts and tokens',
        (tester) async {
      const customBrand = BrandColors(
        accentGradient: Color(0xFF00FF00),
        goldAccent: Color(0xFFFFD700),
      );

      final lightTheme = ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        cardColor: const Color(0xFFFFFFFF),
        extensions: const <ThemeExtension<dynamic>>[customBrand],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: lightTheme,
          home: Builder(
            builder: (context) {
              expect(context.isDark, isFalse);
              expect(context.isLight, isTrue);
              expect(context.scaffoldBackgroundColor,
                  equals(const Color(0xFFFAFAFA)));
              expect(context.cardColor, equals(const Color(0xFFFFFFFF)));

              final tokens = context.tokens<BrandColors>();
              expect(tokens, isNotNull);
              expect(tokens!.goldAccent, equals(const Color(0xFFFFD700)));

              return const SizedBox();
            },
          ),
        ),
      );
    });
  });

  group('Responsive Scaling & Metrics (AppResponsive)', () {
    setUp(() {
      AppResponsive.reset();
    });

    test('Falls back to 1.0 when not initialized', () {
      expect(100.w, equals(100.0));
      expect(50.h, equals(50.0));
      expect(16.sp, equals(16.0));
      expect(12.r, equals(12.0));
    });

    test('Scales width and height proportionally to design size', () {
      // Baseline 390x844, screen is 780x1688 (exactly 2x)
      AppResponsive.init(
        designSize: const Size(390, 844),
        screenSize: const Size(780, 1688),
      );

      expect(100.w, equals(200.0));
      expect(50.h, equals(100.0));
      expect(16.sp, equals(32.0));
      expect(12.r, equals(24.0));
    });

    test('scaleRadius uses minimum dimension ratio to prevent distortion', () {
      // Width 2x (390 -> 780), Height 1x (844 -> 844)
      AppResponsive.init(
        designSize: const Size(390, 844),
        screenSize: const Size(780, 844),
      );

      // min(2.0, 1.0) = 1.0
      expect(16.r, equals(16.0));
      expect(100.w, equals(200.0));
      expect(50.h, equals(50.0));
    });

    test('gapX and gapY create SizedBox spacers', () {
      final gapX = 16.gapX as SizedBox;
      final gapY = 24.gapY as SizedBox;

      expect(gapX.width, equals(16.0));
      expect(gapY.height, equals(24.0));
    });

    testWidgets('Context responsive extensions report correct metrics',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(context.screenWidth, equals(400.0));
              expect(context.screenHeight, equals(600.0));
              expect(context.isMobile, isTrue);
              expect(context.isTablet, isFalse);
              expect(context.isDesktop, isFalse);
              expect(context.isPortrait, isTrue);
              expect(context.isLandscape, isFalse);
              return const SizedBox();
            },
          ),
        ),
      );
    });

    test(
        'scaleSp scales with screen geometry and does not double-multiply with system textScaleFactor',
        () {
      // Screen width is 2x design width (390 -> 780), and system text scale is 1.5x
      AppResponsive.init(
        designSize: const Size(390, 844),
        screenSize: const Size(780, 844),
        textScaleFactor: 1.5,
      );

      // By default, scaleSp scales strictly by screen geometry (2x * 16 = 32),
      // allowing Flutter's Text widget to apply textScaleFactor (1.5) without double scaling (which would be 48)
      expect(16.sp, equals(32.0));

      // With maxScale: 1.5, clamped to 16 * 1.5 = 24.0
      expect(AppResponsive.scaleSp(16, maxScale: 1.5), equals(24.0));

      // When applySystemScale is explicitly true (for custom Canvas painting):
      expect(AppResponsive.scaleSp(16, applySystemScale: true), equals(48.0));
    });

    test('Breakpoints correctly identify tablet and desktop', () {
      AppResponsive.init(screenSize: const Size(768, 1024));
      expect(App.isMobile, isFalse);
      expect(App.isTablet, isTrue);
      expect(App.isDesktop, isFalse);

      AppResponsive.init(screenSize: const Size(1280, 800));
      expect(App.isMobile, isFalse);
      expect(App.isTablet, isFalse);
      expect(App.isDesktop, isTrue);
    });

    testWidgets(
        'context.w, context.h, context.r, context.sp and metricsNotifier react to media query changes',
        (tester) async {
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2.0; // Logical size 390x844 (1x)
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (context) {
            return Column(
              children: [
                Text('w:${context.w(100)}'),
                Text('h:${context.h(50)}'),
                Text('r:${context.r(16)}'),
                Text('sp:${context.sp(14)}'),
              ],
            );
          }),
        ),
      );

      expect(find.text('w:100.0'), findsOneWidget);
      expect(find.text('h:50.0'), findsOneWidget);
      expect(find.text('r:16.0'), findsOneWidget);
      expect(find.text('sp:14.0'), findsOneWidget);

      // Now change physical size to 2x width (1560, 1688) -> logical size (780, 844)
      tester.view.physicalSize = const Size(1560, 1688);
      await tester.pump();

      // context.w(100) automatically scales to 200.0 because of inherited MediaQuery dependency
      expect(find.text('w:200.0'), findsOneWidget);
      expect(find.text('h:50.0'), findsOneWidget);
    });
  });

  group('MasterApp Root Container', () {
    setUp(() {
      AppThemeManager.instance.reset();
      AppResponsive.reset();
    });

    testWidgets('Renders and synchronizes theme and locale reactively',
        (tester) async {
      final translations = AppTranslations.fromMap({
        'en': {'greeting': 'Hello'},
        'ar': {'greeting': 'مرحبا'},
      });

      await tester.pumpWidget(
        MasterApp(
          title: 'Test App',
          translations: translations,
          initialLocale: const Locale('en'),
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Column(
                  children: [
                    Text('greeting'.tr),
                    Text(context.isDark ? 'Dark Mode' : 'Light Mode'),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('Light Mode'), findsOneWidget);

      // Change locale dynamically
      App.setLocale(const Locale('ar'));
      await tester.pumpAndSettle();

      expect(find.text('مرحبا'), findsOneWidget);

      // Toggle theme dynamically
      App.setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();

      expect(find.text('Dark Mode'), findsOneWidget);
    });

    testWidgets(
        'MasterApp(themeMode: ThemeMode.light) allows dynamic toggling at runtime via App.toggleTheme()',
        (tester) async {
      await tester.pumpWidget(
        MasterApp(
          themeMode: ThemeMode.light,
          home: Builder(builder: (context) {
            return Text(context.isDark ? 'Mode:Dark' : 'Mode:Light');
          }),
        ),
      );

      expect(find.text('Mode:Light'), findsOneWidget);
      expect(App.themeMode, equals(ThemeMode.light));

      // Toggle theme mode at runtime
      App.toggleTheme();
      await tester.pumpAndSettle();

      // Must switch to Dark Mode! (Previously broken because widget.themeMode ?? activeMode always returned widget.themeMode)
      expect(App.themeMode, equals(ThemeMode.dark));
      expect(find.text('Mode:Dark'), findsOneWidget);
    });
  });
}
