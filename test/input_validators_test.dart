import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:toolverse/utils/input_validators.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Full Name Formatter Tests', () {
    final formatter = NameInputFormatter(null, maxLength: 50);

    test('Accepts standard alphabetic name with spaces', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: 'Hasini Menon',
        selection: TextSelection.collapsed(offset: 12),
      );
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, 'Hasini Menon');
    });

    test('Rejects digits in "Hasini123" and preserves "Hasini"', () {
      const oldValue = TextEditingValue(
        text: 'Hasini',
        selection: TextSelection.collapsed(offset: 6),
      );
      const newValue = TextEditingValue(
        text: 'Hasini123',
        selection: TextSelection.collapsed(offset: 9),
      );
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, 'Hasini');
    });

    test('Rejects special characters like "Hasini@#"', () {
      const oldValue = TextEditingValue(
        text: 'Hasini',
        selection: TextSelection.collapsed(offset: 6),
      );
      const newValue = TextEditingValue(
        text: 'Hasini@#',
        selection: TextSelection.collapsed(offset: 8),
      );
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, 'Hasini');
    });
  });

  group('OTP Formatter Tests', () {
    final formatter = OtpDigitInputFormatter(null);

    test('Accepts single digit entry', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: '5',
        selection: TextSelection.collapsed(offset: 1),
      );
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '5');
    });

    test('Rejects alphabetic/symbol keystrokes', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: 'a',
        selection: TextSelection.collapsed(offset: 1),
      );
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '');
    });

    test('Allows multi-digit paste up to 6 digits', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: '123456',
        selection: TextSelection.collapsed(offset: 6),
      );
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '123456');
    });
  });

  group('Phone Formatter Tests', () {
    final formatter = PhoneInputFormatter(null, maxLength: 18);

    test('Accepts valid phone format with + and digits', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: '+919876543210',
        selection: TextSelection.collapsed(offset: 13),
      );
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '+919876543210');
    });

    test('Rejects letters in phone input', () {
      const oldValue = TextEditingValue(
        text: '98765',
        selection: TextSelection.collapsed(offset: 5),
      );
      const newValue = TextEditingValue(
        text: '98765abc',
        selection: TextSelection.collapsed(offset: 8),
      );
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '98765');
    });
  });

  group('Deposit Formatter Tests', () {
    final formatter = NumericAmountInputFormatter(null, maxLength: 6, maxAmount: 50000);

    test('Accepts valid deposit amount', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: '500',
        selection: TextSelection.collapsed(offset: 3),
      );
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '500');
    });

    test('Rejects negative sign and letters', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: '-500',
        selection: TextSelection.collapsed(offset: 4),
      );
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '500');
    });

    test('Clamps or rejects amount exceeding 50,000', () {
      const oldValue = TextEditingValue(
        text: '50000',
        selection: TextSelection.collapsed(offset: 5),
      );
      const newValue = TextEditingValue(
        text: '500001',
        selection: TextSelection.collapsed(offset: 6),
      );
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '50000');
    });
  });

  group('Item Name Formatter Tests', () {
    final formatter = ItemNameInputFormatter(null, maxLength: 60);

    test('Accepts "Bosch Drill 500W"', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: 'Bosch Drill 500W',
        selection: TextSelection.collapsed(offset: 16),
      );
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, 'Bosch Drill 500W');
    });

    test('Rejects prohibited punctuation like "<>"', () {
      const oldValue = TextEditingValue(
        text: 'Bosch Drill',
        selection: TextSelection.collapsed(offset: 11),
      );
      const newValue = TextEditingValue(
        text: 'Bosch Drill<script>',
        selection: TextSelection.collapsed(offset: 19),
      );
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, 'Bosch Drillscript');
    });
  });

  group('Address Formatter Tests', () {
    final formatter = AddressInputFormatter(null, maxLength: 100);

    test('Accepts "Apartment 204, Block A"', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: 'Apartment 204, Block A',
        selection: TextSelection.collapsed(offset: 22),
      );
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, 'Apartment 204, Block A');
    });

    test('Rejects prohibited symbols like "{}"', () {
      const oldValue = TextEditingValue(
        text: 'Apartment 204',
        selection: TextSelection.collapsed(offset: 13),
      );
      const newValue = TextEditingValue(
        text: 'Apartment 204 {Block A}',
        selection: TextSelection.collapsed(offset: 23),
      );
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, 'Apartment 204 Block A');
    });
  });
}
