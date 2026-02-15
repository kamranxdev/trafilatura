/// Trafilatura - Web scraping and text extraction library.
///
/// Python & Dart tool to gather text on the Web:
/// web crawling/scraping, extraction of text, metadata, comments.
///
/// ## Usage
///
/// ```dart
/// import 'package:trafilatura/trafilatura.dart';
///
/// void main() async {
///   final html = '<html><body><article><p>Hello World</p></article></body></html>';
///   final text = extract(filecontent: html);
///   print(text); // Hello World
/// }
/// ```
library trafilatura;

// Core extraction
export 'src/core.dart' show extract, extractWithMetadata, bareExtraction;

// Baseline extraction
export 'src/baseline.dart' show baseline, html2txt;

// Downloads
export 'src/downloads.dart' show fetchUrl, fetchResponse, Response;

// Metadata extraction
export 'src/metadata.dart' show extractMetadata;

// Utilities
export 'src/utils.dart' show loadHtml;

// Settings
export 'src/settings.dart' show Extractor, Document, DefaultConfig;

// Deduplication
export 'src/deduplication.dart' show LRUCache, Simhash, duplicateTest;

// Feeds 
export 'src/feeds.dart' show findFeedUrls, extractLinks, FeedParameters;

// Sitemaps
export 'src/sitemaps.dart' show sitemapSearch, SitemapObject;

// Spider/Crawler
export 'src/spider.dart' show focusedCrawler, CrawlParameters;

// Meta functions
export 'src/meta.dart' show resetCaches;
