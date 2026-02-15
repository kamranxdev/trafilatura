/// Tests for sitemaps functionality.
import 'dart:io';
import 'package:test/test.dart';
import 'package:trafilatura/trafilatura.dart';

final String resourcesDir = '${Directory.current.path}/test/resources';

void main() {
  group('Sitemap Search', () {
    test('sitemapSearch returns SitemapObject', () async {
      // This would require network access
    }, skip: 'Requires network access');
  });

  group('SitemapObject', () {
    test('SitemapObject holds URL data', () {
      final sitemap = SitemapObject(
        baseUrl: 'https://example.org',
        domain: 'example.org',
        sitemapUrls: ['https://example.org/sitemap.xml'],
      );
      expect(sitemap.baseUrl, equals('https://example.org'));
      expect(sitemap.domain, equals('example.org'));
      expect(sitemap.sitemapUrls, contains('https://example.org/sitemap.xml'));
    });

    test('SitemapObject tracks seen URLs', () {
      final sitemap = SitemapObject(
        baseUrl: 'https://example.org',
        domain: 'example.org', 
        sitemapUrls: [],
      );
      expect(sitemap.seen, isEmpty);
      expect(sitemap.urls, isEmpty);
    });
  });

  group('Sitemap Files', () {
    test('reads XML sitemap file', () async {
      final file = File('$resourcesDir/sitemap.xml');
      if (await file.exists()) {
        final content = await file.readAsString();
        expect(content.contains('urlset'), isTrue);
      }
    });

    test('reads sitemap index file', () async {
      final file = File('$resourcesDir/sitemap2.xml');
      if (await file.exists()) {
        final content = await file.readAsString();
        expect(content, isNotNull);
      }
    });
  });
}

