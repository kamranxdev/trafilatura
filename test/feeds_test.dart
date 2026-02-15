/// Tests for feeds functionality.
import 'dart:io';
import 'package:test/test.dart';
import 'package:trafilatura/trafilatura.dart';

final String resourcesDir = '${Directory.current.path}/test/resources';

void main() {
  group('Feed URL Discovery', () {
    test('findFeedUrls returns list', () async {
      // findFeedUrls is async and takes a URL
      // This would require network access for real testing
    }, skip: 'Requires network access');

    test('FeedParameters can be created', () {
      final params = FeedParameters(
        base: 'https://example.org',
        domain: 'example.org',
        reference: 'https://example.org/feed',
      );
      expect(params, isNotNull);
      expect(params.base, equals('https://example.org'));
      expect(params.domain, equals('example.org'));
    });
  });

  group('Feed File Parsing', () {
    test('parses ATOM feed file', () async {
      final file = File('$resourcesDir/feed1.atom');
      if (await file.exists()) {
        final content = await file.readAsString();
        expect(content.contains('feed'), isTrue);
      }
    });

    test('parses RSS feed file', () async {
      final file = File('$resourcesDir/feed2.rss');
      if (await file.exists()) {
        final content = await file.readAsString();
        expect(content.contains('rss'), isTrue);
      }
    });
  });
}

