# API Reference

Complete API documentation for Trafilatura Dart.

## Core Functions

### extract()

Main text extraction function.

```dart
String? extract(
  dynamic htmlContent, {
  String? url,
  String outputFormat = 'txt',
  bool includeComments = false,
  bool includeTables = true,
  bool includeImages = false,
  bool includeLinks = false,
  bool includeFormatting = false,
  String? targetLanguage,
  bool deduplicate = false,
  bool fast = false,
  bool withMetadata = false,
  Extractor? config,
})
```

**Parameters:**
- `htmlContent` - HTML string, bytes, or parsed document
- `url` - Source URL for link resolution
- `outputFormat` - Output format: 'txt', 'json', 'xml', 'xmltei', 'csv'
- `includeComments` - Extract page comments
- `includeTables` - Extract table content
- `includeImages` - Include image URLs
- `includeLinks` - Include hyperlink URLs
- `includeFormatting` - Preserve text formatting
- `targetLanguage` - ISO 639-1 language code filter
- `deduplicate` - Skip duplicate content
- `fast` - Skip fallback extraction
- `withMetadata` - Include metadata in output
- `config` - Custom Extractor configuration

**Returns:** Extracted text or null if extraction fails.

### bareExtraction()

Extract content as structured object.

```dart
Document? bareExtraction(
  dynamic htmlContent, {
  String? url,
  String outputFormat = 'python',
  bool includeComments = false,
  bool includeTables = true,
  bool includeImages = false,
  bool includeLinks = false,
  bool includeFormatting = false,
  Extractor? config,
})
```

**Returns:** Document object with structured content.

### extractMetadata()

Extract metadata only.

```dart
Document? extractMetadata(
  String html, {
  String? url,
})
```

**Returns:** Document with metadata fields populated.

## Download Functions

### fetchUrl()

Download content from URL.

```dart
Future<String?> fetchUrl(
  String url, {
  Duration? timeout,
  String? userAgent,
})
```

### fetchAndExtract()

Download and extract in one step.

```dart
Future<String?> fetchAndExtract(
  String url, {
  String outputFormat = 'txt',
  bool includeComments = false,
  bool includeTables = true,
})
```

### batchDownload()

Download multiple URLs in parallel.

```dart
Future<List<DownloadResult>> batchDownload(
  List<String> urls, {
  int parallel = 4,
  Duration? timeout,
})
```

## Feed Functions

### findFeedUrls()

Find feed URLs in HTML.

```dart
List<String> findFeedUrls(String html, String baseUrl)
```

### extractFeedUrls()

Extract article URLs from feed content.

```dart
List<String> extractFeedUrls(String feedContent)
```

### isFeedContent()

Check if content is a feed.

```dart
bool isFeedContent(String content)
```

## Sitemap Functions

### getSitemapUrls()

Get possible sitemap URLs for a domain.

```dart
List<String> getSitemapUrls(String baseUrl)
```

### extractSitemapUrls()

Extract URLs from sitemap XML.

```dart
List<String> extractSitemapUrls(String sitemapContent)
```

### extractSitemapUrlsFromGzip()

Extract URLs from gzipped sitemap.

```dart
List<String> extractSitemapUrlsFromGzip(List<int> bytes)
```

### extractSitemapsFromRobots()

Find sitemap URLs in robots.txt.

```dart
List<String> extractSitemapsFromRobots(String robotsTxt)
```

### isSitemapContent() / isTextSitemap()

Check content type.

```dart
bool isSitemapContent(String content)
bool isTextSitemap(String content)
```

## Deduplication

### ContentStore

Store for duplicate detection.

```dart
class ContentStore {
  ContentStore({double threshold = 0.9});
  
  void add(String content);
  bool isDuplicate(String content);
  void clear();
}
```

### Simhash

Locality-sensitive hashing.

```dart
class Simhash {
  static int generate(String text);
  static int distance(int hash1, int hash2);
  static void clearCache();
}
```

### LRUCache

Least-recently-used cache.

```dart
class LRUCache<T> {
  LRUCache({required int maxSize});
  
  void put(String key, T value);
  T? get(String key);
  void clear();
}
```

### URL Functions

```dart
String normalizeUrl(String url);
List<String> deduplicateUrls(List<String> urls);
```

## Utility Functions

### Text Processing

```dart
String trim(String text);
String? sanitize(String? text);
String normalizeUnicode(String text);
bool textfilter(Element element);
```

### HTML Processing

```dart
Document? loadHtml(dynamic input);
bool isDubiousHtml(String input);
String repairFaultyHtml(String html, String beginning);
```

### URL Utilities

```dart
bool isValidUrl(String url);
bool isImageFile(String url);
List<String> detectEncoding(List<int> bytes);
String decodeResponse(List<int> bytes);
```

## Classes

### Document

Represents extracted content and metadata.

```dart
class Document {
  String? title;
  String? author;
  String? date;
  String? url;
  String? hostname;
  String? description;
  String? sitename;
  String? image;
  List<String>? categories;
  List<String>? tags;
  String? license;
  String? pagetype;
  String? text;
  String? comments;
  String? raw_text;
  String? fingerprint;
  String? language;
  String? id;
  
  // Body elements (XML)
  XmlElement? body;
  XmlElement? commentsbody;
  
  Map<String, dynamic> asDict();
}
```

### Extractor

Configuration for extraction.

```dart
class Extractor {
  Extractor({
    String? source,
    int? minOutputSize,
    int? minExtractedSize,
    bool includeComments = false,
    bool includeTables = true,
    bool includeImages = false,
    bool includeLinks = false,
    bool includeFormatting = false,
    // ... additional options
  });
}
```

### DownloadResult

Result from batch download.

```dart
class DownloadResult {
  final String url;
  final String? content;
  final String? error;
  final int statusCode;
}
```

### UrlFilter

Filter URLs by pattern.

```dart
class UrlFilter {
  UrlFilter({List<String> patterns = const []});
  
  List<String> apply(List<String> urls);
}
```

## Constants

### DefaultConfig

Default configuration values.

```dart
class DefaultConfig {
  static const int minOutputSize = 75;
  static const int minExtractedSize = 200;
  static const int minOutputCommSize = 30;
  // ... more defaults
}
```

## Exceptions

The library uses standard Dart exceptions:
- `ArgumentError` - Invalid input arguments
- `FormatException` - Invalid HTML/XML format
- `HttpException` - Download failures
