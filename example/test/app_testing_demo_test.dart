import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appforge/appforge.dart';

import 'package:example/controllers/app_settings_controller.dart';
import 'package:example/controllers/lifecycle_lab_controller.dart';
import 'package:example/controllers/state_lab_controller.dart';
import 'package:example/screens/home_screen.dart';
import 'package:example/translations.dart';

class _FakeSettingsController extends AppSettingsController {
  int toggleThemeCalls = 0;

  @override
  void toggleTheme() {
    toggleThemeCalls++;
    super.toggleTheme();
  }
}

void main() {
  setUp(() {
    App.resetForTesting();
  });

  tearDown(() {
    App.resetForTesting();
  });

  group('Example App — Isolated Testing with AppForge', () {
    test(
      'overrides controller and records navigation in pure unit test',
      () async {
        final fakeSettings = _FakeSettingsController();
        final restore = App.override<AppSettingsController>(fakeSettings);
        App.recordNavigationForTesting();

        App.find<AppSettingsController>().toggleTheme();
        await App.toNamed('/details', arguments: {'from': 'unit_test'});

        expect(fakeSettings.toggleThemeCalls, 1);
        expect(App.recordedNavigations, hasLength(1));
        expect(App.recordedNavigations.first.routeName, '/details');
        expect(App.recordedNavigations.first.arguments, {'from': 'unit_test'});

        restore();
        expect(fakeSettings.isDisposed, isTrue);
      },
    );

    testWidgets(
      'HomeScreen renders under AppTestScope with overridden controllers',
      (tester) async {
        final fakeSettings = _FakeSettingsController();

        await tester.pumpWidget(
          AppTestScope(
            overrides: [
              AppOverride<AppSettingsController>(fakeSettings),
              AppOverride<StateLabController>(StateLabController()),
              AppOverride<LifecycleLabController>(LifecycleLabController()),
            ],
            child: MasterApp(
              title: 'AppForge Test',
              translations: DemoAppTranslations(),
              initialLocale: const Locale('en', 'US'),
              home: const HomeScreen(),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('AF'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.dark_mode));
        await tester.pump();
        expect(fakeSettings.toggleThemeCalls, 1);
      },
    );
  });
}
