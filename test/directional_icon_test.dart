import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appforge/appforge.dart';

void main() {
  group('Directional Icons & autoMirror Extension', () {
    testWidgets('autoMirror does not flip widget in LTR', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              final icon = const Icon(Icons.arrow_forward).autoMirror(context);
              // In LTR, autoMirror returns the original icon unmodified
              expect(icon is Icon, isTrue);
              return icon;
            },
          ),
        ),
      );
    });

    testWidgets('autoMirror wraps widget in Transform.flip in RTL',
        (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.rtl,
          child: Builder(
            builder: (context) {
              final mirrored =
                  const Icon(Icons.arrow_forward).autoMirror(context);
              expect(mirrored is Transform, isTrue);
              return mirrored;
            },
          ),
        ),
      );
    });

    testWidgets(
        'AppIcons facade produces directional arrows correctly in LTR and RTL',
        (tester) async {
      // LTR test
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              final forward = AppIcons.arrowForward(context: context);
              final back = AppIcons.arrowBack(context: context);
              final chevronFwd = AppIcons.chevronForward(context: context);
              final chevronBk = AppIcons.chevronBack(context: context);

              expect(forward is Icon, isTrue);
              expect(back is Icon, isTrue);
              expect(chevronFwd is Icon, isTrue);
              expect(chevronBk is Icon, isTrue);
              return const SizedBox();
            },
          ),
        ),
      );

      // RTL test
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.rtl,
          child: Builder(
            builder: (context) {
              final forward = AppIcons.arrowForward(context: context);
              final back = AppIcons.arrowBack(context: context);
              final chevronFwd = AppIcons.chevronForward(context: context);
              final chevronBk = AppIcons.chevronBack(context: context);

              // In RTL, they must be wrapped in Transform.flip
              expect(forward is Transform, isTrue);
              expect(back is Transform, isTrue);
              expect(chevronFwd is Transform, isTrue);
              expect(chevronBk is Transform, isTrue);
              return const SizedBox();
            },
          ),
        ),
      );
    });

    test('autoMirror uses global App.isRtl when context is not provided', () {
      App.setLocale(const Locale('en', 'US'));
      final ltrWidget = const Icon(Icons.arrow_forward).autoMirror();
      expect(ltrWidget is Icon, isTrue);

      App.setLocale(const Locale('ar'));
      final rtlWidget = const Icon(Icons.arrow_forward).autoMirror();
      expect(rtlWidget is Transform, isTrue);

      // Reset
      App.setLocale(const Locale('en', 'US'));
    });
  });
}
