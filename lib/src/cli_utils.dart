/// Command-line utility functions for Trafilatura.
///
/// This module provides helper functions for the CLI application.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'baseline.dart';
import 'core.dart';
import 'downloads.dart' as downloads;
import 'feeds.dart';
import 'settings.dart';
import 'sitemaps.dart';
import 'spider.dart' as spider;

/// Maximum files per directory.
const int maxFilesPerDirectory = 1000;

/// Filename length for generated names.
const int filenameLen = 8;

/// Character class for random filenames.
const String _charClass = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

/// Random instance for filename generation.
final _random = Random(345);

/// Extension mapping for output formats.
const Map<String, String> _extensionMapping = {
  'csv': '.csv',
  'json': '.json',
  'xml': '.xml',
  'xmltei': '.xml',
};

/// URL store for downloads.
class UrlStore {
  final Map<String, Queue<String>> _urlDict = {};
  final Set<String> _knownUrls = {};
  final Set<String> _visitedUrls = {};
  
  /// Add URLs to the store.
  void addUrls(List<String> urls, {bool visited = false}) {
    for (var url in urls) {
      final domain = _extractDomain(url);
      if (domain == null) continue;
      
      _urlDict.putIfAbsent(domain, () => Queue());
      
      if (!_knownUrls.contains(url)) {
        _knownUrls.add(url);
        if (!visited) {
          _urlDict[domain]!.addLast(url);
        } else {
          _visitedUrls.add(url);
        }
      }
    }
  }
  
  /// Get next URL for a domain.
  String? getUrl(String domain, {bool asVisited = true}) {
    final queue = _urlDict[domain];
    if (queue == null || queue.isEmpty) return null;
    
    final url = queue.removeFirst();
    if (asVisited) {
      _visitedUrls.add(url);
    }
    return url;
  }
  
  /// Check if processing is done.
  bool get done => _urlDict.values.every((q) => q.isEmpty);
  
  /// Get known domains.
  List<String> getKnownDomains() => _urlDict.keys.toList();
  
  /// Get all known URLs.
  List<String> findKnownUrls(String domain) {
    return _knownUrls.where((u) => u.contains(domain)).toList();
  }
  
  /// Get total URL count.
  int totalUrlNumber() => _knownUrls.length;
  
  /// Dump all URLs.
  List<String> dumpUrls() => _knownUrls.toList();
  
  /// Print unvisited URLs.
  void printUnvisitedUrls() {
    for (var url in _knownUrls.where((u) => !_visitedUrls.contains(u))) {
      print(url);
    }
  }
  
  /// Reset the store.
  void reset() {
    _urlDict.clear();
    _knownUrls.clear();
    _visitedUrls.clear();
  }
  
  String? _extractDomain(String url) {
    final uri = Uri.tryParse(url);
    return uri?.host;
  }
}

/// Load URLs from input file.
Future<List<String>> loadInputUrls(dynamic args) async {
  final inputUrls = <String>[];
  
  if (args.inputFile != null) {
    final file = File(args.inputFile);
    if (await file.exists()) {
      final lines = await file.readAsLines();
      inputUrls.addAll(lines.map((l) => l.trim()).where((l) => l.isNotEmpty));
    }
  } else if (args.url != null) {
    inputUrls.add(args.url);
  } else if (args.crawl != null && args.crawl.isNotEmpty) {
    inputUrls.add(args.crawl);
  } else if (args.feed != null && args.feed.isNotEmpty) {
    inputUrls.add(args.feed);
  } else if (args.sitemap != null && args.sitemap.isNotEmpty) {
    inputUrls.add(args.sitemap);
  }
  
  // Deduplicate while preserving order
  return inputUrls.toSet().toList();
}

/// Load blacklist from file.
Future<Set<String>> loadBlacklist(String filename) async {
  final file = File(filename);
  if (!await file.exists()) return {};
  
  final lines = await file.readAsLines();
  return lines
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('#'))
      .toSet();
}

/// Load input URLs into a URL store.
Future<UrlStore> loadInputDict(dynamic args) async {
  final inputList = await loadInputUrls(args);
  final urlStore = UrlStore();
  
  // Filter and add URLs
  for (var url in inputList) {
    if (args.blacklist != null && args.blacklist!.contains(url)) {
      continue;
    }
    if (args.urlFilter != null && args.urlFilter.isNotEmpty) {
      final matches = args.urlFilter.any((f) => url.contains(f));
      if (!matches) continue;
    }
    urlStore.addUrls([url]);
  }
  
  return urlStore;
}

