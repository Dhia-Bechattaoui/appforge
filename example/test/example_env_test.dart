import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:appforge/appforge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Example App .env File Integration', () {
    test(
      'App.loadEnv parses example/.env directly from filesystem / assets',
      () async {
        // Load the .env file created in the example project
        final envFile = File('.env');
        expect(envFile.existsSync(), true, reason: 'example/.env must exist');

        await App.loadEnv(fileName: '.env');

        // Verify loaded values
        expect(App.env('APP_NAME'), 'AppForge Studio');
        expect(App.env('APP_ENV'), 'production');
        expect(App.env('APP_VERSION'), '1.3.0');

        // Verify variable interpolation (${API_HOST}:${API_PORT})
        expect(App.env('API_HOST'), 'api.appforge.dev');
        expect(App.envInt('API_PORT'), 443);
        expect(App.env('API_BASE_URL'), 'https://api.appforge.dev:443/v1');

        // Verify typed primitives
        expect(App.envInt('API_TIMEOUT_SEC'), 15);
        expect(App.envBool('FEATURE_ANALYTICS'), true);
        expect(App.envBool('FEATURE_BETA_UI'), false);

        // Verify automatic secret masking
        expect(App.hasEnv('API_SECRET_KEY'), true);
        expect(App.env('API_SECRET_KEY'), 'forge_sec_9948201849182049182');
        expect(
          App.envMaskedMap['API_SECRET_KEY']!.contains(
            'forge_sec_9948201849182049182',
          ),
          false,
        );
        expect(
          App.envMaskedMap['DATABASE_PASSWORD']!.contains('secretPass123'),
          false,
        );
        expect(App.envMaskedMap['DATABASE_PASSWORD']!.contains('****'), true);
      },
    );
  });
}
