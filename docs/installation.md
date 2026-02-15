# Installation

This guide explains how to install and set up Trafilatura Dart.

## Requirements

- Dart SDK 3.0.0 or higher
- For Flutter projects: Flutter 3.0.0 or higher

## Installation Methods

### As a package dependency

Add Trafilatura to your `pubspec.yaml` file:

```yaml
dependencies:
  trafilatura: ^1.0.0
```

Then run:

```bash
dart pub get
```

### Global CLI installation

To use Trafilatura as a command-line tool:

```bash
dart pub global activate trafilatura
```

Make sure you have the pub global bin directory in your PATH:

- **Linux/macOS**: Add `export PATH="$PATH:$HOME/.pub-cache/bin"` to your shell profile
- **Windows**: Add `%APPDATA%\Pub\Cache\bin` to your PATH

### From source

Clone the repository and install dependencies:

```bash
git clone https://github.com/kamranxdev/trafilatura-dart.git
cd trafilatura-dart
dart pub get
```

Run the CLI directly:

```bash
dart run bin/trafilatura.dart --help
```

## Verification

Verify the installation:

```bash
# Check Dart version
dart --version

# Test Trafilatura
dart run bin/trafilatura.dart --version

# Or if globally installed
trafilatura --version
```

## Dependencies

Trafilatura Dart uses the following packages:

| Package | Purpose |
|---------|---------|
| `html` | HTML parsing |
| `xml` | XML generation and parsing |
| `http` | HTTP client for downloads |
| `crypto` | Hashing for deduplication |
| `args` | Command-line argument parsing |
| `intl` | Internationalization |
| `charset` | Character encoding detection |

All dependencies are automatically installed via `dart pub get`.

## Flutter Integration

Trafilatura works with Flutter. Add it to your Flutter project:

```yaml
dependencies:
  trafilatura: ^1.0.0
```

```dart
import 'package:trafilatura/trafilatura.dart';

class MyWidget extends StatelessWidget {
  Future<String?> extractContent(String html) async {
    return extract(html);
  }
}
```

## Troubleshooting

### Common Issues

**Pub get fails**
- Ensure you have Dart 3.0.0 or higher
- Check your internet connection
- Try `dart pub cache repair`

**CLI not found**
- Ensure global bin is in PATH
- Try running with `dart pub global run trafilatura`

**Encoding issues**
- The library auto-detects encoding
- For specific encodings, decode manually before passing to extract()
