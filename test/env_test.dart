import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:appforge/appforge.dart';

void main() {
  group('Step 13: Zero-Dependency Environment Configuration Loader (AppEnv)',
      () {
    tearDown(() {
      AppEnv.clear();
    });

    test('Parses standard KEY=VALUE pairs, comments, and export prefix', () {
      const envContent = '''
# Application Settings
APP_NAME=AppForge
APP_VERSION=1.0.0

# Server configuration
export HOST=127.0.0.1
PORT=3000 # Inline comment should be stripped
DEBUG=true
''';

      AppEnv.loadFromString(envContent);

      expect(AppEnv.get('APP_NAME'), 'AppForge');
      expect(AppEnv.get('APP_VERSION'), '1.0.0');
      expect(AppEnv.get('HOST'), '127.0.0.1');
      expect(AppEnv.getInt('PORT'), 3000);
      expect(AppEnv.getBool('DEBUG'), true);
      expect(AppEnv.contains('APP_NAME'), true);
      expect(AppEnv.contains('NON_EXISTENT'), false);
    });

    test(
        'Handles single and double quoted strings and preserves inline hashes inside quotes',
        () {
      const envContent = '''
TITLE="Welcome to AppForge #1 Framework"
TAGLINE='Zero #dependencies & high performance'
COMPLEX_EQUALS="key=value&foo=bar"
EMPTY_QUOTED=""
SINGLE_EMPTY=''
''';

      AppEnv.loadFromString(envContent);

      expect(AppEnv.get('TITLE'), 'Welcome to AppForge #1 Framework');
      expect(AppEnv.get('TAGLINE'), 'Zero #dependencies & high performance');
      expect(AppEnv.get('COMPLEX_EQUALS'), 'key=value&foo=bar');
      expect(AppEnv.get('EMPTY_QUOTED'), '');
      expect(AppEnv.get('SINGLE_EMPTY'), '');
    });

    test(
        'Expands escape sequences in double quotes and keeps them literal in single quotes',
        () {
      const envContent = r'''
ESCAPED_DOUBLE="Line 1\nLine 2\tTabbed \"Quotes\""
ESCAPED_SINGLE='Line 1\nLine 2\tTabbed'
''';

      AppEnv.loadFromString(envContent);

      expect(AppEnv.get('ESCAPED_DOUBLE'), 'Line 1\nLine 2\tTabbed "Quotes"');
      expect(AppEnv.get('ESCAPED_SINGLE'), r'Line 1\nLine 2\tTabbed');
    });

    test('Parses multi-line values enclosed in double or single quotes', () {
      const envContent = '''
CERT="-----BEGIN CERTIFICATE-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A
-----END CERTIFICATE-----"
PRIVATE_KEY='-----BEGIN RSA PRIVATE KEY-----
LINE1
LINE2
-----END RSA PRIVATE KEY-----'
REGULAR_VAR=simple_value
''';

      AppEnv.loadFromString(envContent);

      expect(
        AppEnv.get('CERT'),
        '-----BEGIN CERTIFICATE-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A\n-----END CERTIFICATE-----',
      );
      expect(
        AppEnv.get('PRIVATE_KEY'),
        '-----BEGIN RSA PRIVATE KEY-----\nLINE1\nLINE2\n-----END RSA PRIVATE KEY-----',
      );
      expect(AppEnv.get('REGULAR_VAR'), 'simple_value');
    });

    test('Performs variable interpolation with \${VAR} and \$VAR syntax', () {
      const envContent = '''
DOMAIN=api.appforge.dev
PORT=8443
BASE_URL=https://\${DOMAIN}:\${PORT}/v1
USER_ENDPOINT=\$BASE_URL/users
''';

      AppEnv.loadFromString(envContent);

      expect(AppEnv.get('DOMAIN'), 'api.appforge.dev');
      expect(AppEnv.getInt('PORT'), 8443);
      expect(AppEnv.get('BASE_URL'), 'https://api.appforge.dev:8443/v1');
      expect(AppEnv.get('USER_ENDPOINT'),
          'https://api.appforge.dev:8443/v1/users');
    });

    test(
        'Typed getters return correctly parsed primitives and default fallbacks',
        () {
      const envContent = '''
STR_VAL=hello
INT_VAL=42
DOUBLE_VAL=3.14159
BOOL_TRUE_1=true
BOOL_TRUE_2=1
BOOL_TRUE_3=yes
BOOL_TRUE_4=on
BOOL_TRUE_5=enabled
BOOL_FALSE_1=false
BOOL_FALSE_2=0
BOOL_FALSE_3=no
BOOL_FALSE_4=off
BOOL_FALSE_5=disabled
INVALID_INT=abc
INVALID_DOUBLE=xyz
''';

      AppEnv.loadFromString(envContent);

      // String getters
      expect(AppEnv.get('STR_VAL'), 'hello');
      expect(AppEnv.get('MISSING', defaultValue: 'fallback'), 'fallback');
      expect(AppEnv.getOrNull('MISSING'), null);

      // Int getters
      expect(AppEnv.getInt('INT_VAL'), 42);
      expect(AppEnv.getInt('INVALID_INT', defaultValue: 99), 99);
      expect(AppEnv.getInt('MISSING_INT', defaultValue: 10), 10);

      // Double getters
      expect(AppEnv.getDouble('DOUBLE_VAL'), 3.14159);
      expect(AppEnv.getDouble('INVALID_DOUBLE', defaultValue: 1.5), 1.5);
      expect(AppEnv.getDouble('MISSING_DOUBLE', defaultValue: 2.0), 2.0);

      // Boolean getters (truthy)
      expect(AppEnv.getBool('BOOL_TRUE_1'), true);
      expect(AppEnv.getBool('BOOL_TRUE_2'), true);
      expect(AppEnv.getBool('BOOL_TRUE_3'), true);
      expect(AppEnv.getBool('BOOL_TRUE_4'), true);
      expect(AppEnv.getBool('BOOL_TRUE_5'), true);

      // Boolean getters (falsy)
      expect(AppEnv.getBool('BOOL_FALSE_1'), false);
      expect(AppEnv.getBool('BOOL_FALSE_2'), false);
      expect(AppEnv.getBool('BOOL_FALSE_3'), false);
      expect(AppEnv.getBool('BOOL_FALSE_4'), false);
      expect(AppEnv.getBool('BOOL_FALSE_5'), false);

      // Boolean defaults
      expect(AppEnv.getBool('MISSING_BOOL', defaultValue: true), true);
      expect(AppEnv.getBool('MISSING_BOOL', defaultValue: false), false);
    });

    test('Loads from local file and respects isOptional flag', () async {
      final tempDir = Directory.systemTemp.createTempSync('appforge_env_test_');
      final envFile = File('${tempDir.path}/.env.test');
      envFile.writeAsStringSync('FILE_KEY=loaded_from_disk\nTIMEOUT=30');

      try {
        await AppEnv.load(fileName: envFile.path);
        expect(AppEnv.get('FILE_KEY'), 'loaded_from_disk');
        expect(AppEnv.getInt('TIMEOUT'), 30);

        // Missing file with isOptional: true does not crash
        await AppEnv.load(
            fileName: '${tempDir.path}/missing.env', isOptional: true);

        // Missing file with isOptional: false throws StateError
        expect(
          () => AppEnv.load(
              fileName: '${tempDir.path}/missing.env', isOptional: false),
          throwsA(isA<StateError>()),
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('loadFromMap registers and optionally overwrites environment map', () {
      AppEnv.loadFromMap({'A': '1', 'B': '2'});
      expect(AppEnv.get('A'), '1');
      expect(AppEnv.get('B'), '2');

      AppEnv.loadFromMap({'B': '20', 'C': '3'}, overwrite: true);
      expect(AppEnv.get('B'), '20');
      expect(AppEnv.get('C'), '3');

      AppEnv.loadFromMap({'C': '300'}, overwrite: false);
      expect(AppEnv.get('C'), '3'); // preserved
    });

    test('debugSummary masks sensitive keys and exposes public ones', () {
      AppEnv.loadFromMap({
        'API_KEY': 'sk_live_998877665544',
        'DATABASE_PASSWORD': 'supersecretpwd123',
        'AUTH_TOKEN': 'jwt.token.payload',
        'APP_NAME': 'MyCoolApp',
      });

      final summary = AppEnv.debugSummary();
      expect(summary.contains('AppEnv Configuration'), true);
      expect(summary.contains('APP_NAME = MyCoolApp'), true);
      expect(summary.contains('supersecretpwd123'), false); // Masked
      expect(summary.contains('sk_live_998877665544'), false); // Masked
      expect(summary.contains('****'), true);

      final masked = AppEnv.maskedMap();
      expect(masked['APP_NAME'], 'MyCoolApp');
      expect(masked['DATABASE_PASSWORD']!.contains('****'), true);
      expect(masked['DATABASE_PASSWORD']!.contains('supersecret'), false);
    });

    test('App facade integrates all AppEnv methods seamlessly', () {
      App.loadEnvFromMap({
        'BASE_URL': 'https://api.appforge.com',
        'MAX_RETRIES': '5',
        'IS_STAGING': 'true',
        'API_KEY': 'secret_123456789',
      });

      expect(App.env('BASE_URL'), 'https://api.appforge.com');
      expect(App.envOrNull('BASE_URL'), 'https://api.appforge.com');
      expect(App.envOrNull('NON_EXISTENT'), null);
      expect(App.envInt('MAX_RETRIES'), 5);
      expect(App.envBool('IS_STAGING'), true);
      expect(App.hasEnv('BASE_URL'), true);
      expect(App.hasEnv('NON_EXISTENT'), false);
      expect(App.envMap['BASE_URL'], 'https://api.appforge.com');
      expect(App.envMaskedMap['API_KEY']!.contains('****'), true);
      expect(App.envMaskedMap['API_KEY']!.contains('secret_123456789'), false);
    });

    test('Single-quoted values preserve literal dollar signs and variables',
        () {
      const envContent = '''
DEFINED_VAR=expanded_value
PASSWORD='secret\$123\${DEFINED_VAR}'
DOUBLE_QUOTED="expanded_\${DEFINED_VAR}"
''';

      AppEnv.loadFromString(envContent);

      // Single quotes must NEVER expand variables or dollar signs
      expect(AppEnv.get('PASSWORD'), r'secret$123${DEFINED_VAR}');
      // Double quotes expand variables
      expect(AppEnv.get('DOUBLE_QUOTED'), 'expanded_expanded_value');
    });

    test(
        'Undefined variables and currency dollar signs are preserved literally',
        () {
      const envContent = '''
PRICE="\$100"
NOTE="Amount: \$50 or \${UNDEFINED_TOKEN}"
''';

      AppEnv.loadFromString(envContent);

      expect(AppEnv.get('PRICE'), r'$100');
      expect(AppEnv.get('NOTE'), r'Amount: $50 or ${UNDEFINED_TOKEN}');
    });

    test(
        'Windows CRLF line endings are cleanly normalized in multi-line strings',
        () {
      const envContent =
          "HEADER=\"Line1\r\nLine2\r\nLine3\"\r\nSINGLE='Val1\r\nVal2'\r\n";

      AppEnv.loadFromString(envContent);

      expect(AppEnv.get('HEADER'), 'Line1\nLine2\nLine3');
      expect(AppEnv.get('SINGLE'), 'Val1\nVal2');
      expect(AppEnv.get('HEADER').contains('\r'), false);
      expect(AppEnv.get('SINGLE').contains('\r'), false);
    });

    test(r'Unescape regex handles \\n correctly without double-unescaping', () {
      const envContent = r'ESCAPED="\\n"';

      AppEnv.loadFromString(envContent);

      // "\\n" unescapes to "\n" (literal backslash + n), NOT a real linefeed
      expect(AppEnv.get('ESCAPED'), r'\n');
    });
  });
}
