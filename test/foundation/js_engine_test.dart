import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/foundation/js_engine.dart';

void main() {
  test('read-only source retry recognizes JavaScript syntax errors', () {
    expect(
      JsEngine.debugIsRetryableReadSyntaxError(
        Exception('SyntaxError: unexpected token < in JSON'),
      ),
      isTrue,
    );
    expect(
      JsEngine.debugIsRetryableReadSyntaxError(
        Exception('JSException: Syntax error: unexpected end of input'),
      ),
      isTrue,
    );
  });

  test('read-only source retry ignores unrelated failures', () {
    expect(
      JsEngine.debugIsRetryableReadSyntaxError(
        Exception('Connection timed out'),
      ),
      isFalse,
    );
    expect(
      JsEngine.debugIsRetryableReadSyntaxError(
        Exception('Invalid Status Code: 403'),
      ),
      isFalse,
    );
  });
}
