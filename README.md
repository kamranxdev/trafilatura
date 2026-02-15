# Trafilatura Dart: Discover and Extract Text Data on the Web

<br/>

<img alt="Trafilatura Logo" src="https://raw.githubusercontent.com/adbar/trafilatura/master/docs/trafilatura-logo.png" align="center" width="60%"/>

<br/>

[![Dart Package](https://img.shields.io/pub/v/trafilatura.svg)](https://pub.dev/packages/trafilatura)
[![Dart SDK](https://img.shields.io/badge/Dart-%3E%3D3.0.0-blue.svg)](https://dart.dev/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

<br/>


## Introduction

Trafilatura Dart is a cutting-edge **Dart package and command-line tool**
designed to **gather text on the Web and simplify the process of turning
raw HTML into structured, meaningful data**. It includes all necessary
discovery and text processing components to perform **web crawling,
downloads, scraping, and extraction** of main texts, metadata and
comments.

This is a **Dart port** of the popular Python [trafilatura](https://github.com/adbar/trafilatura) library, migrated by [kamranxdev](https://github.com/kamranxdev) (Kamran Khan).


### Features

- Advanced web crawling and text discovery:
   - Support for sitemaps (TXT, XML) and feeds (ATOM, JSON, RSS)
   - Smart crawling and URL management (filtering and deduplication)

- Parallel processing of online and offline input:
   - Live URLs, efficient and polite processing of download queues
   - Previously downloaded HTML files and parsed HTML trees

- Robust and configurable extraction of key elements:
   - Main text (common patterns and generic algorithms)
   - Metadata (title, author, date, site name, categories and tags)
   - Formatting and structure: paragraphs, titles, lists, quotes, code, line breaks
   - Optional elements: comments, links, images, tables

- Multiple output formats:
   - TXT and Markdown
   - CSV
   - JSON
   - HTML, XML and XML-TEI

- Actively maintained Dart implementation:
   - Compatible with Dart 3.0+ and Flutter
   - Null-safe code


## Platform Support

Trafilatura Dart works across all Dart and Flutter platforms:

### ✅ Fully Supported Platforms

| Platform | Status | Notes |
|----------|--------|-------|
| **Dart VM** | ✅ Full support | All features available |
| **Flutter Android** | ✅ Full support | Mobile web scraping |
| **Flutter iOS** | ✅ Full support | Mobile web scraping |
| **Flutter Web** | ✅ Full support | Browser-based extraction |
| **Flutter Desktop (Windows)** | ✅ Full support | Native desktop apps |
| **Flutter Desktop (macOS)** | ✅ Full support | Native desktop apps |
| **Flutter Desktop (Linux)** | ✅ Full support | Native desktop apps |
| **Command-line** | ✅ Full support | Via `dart pub global activate` |

### 📦 Dependency Platform Support

All dependencies are pure Dart packages with full cross-platform support:

| Package | Version | Platforms | Purpose |
|---------|---------|-----------|----------|
| [`html`](https://pub.dev/packages/html) | ^0.15.4 | All platforms | HTML parsing and DOM manipulation |
| [`xml`](https://pub.dev/packages/xml) | ^6.4.0 | All platforms | XML generation and parsing |
| [`http`](https://pub.dev/packages/http) | ^1.1.0 | All platforms | HTTP client for web requests |
| [`crypto`](https://pub.dev/packages/crypto) | ^3.0.3 | All platforms | Hashing (Simhash, MD5) |
| [`charset`](https://pub.dev/packages/charset) | ^2.0.1 | All platforms | Character encoding detection |
| [`intl`](https://pub.dev/packages/intl) | ^0.18.1 | All platforms | Date parsing & formatting |
| [`args`](https://pub.dev/packages/args) | ^2.4.2 | All platforms | CLI argument parsing |
| [`convert`](https://pub.dev/packages/convert) | ^3.1.1 | All platforms | Data encoding/decoding |
| [`collection`](https://pub.dev/packages/collection) | ^1.18.0 | All platforms | Collection utilities |
| [`path`](https://pub.dev/packages/path) | ^1.8.3 | All platforms | File path manipulation |

**Note**: No platform-specific or native dependencies required. The package works identically across all platforms.


## Installation

### As a dependency

Add to your `pubspec.yaml`:

```yaml
dependencies:
  trafilatura: ^1.0.0
```

Then run:

```bash
dart pub get
```

### Global CLI installation

```bash
dart pub global activate trafilatura
```


## Usage

### As a Dart library

```dart
import 'package:trafilatura/trafilatura.dart';

void main() async {
  // Extract text from HTML string
  const html = '''
    <html>
      <body>
        <article>
          <h1>Article Title</h1>
          <p>This is the main content of the article.</p>
        </article>
      </body>
    </html>
  ''';
  
  final text = extract(html);
  print(text);
  
  // Extract with options
  final result = extract(
    html,
    includeFormatting: true,
    includeLinks: true,
    includeImages: true,
    outputFormat: 'xml',
  );
  
  // Extract metadata
  final metadata = extractMetadata(html);
  print('Title: ${metadata?.title}');
  print('Author: ${metadata?.author}');
  
  // Download and extract from URL
  final content = await fetchAndExtract('https://example.org');
  print(content);
}
```

### Bare extraction (returns structured data)

```dart
final result = bareExtraction(html);
print(result.text);
print(result.title);
print(result.author);
print(result.date);
```

### Output formats

```dart
// Plain text (default)
final text = extract(html);

// JSON output
final json = extract(html, outputFormat: 'json');

// XML output
final xml = extract(html, outputFormat: 'xml');

// XML-TEI output
final tei = extract(html, outputFormat: 'xmltei');

// CSV output
final csv = extract(html, outputFormat: 'csv');
```

### Command-line usage

```bash
# Extract from URL
trafilatura -u https://example.org

# Extract from file
trafilatura -i input.html

# Process directory
trafilatura --input-dir ./pages --output-dir ./output

# Include formatting
trafilatura -u https://example.org --formatting --links

# Output as JSON
trafilatura -u https://example.org -f json

# Discover feed URLs
trafilatura --feed https://example.org

# Discover sitemap URLs
trafilatura --sitemap https://example.org

# Crawl website
trafilatura --crawl https://example.org --limit 100
```

### CLI Options

```
-i, --input-file         Name of input file for batch processing
    --input-dir          Read files from a specified directory
-u, --URL                Custom URL download
    --parallel           Number of parallel downloads (default: 4)
-o, --output-dir         Write results to specified directory
    --feed               Look for feeds and/or pass a feed URL
    --sitemap            Look for sitemaps for the given website
    --crawl              Crawl a fixed number of pages
-f, --fast               Fast extraction without fallback
    --formatting         Include text formatting
    --links              Include links with targets
    --images             Include image sources
    --no-comments        Don't output comments
    --no-tables          Don't output table elements
    --target-language    Target language (ISO 639-1 code)
    --output-format      Output format (txt, json, xml, xmltei, csv)
```


## Feed and Sitemap Discovery

```dart
// Find feed URLs in HTML
final feeds = findFeedUrls(html, baseUrl);

// Extract URLs from feed
final feedUrls = extractFeedUrls(feedContent);

// Find sitemap URLs
final sitemaps = getSitemapUrls('https://example.org');

// Extract URLs from sitemap
final urls = extractSitemapUrls(sitemapContent);
```


## Deduplication

```dart
// Content store for duplicate detection
final store = ContentStore(threshold: 0.9);

store.add('Content of first document');

if (store.isDuplicate('Similar content')) {
  print('Duplicate detected');
}

// URL deduplication
final uniqueUrls = deduplicateUrls(urlList);
```


## Configuration

```dart
// Use custom configuration
final config = Extractor(
  minOutputSize: 100,
  minExtractedSize: 50,
  includeComments: true,
  includeTables: true,
  includeFormatting: true,
);

final result = extract(html, config: config);
```


## Running Tests

```bash
# Run all tests
dart test

# Run specific test file
dart test test/unit_test.dart

# Run with coverage
dart test --coverage=coverage
```


## Development

```bash
# Get dependencies
dart pub get

# Analyze code
dart analyze

# Format code
dart format lib/ bin/ test/

# Run the CLI
dart run bin/trafilatura.dart --help
```


## License

This package is distributed under the [Apache 2.0 license](https://www.apache.org/licenses/LICENSE-2.0.html).


## Contributing

Contributions of all kinds are welcome! Please read the
[Contributing guide](CONTRIBUTING.md) for more information.


## Dart Port

This Dart port was created and is maintained by [kamranxdev](https://github.com/kamranxdev) (Kamran Khan).

The port migrates the original Python implementation to Dart, leveraging Dart-native packages and idioms while preserving the core extraction algorithms and functionality.

### Key Dart Dependencies

| Package | Purpose |
|---------|---------|
| [`html`](https://pub.dev/packages/html) | HTML parsing |
| [`xml`](https://pub.dev/packages/xml) | XML generation and parsing |
| [`http`](https://pub.dev/packages/http) | HTTP client for downloads |
| [`crypto`](https://pub.dev/packages/crypto) | Hashing for deduplication |
| [`args`](https://pub.dev/packages/args) | Command-line argument parsing |
| [`intl`](https://pub.dev/packages/intl) | Internationalization |
| [`charset`](https://pub.dev/packages/charset) | Character encoding detection |


## Original Project

Based on the original Python trafilatura library by Adrien Barbaresi:
- [GitHub Repository](https://github.com/adbar/trafilatura)
- [Documentation](https://trafilatura.readthedocs.io/)


## Citation

If you use this library in academic work, please cite the original paper and this Dart port:

```bibtex
@inproceedings{barbaresi-2021-trafilatura,
  title = {{Trafilatura: A Web Scraping Library and Command-Line Tool for Text Discovery and Extraction}},
  author = "Barbaresi, Adrien",
  booktitle = "Proceedings of the Joint Conference of the 59th Annual Meeting of the Association for Computational Linguistics",
  pages = "122--131",
  publisher = "Association for Computational Linguistics",
  url = "https://aclanthology.org/2021.acl-demo.15",
  year = 2021,
}
```

```bibtex
@software{khan-trafilatura-dart,
  title = {{Trafilatura Dart: A Dart Port of Trafilatura}},
  author = "Khan, Kamran",
  url = "https://github.com/kamranxdev/trafilatura",
  year = 2026,
  version = {1.0.0},
}
```