/// Check if output directory is writable.
bool checkOutputDirStatus(String directory) {
  final dir = Directory(directory);
  
  if (!dir.existsSync()) {
    try {
      dir.createSync(recursive: true);
    } catch (e) {
      stderr.writeln('ERROR: Cannot create directory: $directory');
      return false;
    }
  }
  
  return true;
}

/// Determine counter directory.
String determineCounterDir(String dirname, int c) {
  if (c < 0) return dirname;
  final subDir = ((c ~/ maxFilesPerDirectory) + 1).toString();
  return '$dirname/$subDir';
}

/// Get a writable path with random filename.
(String, String) getWritablePath(String destdir, String extension) {
  String? outputPath;
  String filename;
  
  do {
    filename = List.generate(filenameLen, (_) => _charClass[_random.nextInt(_charClass.length)]).join();
    outputPath = '$destdir/$filename$extension';
  } while (File(outputPath).existsSync());
  
  return (outputPath, filename);
}

/// Generate hash-based filename.
String generateHashFilename(String content) {
  // Remove XML tags
  final clean = content.replaceAll(RegExp(r'<[^>]+>'), '');
  final bytes = utf8.encode(clean);
  final digest = md5.convert(bytes);
  return base64Url.encode(digest.bytes).substring(0, 12);
}

/// Determine output path based on options.
(String, String) determineOutputPath(
  dynamic args,
  String origFilename,
  String content, {
  int counter = -1,
  String? newFilename,
}) {
  // Determine extension
  final extension = _extensionMapping[args.outputFormat] ?? '.txt';
  
  String destinationDir;
  String filename;
  
  if (args.keepDirs) {
    final originalDir = origFilename.replaceAll(RegExp(r'[^/]+$'), '');
    destinationDir = '${args.outputDir}/$originalDir';
    filename = origFilename.replaceAll(RegExp(r'\.[a-z]{2,5}$'), '');
  } else {
    destinationDir = determineCounterDir(args.outputDir, counter);
    filename = newFilename ?? generateHashFilename(content);
  }
  
  final outputPath = '$destinationDir/$filename$extension';
  return (outputPath, destinationDir);
}

/// Write result to stdout or file.
void writeResult(
  String? result,
  dynamic args, {
  String origFilename = '',
  int counter = -1,
  String? newFilename,
}) {
  if (result == null) return;
  
  if (args.outputDir == null) {
    print(result);
  } else {
    final (destinationPath, destinationDir) = determineOutputPath(
      args, origFilename, result,
      counter: counter,
      newFilename: newFilename,
    );
    
    if (checkOutputDirStatus(destinationDir)) {
      File(destinationPath).writeAsStringSync(result);
    }
  }
}

/// Generate file list from directory.
Iterable<String> generateFilelist(String inputDir) sync* {
  final dir = Directory(inputDir);
  if (!dir.existsSync()) return;
  
  for (var entity in dir.listSync(recursive: true)) {
    if (entity is File) {
      yield entity.path;
    }
  }
}

/// Convert CLI args to Extractor.
Extractor argsToExtractor(dynamic args, {String? url}) {
  return Extractor(
    url: url ?? args.url,
    outputFormat: args.outputFormat,
    fast: args.fast,
    precision: args.precision,
    recall: args.recall,
    comments: args.comments,
    formatting: args.formatting,
    links: args.links,
    images: args.images,
    tables: args.tables,
    dedup: args.deduplicate,
    lang: args.targetLanguage,
    withMetadata: args.withMetadata,
    onlyWithMetadata: args.onlyWithMetadata,
    teiValidation: args.validateTei,
    urlBlacklist: args.blacklist,
  );
}

/// Examine and extract content from HTML.
Future<String?> examine(
  dynamic htmlstring,
  dynamic args, {
  String? url,
  Extractor? options,
}) async {
  options ??= argsToExtractor(args, url: url);
  
  if (htmlstring == null || (htmlstring is String && htmlstring.isEmpty)) {
    stderr.writeln('ERROR: empty document');
    return null;
  }
  
  try {
    return extract(
      filecontent: htmlstring,
      options: options,
    );
  } catch (e) {
    stderr.writeln('ERROR: $e');
    return null;
  }
}

