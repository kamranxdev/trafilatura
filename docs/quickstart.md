# Quick Start Guide

Get started with Trafilatura Dart in minutes.

## Basic Usage

### Extract text from HTML

```dart
import 'package:trafilatura/trafilatura.dart';

void main() {
  const html = '''
    <html>
      <head><title>My Article</title></head>
      <body>
        <header><nav>Navigation menu</nav></header>
        <article>
          <h1>Welcome to My Article</h1>
          <p>This is the main content of the article.</p>
          <p>It contains important information.</p>
        </article>
        <footer>Copyright 2024</footer>
      </body>
    </html>
  ''';
  
  final text = extract(html);
  print(text);
  // Output: Welcome to My Article
  // This is the main content of the article.
  // It contains important information.
}
```

### Download and extract from URL

```dart
import 'package:trafilatura/trafilatura.dart';

void main() async {
  final content = await fetchAndExtract('https://example.org');
  print(content);
}
```

### Extract metadata

```dart
import 'package:trafilatura/trafilatura.dart';

void main() {
  const html = '''
    <html>
      <head>
        <title>Article Title</title>
        <meta name="author" content="John Doe">
        <meta name="description" content="A great article">
      </head>
      <body><article><p>Content here</p></article></body>
    </html>
  ''';
  
  final metadata = extractMetadata(html);
  print('Title: ${metadata?.title}');
  print('Author: ${metadata?.author}');
  print('Description: ${metadata?.description}');
}
```

## Output Formats

### Plain text (default)

```dart
final text = extract(html);
```

### JSON

```dart
final json = extract(html, outputFormat: 'json');
// Returns JSON string with text and metadata
```

### XML

```dart
final xml = extract(html, outputFormat: 'xml');
// Returns XML document
```

### XML-TEI

```dart
final tei = extract(html, outputFormat: 'xmltei');
// Returns TEI-compliant XML
```

### CSV

```dart
final csv = extract(html, outputFormat: 'csv');
// Returns tab-separated values
```

## Including Optional Elements

### With formatting

```dart
final result = extract(html, includeFormatting: true);
```

### With links

```dart
final result = extract(html, includeLinks: true, outputFormat: 'xml');
```

### With images

```dart
final result = extract(html, includeImages: true, outputFormat: 'xml');
```

### With tables

```dart
final result = extract(html, includeTables: true);
```

### With comments

```dart
final result = extract(html, includeComments: true);
```

## Command-Line Quick Start

### Extract from URL

```bash
trafilatura -u https://example.org
```

### Extract from file

```bash
trafilatura -i article.html
```

### Save output

```bash
trafilatura -u https://example.org -o output.txt
```

### JSON output

```bash
trafilatura -u https://example.org --output-format json
```

### With formatting and links

```bash
trafilatura -u https://example.org --formatting --links
```

## Next Steps

- [Usage Guide](usage.md) - Detailed usage instructions
- [CLI Reference](cli.md) - Full command-line options
- [API Reference](api.md) - Complete API documentation
