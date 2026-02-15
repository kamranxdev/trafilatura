// ignore_for_file: avoid_print
/// Example demonstrating the main features of the trafilatura package.
///
/// This example shows how to:
/// - Extract text content from HTML
/// - Extract text with metadata
/// - Use different output formats (plain text, JSON, XML)
/// - Download and extract content from a URL
/// - Discover feed URLs
library;

import 'package:trafilatura/trafilatura.dart';

void main() async {
  // ── 1. Basic text extraction from HTML ──────────────────────────
  const html = '''
  <html>
    <head><title>Example Article</title></head>
    <body>
      <nav>Navigation menu</nav>
      <article>
        <h1>Breaking News</h1>
        <p>This is the main content of the article. It contains
        important information that readers want to see.</p>
        <p>Trafilatura automatically removes boilerplate content
        like navigation, footers, and ads.</p>
      </article>
      <footer>Copyright 2026</footer>
    </body>
  </html>
  ''';

  final text = extract(filecontent: html);
  print('=== Basic Extraction ===');
  print(text);
  print('');

  // ── 2. Extract with metadata ────────────────────────────────────
  final doc = extractWithMetadata(
    filecontent: html,
    url: 'https://example.com/article',
  );
  if (doc != null) {
    print('=== With Metadata ===');
    print('Title: ${doc.title}');
    print('Text: ${doc.text}');
    print('');
  }

  // ── 3. JSON output format ──────────────────────────────────────
  final jsonOutput = extract(
    filecontent: html,
    outputFormat: 'json',
    withMetadata: true,
    url: 'https://example.com/article',
  );
  print('=== JSON Output ===');
  print(jsonOutput);
  print('');

  // ── 4. Extract with options ────────────────────────────────────
  final formatted = extract(
    filecontent: html,
    includeFormatting: true,
    includeLinks: true,
    includeComments: false,
  );
  print('=== Formatted Output ===');
  print(formatted);
  print('');

  // ── 5. Download and extract from a URL ─────────────────────────
  final response = await fetchUrl('https://example.com');
  if (response != null) {
    final extracted = extract(filecontent: response);
    print('=== From URL ===');
    print(extracted);
  }
}