/// Process a single file.
Future<void> fileProcessing(
  String filename,
  dynamic args, {
  int counter = -1,
  Extractor? options,
}) async {
  options ??= argsToExtractor(args);
  options.source = filename;
  
  final file = File(filename);
  if (!await file.exists()) return;
  
  final content = await file.readAsString();
  final result = await examine(content, args, options: options);
  writeResult(result, args, origFilename: filename, counter: counter);
}

/// Process files in a directory.
Future<void> fileProcessingPipeline(dynamic args) async {
  var counter = -1;
  final options = argsToExtractor(args);
  
  final files = generateFilelist(args.inputDir).toList();
  if (files.length >= maxFilesPerDirectory) {
    counter = 0;
  }
  
  for (var filename in files) {
    await fileProcessing(filename, args, counter: counter, options: options);
    if (counter >= 0) counter++;
  }
}

/// Download and process a result.
Future<int> processResult(
  String htmlstring,
  dynamic args,
  int counter,
  Extractor? options,
) async {
  final result = await examine(htmlstring, args, options: options);
  writeResult(result, args, counter: counter);
  
  if (counter >= 0 && result != null) {
    return counter + 1;
  }
  return counter;
}

/// Download queue processing.
Future<(List<String>, int)> downloadQueueProcessing(
  UrlStore urlStore,
  dynamic args,
  int counter,
  Extractor options,
) async {
  final errors = <String>[];
  
  while (!urlStore.done) {
    for (var domain in urlStore.getKnownDomains()) {
      final url = urlStore.getUrl(domain);
      if (url == null) continue;
      
      final result = await downloads.fetchUrl(url);
      if (result != null) {
        options.url = url;
        counter = await processResult(result, args, counter, options);
      } else {
        errors.add(url);
      }
      
      // Rate limiting
      await Future.delayed(const Duration(seconds: 2));
    }
  }
  
  return (errors, counter);
}

/// CLI discovery function.
Future<int> cliDiscovery(dynamic args) async {
  final urlStore = await loadInputDict(args);
  final inputUrls = urlStore.dumpUrls();
  
  if (args.list) {
    urlStore.reset();
  }
  
  // Discover URLs
  for (var url in inputUrls) {
    List<String> discovered;
    if (args.feed != null) {
      discovered = await findFeedUrls(url, targetLang: args.targetLanguage);
    } else {
      discovered = await sitemapSearch(url, targetLang: args.targetLanguage);
    }
    urlStore.addUrls(discovered);
    
    if (args.list) {
      urlStore.printUnvisitedUrls();
      urlStore.reset();
    }
  }
  
  // Process discovered URLs
  return urlProcessingPipeline(args, urlStore);
}

/// CLI crawler function.
Future<void> cliCrawler(dynamic args, {int n = 30, UrlStore? urlStore}) async {
  final inputUrls = await loadInputUrls(args);
  
  for (var url in inputUrls) {
    final (todo, known) = await spider.focusedCrawler(
      url,
      maxSeenUrls: n,
      lang: args.targetLanguage,
    );
    
    for (var foundUrl in todo) {
      print(foundUrl);
    }
  }
}

/// Probe homepage for extractable content.
Future<void> probeHomepage(dynamic args) async {
  final inputUrls = await loadInputUrls(args);
  final options = argsToExtractor(args);
  
  for (var url in inputUrls) {
    final result = await downloads.fetchUrl(url);
    if (result != null) {
      final text = html2txt(result);
      if (text.isNotEmpty && 
          text.length > options.minExtractedSize &&
          text.contains(RegExp(r'[a-zA-Z]'))) {
        print(url);
      }
    }
  }
}

/// Define exit code based on errors.
int defineExitCode(List<String> errors, int total) {
  if (total == 0) return 0;
  final ratio = errors.length / total;
  
  if (ratio > 0.99) return 126;
  if (errors.isNotEmpty) return 1;
  return 0;
}

/// URL processing pipeline.
Future<int> urlProcessingPipeline(dynamic args, UrlStore urlStore) async {
  if (args.list) {
    urlStore.printUnvisitedUrls();
    return 0;
  }
  
  final options = argsToExtractor(args);
  final urlCount = urlStore.totalUrlNumber();
  var counter = urlCount > maxFilesPerDirectory ? 0 : -1;
  
  final (errors, _) = await downloadQueueProcessing(urlStore, args, counter, options);
  
  return defineExitCode(errors, urlCount);
}
