import 'package:condominio/utils/token_redaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('redactTokenForLog', () {
    test('null e stringa vuota', () {
      expect(redactTokenForLog(null), '(null)');
      expect(redactTokenForLog(''), '(empty)');
    });

    test('token corto non lancia e non espone il valore', () {
      expect(redactTokenForLog('abc'), '***');
      expect(redactTokenForLog('abcdefgh'), '***');
    });

    test('lunghezza intermedia', () {
      expect(redactTokenForLog('abcdefghij'), 'abcd…(10)');
      expect(
        redactTokenForLog('abcdefghijklmnopqrst'),
        'abcd…(20)',
      );
    });

    test('token lungo mostra prefisso e suffisso', () {
      const long =
          'abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJ';
      expect(
        redactTokenForLog(long),
        'abcdefghijklmnopqrst…ABCDEFGHIJ',
      );
    });

    test('oggetti non-stringa usano toString()', () {
      expect(redactTokenForLog(12345), '***');
    });
  });
}
