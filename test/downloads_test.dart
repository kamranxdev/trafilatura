/// Tests for downloads functionality.
import 'package:test/test.dart';
import 'package:trafilatura/trafilatura.dart';

void main() {
  group('Fetch URL', () {
    test('fetchUrl returns Response object', () async {
      // This test would require network access
      // Skip in CI or mock the response
    }, skip: 'Requires network access');

    test('Response class has expected properties', () {
      // Response(data, status, url) - positional arguments
      final response = Response(
        '<html><body>Test</body></html>'.codeUnits,
        200,
        'https://example.org',
      );
      expect(response.data, isNotNull);
      expect(response.status, equals(200));
      expect(response.url, equals('https://example.org'));
    });

    test('Response hasData checks for content', () {
      final response = Response(
        '<html><body>Test</body></html>'.codeUnits,
        200,
        'https://example.org',
      );
      expect(response.hasData, isTrue);
      
      final emptyResponse = Response(null, 404, 'https://example.org');
      expect(emptyResponse.hasData, isFalse);
    });
  });

  group('URL Utilities', () {
    test('handles various URL formats', () {
      // Basic URL handling tests
      const url1 = 'https://example.org/page';
      const url2 = 'https://example.org/page/';
      expect(url1.replaceAll(RegExp(r'/$'), ''), equals('https://example.org/page'));
      expect(url2.replaceAll(RegExp(r'/$'), ''), equals('https://example.org/page'));
    });
  });
}

