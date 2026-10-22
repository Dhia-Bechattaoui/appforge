import 'package:flutter_test/flutter_test.dart';
import 'package:appforge/appforge.dart';

void main() {
  group('String Validators & Extensions (AppValidationExtension)', () {
    test('isValidEmail validates email formats correctly', () {
      expect('user@example.com'.isValidEmail, isTrue);
      expect('john.doe+test@domain.co.uk'.isValidEmail, isTrue);
      expect('invalid-email'.isValidEmail, isFalse);
      expect('user@'.isValidEmail, isFalse);
      expect('@domain.com'.isValidEmail, isFalse);
      expect(''.isValidEmail, isFalse);
      expect('   '.isValidEmail, isFalse);
    });

    test('isValidPhone validates international and local phone numbers', () {
      expect('+974 5500 1234'.isValidPhone, isTrue);
      expect('+1-800-555-0199'.isValidPhone, isTrue);
      expect('0501234567'.isValidPhone, isTrue);
      expect('+٩٧٤ ٥٥٠٠ ١٢٣٤'.isValidPhone, isTrue); // Arabic-Indic digits
      expect('٠٥٠١٢٣٤٥٦٧'.isValidPhone, isTrue);
      expect('123'.isValidPhone, isFalse); // too short (< 7)
      expect('not-a-number'.isValidPhone, isFalse);
      expect(''.isValidPhone, isFalse);
    });

    test('hasMinLength and hasMaxLength validate string bounds', () {
      expect('password123'.hasMinLength(8), isTrue);
      expect('short'.hasMinLength(8), isFalse);
      expect('short'.hasMaxLength(10), isTrue);
      expect('very-long-string-exceeding-limit'.hasMaxLength(10), isFalse);
    });

    test('isNumeric checks whether string is purely numeric', () {
      expect('12345'.isNumeric, isTrue);
      expect('-42.5'.isNumeric, isTrue);
      expect('١٢٣٤٥'.isNumeric, isTrue); // Arabic-Indic digits
      expect('-٤٢.٥'.isNumeric, isTrue);
      expect('٤٢٫٥'.isNumeric, isTrue); // Arabic decimal separator
      expect('123abc'.isNumeric, isFalse);
      expect(''.isNumeric, isFalse);
      expect('NaN'.isNumeric, isFalse);
      expect('Infinity'.isNumeric, isFalse);
      expect('-Infinity'.isNumeric, isFalse);
      expect('1e5'.isNumeric, isFalse);
    });

    test('capitalizeFirst capitalizes the first character', () {
      expect('flutter'.capitalizeFirst, equals('Flutter'));
      expect('F'.capitalizeFirst, equals('F'));
      expect(''.capitalizeFirst, equals(''));
    });

    test('toArabicDigits converts 0-9 to Eastern Arabic-Indic digits ٠-٩', () {
      expect('12345'.toArabicDigits, equals('١٢٣٤٥'));
      expect('Phone: +974 5500 1234'.toArabicDigits,
          equals('Phone: +٩٧٤ ٥٥٠٠ ١٢٣٤'));
    });

    test('toWesternDigits converts ٠-٩ to Western Arabic digits 0-9', () {
      expect('١٢٣٤٥'.toWesternDigits, equals('12345'));
      expect('هاتف: ٥٥٠٠'.toWesternDigits, equals('هاتف: 5500'));
    });
  });
}
