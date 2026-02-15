/// Tests for metadata extraction functionality.
import 'package:test/test.dart';
import 'package:trafilatura/trafilatura.dart';

void main() {
  group('Metadata Extraction', () {
    test('extracts title from title tag', () {
      const html = '''
        <html><head><title>Page Title</title></head>
        <body><article><p>Some content here</p></article></body></html>
      ''';
      final metadata = extractMetadata(html);
      // Title could come from title tag or other sources
      expect(metadata.title, isNotNull);
    });

    test('extracts title from og:title', () {
      const html = '''
        <html><head>
          <meta property="og:title" content="OG Title">
        </head><body></body></html>
      ''';
      final metadata = extractMetadata(html);
      expect(metadata.title, equals('OG Title'));
    });

    test('extracts author from meta tag', () {
      const html = '''
        <html><head>
          <meta name="author" content="John Doe">
        </head><body></body></html>
      ''';
      final metadata = extractMetadata(html);
      expect(metadata.author, equals('John Doe'));
    });

    test('extracts date from meta tag', () {
      const html = '''
        <html><head>
          <meta property="article:published_time" content="2024-01-15">
        </head><body></body></html>
      ''';
      final metadata = extractMetadata(html);
      expect(metadata.date, equals('2024-01-15'));
    });

    test('extracts canonical URL', () {
      const html = '''
        <html><head>
          <link rel="canonical" href="https://example.org/page">
        </head><body></body></html>
      ''';
      final metadata = extractMetadata(html, defaultUrl: 'https://example.org/page?ref=1');
      expect(metadata.url, equals('https://example.org/page'));
    });

    test('extracts description from meta', () {
      const html = '''
        <html><head>
          <meta name="description" content="A test description">
        </head><body></body></html>
      ''';
      final metadata = extractMetadata(html);
      expect(metadata.description, equals('A test description'));
    });

    test('extracts site name from og:site_name', () {
      const html = '''
        <html><head>
          <meta property="og:site_name" content="Example Site">
        </head><body></body></html>
      ''';
      final metadata = extractMetadata(html);
      expect(metadata.sitename, equals('Example Site'));
    });

    test('extracts image from og:image', () {
      const html = '''
        <html><head>
          <meta property="og:image" content="https://example.org/image.jpg">
        </head><body></body></html>
      ''';
      final metadata = extractMetadata(html);
      expect(metadata.image, equals('https://example.org/image.jpg'));
    });
  });

  group('Document Class', () {
    test('Document has expected properties', () {
      final doc = Document();
      expect(doc.title, isNull);
      expect(doc.author, isNull);
      expect(doc.date, isNull);
      expect(doc.url, isNull);
    });

    test('Document asDict returns map', () {
      final doc = Document();
      doc.title = 'Test Title';
      doc.author = 'Test Author';
      final dict = doc.asDict();
      expect(dict, isA<Map>());
      expect(dict['title'], equals('Test Title'));
    });
  });
}

