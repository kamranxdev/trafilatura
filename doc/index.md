# Trafilatura Dart Documentation

<img alt="Trafilatura Logo" src="trafilatura-logo.png" align="center" width="40%"/>

Welcome to the documentation for **Trafilatura Dart**, a powerful library for web scraping, text extraction, and metadata extraction from HTML documents.

This is a Dart port of the original Python [trafilatura](https://github.com/adbar/trafilatura) library, migrated by [kamranxdev](https://github.com/kamranxdev) (Kamran Khan).

## Quick Links

- [Quick Start Guide](quickstart.md) - Get started in minutes
- [Installation](installation.md) - Installation instructions
- [Usage Guide](usage.md) - Comprehensive usage guide
- [CLI Reference](cli.md) - Command-line interface reference
- [API Reference](api.md) - Complete API documentation

## What is Trafilatura?

Trafilatura is designed to **gather text on the Web and simplify the process of turning raw HTML into structured, meaningful data**. It includes all necessary discovery and text processing components to perform:

- **Web crawling** - Automatically discover and follow links
- **Downloads** - Efficiently fetch web pages
- **Scraping** - Parse and process HTML content
- **Extraction** - Extract main text, metadata, and comments

## Features

### Text Extraction
- Main content extraction with boilerplate removal
- Comment and sidebar extraction
- Table and list handling
- Formatting preservation (bold, italic, etc.)

### Metadata Extraction
- Title, author, date
- Description, site name
- Categories, tags
- Open Graph and Schema.org support

### Discovery
- RSS/Atom/JSON feed parsing
- XML sitemap processing
- robots.txt parsing
- Website crawling

### Output Formats
- Plain text
- JSON
- XML
- XML-TEI (scholarly standard)
- CSV

### Deduplication
- Content fingerprinting (Simhash)
- Near-duplicate detection
- URL normalization

## Installation

```yaml
dependencies:
  trafilatura: ^1.0.0
```

```bash
dart pub get
```

## Basic Usage

```dart
import 'package:trafilatura/trafilatura.dart';

// Extract text from HTML
final text = extract('<html>...</html>');

// Download and extract
final content = await fetchAndExtract('https://example.org');

// Extract metadata
final metadata = extractMetadata(html);
```

## Command Line

```bash
# Extract from URL
trafilatura -u https://example.org

# Process files
trafilatura --input-dir ./html --output-dir ./text
```

## Resources

- [GitHub Repository](https://github.com/kamranxdev/trafilatura)
- [pub.dev Package](https://pub.dev/packages/trafilatura)
- [Original Python Library](https://github.com/adbar/trafilatura) by Adrien Barbaresi
- [Original Documentation](https://trafilatura.readthedocs.io/)

## Credits

- **Dart port**: [kamranxdev](https://github.com/kamranxdev) (Kamran Khan)
- **Original Python library**: [Adrien Barbaresi](https://github.com/adbar)

## License

Apache 2.0 License

## Citation

If you use Trafilatura in academic work, please cite:

```bibtex
@inproceedings{barbaresi-2021-trafilatura,
  title = {{Trafilatura: A Web Scraping Library and Command-Line Tool for Text Discovery and Extraction}},
  author = "Barbaresi, Adrien",
  booktitle = "Proceedings of ACL/IJCNLP 2021",
  pages = "122--131",
  year = 2021,
}
```
