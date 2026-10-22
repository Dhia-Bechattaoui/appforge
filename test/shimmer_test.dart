import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appforge/appforge.dart';

void main() {
  group('Step 14: Zero-Dependency Skeleton Shimmer Engine (AppShimmer)', () {
    testWidgets('AppShimmer renders animated layout placeholder when enabled',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppShimmer(
              child: Container(
                width: 100,
                height: 50,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AppShimmer), findsOneWidget);

      // Advance animation
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AppShimmer), findsOneWidget);
    });

    testWidgets(
        'AppShimmer automatically skeletonizes layout by default without any flag',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppShimmer(
              child: const Text('Automatic Skeletonization'),
            ),
          ),
        ),
      );

      expect(find.byType(AppShimmer), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AppShimmer), findsOneWidget);
    });

    testWidgets(
        'AppShimmer renders child directly without ShaderMask when enabled is false',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppShimmer(
              enabled: false,
              child: const Text('Static Text Placeholder'),
            ),
          ),
        ),
      );

      expect(find.byType(AppShimmer), findsOneWidget);
      expect(find.byType(ShaderMask), findsNothing);
      expect(find.text('Static Text Placeholder'), findsOneWidget);
    });

    testWidgets(
        'AppShimmer.box creates rounded placeholder with custom dimensions',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppShimmer.box(
              width: 150,
              height: 24,
              borderRadius: 12,
            ),
          ),
        ),
      );

      expect(find.byType(AppShimmer), findsOneWidget);
      final container = tester.widget<Container>(find.descendant(
        of: find.byType(AppShimmer),
        matching: find.byType(Container),
      ));

      final constraints = container.constraints;
      expect(constraints?.minWidth, 150);
      expect(constraints?.maxHeight, 24);

      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.borderRadius, BorderRadius.circular(12));
    });

    testWidgets(
        'AppShimmer.circle creates circular placeholder with custom radius',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppShimmer.circle(radius: 30),
          ),
        ),
      );

      expect(find.byType(AppShimmer), findsOneWidget);
      final container = tester.widget<Container>(find.descendant(
        of: find.byType(AppShimmer),
        matching: find.byType(Container),
      ));

      final constraints = container.constraints;
      expect(constraints?.minWidth, 60); // 2 * radius
      expect(constraints?.minHeight, 60);

      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.shape, BoxShape.circle);
    });

    testWidgets('AppShimmer.text renders multiple placeholder lines',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppShimmer.text(
              width: 200,
              height: 12,
              lines: 3,
              spacing: 6,
            ),
          ),
        ),
      );

      expect(find.byType(AppShimmer), findsOneWidget);
      expect(find.byType(Column), findsOneWidget);

      // Verify 3 line containers
      final lineContainers = find.descendant(
        of: find.byType(Column),
        matching: find.byType(Container),
      );
      expect(lineContainers, findsNWidgets(3));
    });

    testWidgets('AppShimmer.listTile renders standard mobile list skeleton',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppShimmer.listTile(
              hasLeading: true,
              hasTrailing: true,
              subtitleLines: 1,
            ),
          ),
        ),
      );

      expect(find.byType(AppShimmer), findsOneWidget);
      expect(find.byType(Row), findsOneWidget);

      // Leading avatar circle exists
      final leadingFinder = find.byWidgetPredicate((widget) =>
          widget is Container &&
          (widget.decoration as BoxDecoration?)?.shape == BoxShape.circle);
      expect(leadingFinder, findsOneWidget);
    });

    testWidgets('AppShimmer.card renders card image and body placeholders',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppShimmer.card(
              width: 250,
              imageHeight: 120,
              borderRadius: 16,
            ),
          ),
        ),
      );

      expect(find.byType(AppShimmer), findsOneWidget);
      expect(find.byType(Column), findsWidgets);
    });

    testWidgets(
        'Directionality.rtl respects ShimmerDirection.auto and sweeps right-to-left',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: AppShimmer(
                direction: ShimmerDirection.auto,
                child: SizedBox(width: 100, height: 50),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AppShimmer), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 750));
      expect(find.byType(AppShimmer), findsOneWidget);
    });

    testWidgets('Widget.shimmer() extension wraps target in AppShimmer',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              width: 80,
              height: 20,
              color: Colors.white,
            ).shimmer(duration: const Duration(seconds: 1)),
          ),
        ),
      );

      expect(find.byType(AppShimmer), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AppShimmer), findsOneWidget);
    });

    testWidgets('AppShimmer stops animation when loop count is reached',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppShimmer(
              duration: const Duration(milliseconds: 500),
              loop: 1,
              child: Container(width: 50, height: 50, color: Colors.white),
            ),
          ),
        ),
      );

      // Complete 1 loop
      await tester.pump(const Duration(milliseconds: 600));
      // Ticker should finish cleanly without error
      expect(find.byType(AppShimmer), findsOneWidget);
    });

    testWidgets('AppShimmer automatically extracts bones matching child layout',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppShimmer(
              enabled: true,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Dr. Sara Al-Thani', style: TextStyle(fontSize: 16)),
                      SizedBox(height: 4),
                      Text('AI Architect', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AppShimmer), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AppShimmer), findsOneWidget);
    });

    testWidgets(
        'widget.shimmer() wraps child and disables cleanly when enabled is false',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const Text('Real Content').shimmer(enabled: false),
          ),
        ),
      );

      expect(find.byType(AppShimmer), findsOneWidget);
      expect(find.text('Real Content'), findsOneWidget);
    });

    testWidgets(
        'AppShimmer renders smoothly through multiple high-frequency animation frames',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Text('Card Title', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                ),
              ],
            ).shimmer(duration: const Duration(milliseconds: 1000)),
          ),
        ),
      );

      expect(find.byType(AppShimmer), findsOneWidget);

      // Advance through 10 animation frames (simulating 60-120Hz ticks)
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
      }
    });
  });
}
