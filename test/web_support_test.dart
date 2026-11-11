import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appforge/appforge.dart';

class _TestXorCodec extends AppStorageCodec {
  final int mask;
  const _TestXorCodec(this.mask);

  @override
  List<int> encode(List<int> bytes) => <int>[for (final b in bytes) b ^ mask];

  @override
  List<int> decode(List<int> bytes) => <int>[for (final b in bytes) b ^ mask];
}

class _WebCounterController extends AppController {
  final count = 0.obs;
}

class _WebTranslations extends AppTranslations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en': {'hello': 'Hello @name'},
        'ar': {'hello': 'مرحبا @name'},
      };
}

void main() {
  setUp(() {
    App.resetForTesting();
  });

  tearDown(() {
    App.resetForTesting();
  });

  group('Web & Cross-Platform Compatibility', () {
    testWidgets(
        'MasterApp, Watch, BiDi localization, and navigation work cleanly',
        (tester) async {
      await tester.pumpWidget(
        AppTestScope(
          overrides: [
            AppOverride<_WebCounterController>(_WebCounterController())
          ],
          child: MasterApp(
            translations: _WebTranslations(),
            initialLocale: const Locale('ar'),
            home: Scaffold(
              body: Watch((_) {
                final ctrl = App.find<_WebCounterController>();
                return Text(
                  '${'hello'.trParams({
                        'name': 'Flutter'
                      })}:${ctrl.count.value}',
                );
              }),
            ),
          ),
        ),
      );

      expect(find.textContaining('مرحبا'), findsOneWidget);
      expect(find.textContaining(':0'), findsOneWidget);

      App.find<_WebCounterController>().count.value = 7;
      await tester.pump();
      expect(find.textContaining(':7'), findsOneWidget);
    });

    test('AppConnectivity.checkConnection completes without dart:io errors',
        () async {
      AppConnectivity.instance.customChecker = () async => true;
      expect(await App.checkConnectivity(), isTrue);

      AppConnectivity.instance.customChecker = null;
      // On Web this probes window.navigator.onLine; on VM it checks hosts.
      final result = await App.checkConnectivity();
      expect(result, isA<bool>());
    });

    test('AppStorage works on Web localStorage and respects AppStorageCodec',
        () async {
      // Only run auto-path init when on Web or when temp fallback is allowed.
      const codec = _TestXorCodec(0x33);
      final storage = await App.initStorage(
        container: 'web_compat_box',
        allowTempFallback: true,
        codec: codec,
      );

      storage.write('theme', 'dark');
      storage.write('count', 12);
      await storage.save();

      AppStorage.resetMemoryCacheOnly();

      final reloaded = await App.initStorage(
        container: 'web_compat_box',
        allowTempFallback: true,
        codec: codec,
      );
      expect(reloaded.read<String>('theme'), 'dark');
      expect(reloaded.read<int>('count'), 12);
    });
  });
}
