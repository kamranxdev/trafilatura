# Command-Line Interface Reference

Complete reference for the Trafilatura CLI.

## Basic Syntax

```bash
trafilatura [options]
```

Or run directly:

```bash
dart run bin/trafilatura.dart [options]
```

## Input Options

### URL Input

```bash
# Single URL
trafilatura -u https://example.org

# Or with long form
trafilatura --URL https://example.org
```

### File Input

```bash
# Single file
trafilatura -i article.html
trafilatura --input-file article.html

# Directory of files
trafilatura --input-dir ./html_files
```

### Standard Input

```bash
# Pipe HTML content
cat article.html | trafilatura

# Curl and extract
curl -s https://example.org | trafilatura
```

## Output Options

### Output Directory

```bash
# Save to directory
trafilatura -u https://example.org -o ./output
trafilatura --input-dir ./html --output-dir ./text
```

### Output Format

```bash
# Plain text (default)
trafilatura -u https://example.org

# JSON
trafilatura -u https://example.org --output-format json

# XML
trafilatura -u https://example.org --output-format xml

# XML-TEI
trafilatura -u https://example.org --output-format xmltei

# CSV
trafilatura -u https://example.org --output-format csv
```

### Backup Original HTML

```bash
trafilatura -u https://example.org --backup-dir ./raw_html
```

## Content Options

### Include Elements

```bash
# Include text formatting (bold, italic, etc.)
trafilatura -u https://example.org --formatting

# Include hyperlinks
trafilatura -u https://example.org --links

# Include images
trafilatura -u https://example.org --images

# All together
trafilatura -u https://example.org --formatting --links --images
```

### Exclude Elements

```bash
# Exclude comments
trafilatura -u https://example.org --no-comments

# Exclude tables
trafilatura -u https://example.org --no-tables
```

### Metadata

```bash
# Include metadata in output
trafilatura -u https://example.org --with-metadata

# Only extract if metadata present
trafilatura -u https://example.org --only-with-metadata
```

## Processing Options

### Fast Mode

```bash
# Skip fallback extractors for speed
trafilatura -u https://example.org -f
trafilatura -u https://example.org --fast
```

### Parallel Processing

```bash
# Set number of parallel workers
trafilatura --input-dir ./html --parallel 8
```

### Language Filtering

```bash
# Only extract if content is in English
trafilatura -u https://example.org --target-language en

# French content only
trafilatura -u https://example.org --target-language fr
```

## Discovery Options

### Feed Discovery

```bash
# Find and process feed URLs
trafilatura --feed https://example.org

# Process specific feed URL
trafilatura --feed https://example.org/feed.xml
```

### Sitemap Discovery

```bash
# Find and process sitemap URLs
trafilatura --sitemap https://example.org

# Process specific sitemap
trafilatura --sitemap https://example.org/sitemap.xml
```

### Website Crawling

```bash
# Crawl website with default limit
trafilatura --crawl https://example.org

# Crawl with specific limit
trafilatura --crawl https://example.org --limit 100
```

### Combined Exploration

```bash
# Use both sitemap and crawling
trafilatura --explore https://example.org
```

## URL Management

### URL Filtering

```bash
# Only process URLs matching patterns
trafilatura --sitemap https://example.org --url-filter "blog|article"
```

### Blacklist

```bash
# Skip URLs in blacklist file
trafilatura --crawl https://example.org --blacklist unwanted.txt
```

### List Mode

```bash
# Only list discovered URLs, don't download
trafilatura --sitemap https://example.org --list
```

### Probe Mode

```bash
# Check if URLs have extractable content
trafilatura --sitemap https://example.org --probe
```

## Archive Options

```bash
# Try Internet Archive if download fails
trafilatura -u https://example.org --archived
```

## Example Workflows

### Extract single article

```bash
trafilatura -u https://example.org/article --formatting
```

### Batch process files

```bash
trafilatura --input-dir ./downloaded --output-dir ./extracted --parallel 4
```

### Build corpus from website

```bash
trafilatura --sitemap https://example.org --output-dir ./corpus --output-format json
```

### Extract with full metadata

```bash
trafilatura -u https://example.org --with-metadata --output-format json
```

### Crawl with constraints

```bash
trafilatura --crawl https://example.org \
  --limit 500 \
  --parallel 2 \
  --url-filter "news|article" \
  --target-language en \
  --output-dir ./articles
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Invalid arguments |

## Help

```bash
# Show help
trafilatura --help
trafilatura -h

# Show version
trafilatura --version
```
