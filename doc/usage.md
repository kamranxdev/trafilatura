# Usage Guide

Complete guide to using Trafilatura Dart.

## Library Usage

### Basic Extraction

```dart
import 'package:trafilatura/trafilatura.dart';

// Simple extraction
final text = extract(htmlString);

// With URL context (helps with link resolution)
final text = extract(htmlString, url: 'https://example.org/page');
```

### Bare Extraction (Structured Output)

```dart
final result = bareExtraction(htmlString);

// Access individual fields
print(result.text);         // Main content
print(result.title);        // Page title
print(result.author);       // Author name
print(result.date);         // Publication date
print(result.url);          // Canonical URL
print(result.hostname);     // Domain name
print(result.description);  // Meta description
print(result.categories);   // Content categories
print(result.tags);         // Content tags
print(result.image);        // Main image URL
print(result.comments);     // Comments text (if extracted)

// Convert to Map
final map = result.asDict();
```

### Extraction Options

```dart
final text = extract(
  html,
  url: 'https://example.org',
  outputFormat: 'txt',           // txt, json, xml, xmltei, csv
  includeComments: false,        // Extract comments
  includeTables: true,           // Extract tables
  includeImages: false,          // Extract image URLs
  includeLinks: false,           // Extract link URLs
  includeFormatting: false,      // Preserve formatting
  targetLanguage: null,          // Filter by language (e.g., 'en')
  deduplicate: false,            // Skip duplicate content
  fast: false,                   // Fast mode (skip fallbacks)
  withMetadata: false,           // Include metadata in output
);
```

### Custom Configuration

```dart
final config = Extractor(
  minOutputSize: 100,        // Minimum text length
  minExtractedSize: 50,      // Minimum extraction length
  includeComments: true,
  includeTables: true,
  includeFormatting: true,
  includeImages: true,
  includeLinks: true,
);

final text = extract(html, config: config);
```

## Downloading Content

### Single URL

```dart
// Simple download and extract
final content = await fetchAndExtract('https://example.org');

// Just download (returns HTML)
final html = await fetchUrl('https://example.org');
if (html != null) {
  final text = extract(html);
}
```

### Batch Downloads

```dart
final urls = [
  'https://example.org/page1',
  'https://example.org/page2',
  'https://example.org/page3',
];

// Download with parallel processing
final results = await batchDownload(urls, parallel: 4);

for (final result in results) {
  print('URL: ${result.url}');
  print('Content: ${result.content}');
}
```

### Download Options

```dart
final html = await fetchUrl(
  'https://example.org',
  timeout: Duration(seconds: 30),
  userAgent: 'MyBot/1.0',
);
```

## Feed Discovery

### Find Feed URLs

```dart
// Find feeds in HTML page
final feeds = findFeedUrls(html, 'https://example.org');
for (final feed in feeds) {
  print(feed); // Feed URL
}
```

### Extract from Feed

```dart
// Parse feed content
final urls = extractFeedUrls(feedContent);
for (final url in urls) {
  print(url); // Article URL from feed
}
```

### Detect Feed Type

```dart
if (isFeedContent(content)) {
  print('This is a feed!');
}
```

## Sitemap Processing

### Discover Sitemaps

```dart
// Get possible sitemap URLs
final sitemapUrls = getSitemapUrls('https://example.org');
// Returns: [sitemap.xml, sitemap_index.xml, sitemap-news.xml, ...]
```

### Parse Sitemap

```dart
// Extract URLs from sitemap
final urls = extractSitemapUrls(sitemapContent);
for (final url in urls) {
  print(url);
}

// Handle gzipped sitemaps
final urls = extractSitemapUrlsFromGzip(gzippedBytes);
```

### Parse robots.txt

```dart
final sitemaps = extractSitemapsFromRobots(robotsTxtContent);
```

## Deduplication

### Content Store

```dart
final store = ContentStore(threshold: 0.9);

// Check and add content
if (!store.isDuplicate(content)) {
  store.add(content);
  processContent(content);
}
```

### URL Deduplication

```dart
final uniqueUrls = deduplicateUrls(urlList);
```

### Simhash

```dart
// Generate hash for content
final hash = Simhash.generate(text);

// Compare two hashes
final distance = Simhash.distance(hash1, hash2);
if (distance < 5) {
  print('Nearly identical content');
}
```

## Metadata Extraction

### Extract All Metadata

```dart
final metadata = extractMetadata(html, url: 'https://example.org');

if (metadata != null) {
  print('Title: ${metadata.title}');
  print('Author: ${metadata.author}');
  print('Date: ${metadata.date}');
  print('URL: ${metadata.url}');
  print('Hostname: ${metadata.hostname}');
  print('Description: ${metadata.description}');
  print('Site Name: ${metadata.sitename}');
  print('Image: ${metadata.image}');
  print('Categories: ${metadata.categories}');
  print('Tags: ${metadata.tags}');
  print('License: ${metadata.license}');
  print('Page Type: ${metadata.pagetype}');
}
```

## Utility Functions

### HTML Validation

```dart
// Check if input looks like HTML
if (isDubiousHtml(input)) {
  print('Not valid HTML');
}
```

### Encoding Detection

```dart
final encodings = detectEncoding(bytes);
print('Detected: $encodings');
```

### Text Processing

```dart
// Trim whitespace
final cleaned = trim('  text  ');

// Normalize Unicode
final normalized = normalizeUnicode(text);

// Sanitize text
final safe = sanitize(text);
```

### URL Utilities

```dart
// Validate URL
if (isValidUrl(url)) {
  print('Valid URL');
}

// Check if image URL
if (isImageFile(url)) {
  print('Image URL');
}

// Normalize URL
final normalized = normalizeUrl(url);
```

## Error Handling

```dart
try {
  final text = extract(html);
  if (text == null) {
    print('No content extracted');
  }
} catch (e) {
  print('Extraction failed: $e');
}
```

## Performance Tips

1. **Use fast mode** for large batches:
   ```dart
   final text = extract(html, fast: true);
   ```

2. **Enable deduplication** to skip repetitive content:
   ```dart
   final store = ContentStore();
   // Check before processing
   ```

3. **Process in parallel** for batch operations:
   ```dart
   final results = await batchDownload(urls, parallel: 8);
   ```

4. **Reuse configuration** objects:
   ```dart
   final config = Extractor(...);
   for (final html in documents) {
     extract(html, config: config);
   }
   ```
