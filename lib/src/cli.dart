/// Command-line interface for Trafilatura.
///
/// This module provides the main entry point for the CLI application.
library;

import 'dart:io';

import 'package:args/args.dart';

import 'cli_utils.dart';
import 'settings.dart';

/// Supported output formats for CLI.
const List<String> supportedFormats = [
  'csv', 'html', 'json', 'markdown', 'txt', 'xml', 'xmltei'
];

/// Build the argument parser.
ArgParser buildParser() {
  final parser = ArgParser();
  
  // Input options
  parser.addOption('input-file',
      abbr: 'i',
      help: 'Name of input file for batch processing');
  parser.addOption('input-dir',
      help: 'Read files from a specified directory');
  parser.addOption('URL',
      abbr: 'u',
      help: 'Custom URL download');
  parser.addOption('parallel',
      help: 'Number of parallel downloads/processing',
      defaultsTo: '${DefaultConfig.parallelCores}');
  parser.addOption('blacklist',
      abbr: 'b',
      help: 'File containing unwanted URLs to discard');
  
  // Output options  
  parser.addFlag('list',
      help: 'Display a list of URLs without downloading',
      negatable: false);
  parser.addOption('output-dir',
      abbr: 'o',
      help: 'Write results to specified directory');
  parser.addOption('backup-dir',
      help: 'Preserve raw HTML in backup directory');
  parser.addFlag('keep-dirs',
      help: 'Keep input directory structure',
      negatable: false);
  
  // Navigation options
  parser.addOption('feed',
      help: 'Look for feeds and/or pass a feed URL');
  parser.addOption('sitemap',
      help: 'Look for sitemaps for the given website');
  parser.addOption('crawl',
      help: 'Crawl a fixed number of pages within a website');
  parser.addOption('explore',
      help: 'Explore websites (combination of sitemap and crawl)');
  parser.addOption('probe',
      help: 'Probe for extractable content');
  parser.addFlag('archived',
      help: 'Try Internet Archive if downloads fail',
      negatable: false);
  parser.addMultiOption('url-filter',
      help: 'Only process URLs containing these patterns');
  
  // Extraction options
  parser.addFlag('fast',
      abbr: 'f',
      help: 'Fast extraction without fallback',
      negatable: false);
  parser.addFlag('formatting',
      help: 'Include text formatting',
      negatable: false);
  parser.addFlag('links',
      help: 'Include links with targets',
      negatable: false);
  parser.addFlag('images',
      help: 'Include image sources',
      negatable: false);
  parser.addFlag('no-comments',
      help: "Don't output comments",
      negatable: false);
  parser.addFlag('no-tables',
      help: "Don't output table elements",
      negatable: false);
  parser.addFlag('only-with-metadata',
      help: 'Only documents with title, URL and date',
      negatable: false);
  parser.addFlag('with-metadata',
      help: 'Extract and add metadata',
      negatable: false);
  parser.addOption('target-language',
      help: 'Target language (ISO 639-1 code)');
  parser.addFlag('deduplicate',
      help: 'Filter out duplicates',
      negatable: false);
  parser.addOption('config-file',
      help: 'Custom config file');
  parser.addFlag('precision',
      help: 'Favor extraction precision',
      negatable: false);
  parser.addFlag('recall',
      help: 'Favor extraction recall',
      negatable: false);
  
  // Format options
  parser.addOption('output-format',
      help: 'Output format',
      allowed: supportedFormats,
      defaultsTo: 'txt');
  parser.addFlag('csv',
      help: 'Shorthand for CSV output',
      negatable: false);
  parser.addFlag('html',
      help: 'Shorthand for HTML output',
      negatable: false);
  parser.addFlag('json',
      help: 'Shorthand for JSON output',
      negatable: false);
  parser.addFlag('markdown',
      help: 'Shorthand for Markdown output',
      negatable: false);
  parser.addFlag('xml',
      help: 'Shorthand for XML output',
      negatable: false);
  parser.addFlag('xmltei',
      help: 'Shorthand for XML TEI output',
      negatable: false);
  parser.addFlag('validate-tei',
      help: 'Validate XML TEI output',
      negatable: false);
  
  // General options
  parser.addFlag('verbose',
      abbr: 'v',
      help: 'Increase logging verbosity',
      negatable: false);
  parser.addFlag('version',
      help: 'Show version information',
      negatable: false);
  parser.addFlag('help',
      abbr: 'h',
      help: 'Show usage information',
      negatable: false);
  
  return parser;
}

/// Parse command-line arguments.
CliArgs parseArgs(List<String> arguments) {
  final parser = buildParser();
  
  try {
    final results = parser.parse(arguments);
    return CliArgs.fromArgResults(results);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    stderr.writeln();
    stderr.writeln(parser.usage);
    exit(1);
  }
}

/// Container for parsed CLI arguments.
class CliArgs {
  // Input
  final String? inputFile;
  final String? inputDir;
  final String? url;
  final int parallel;
  final String? blacklistFile;
  
  // Output
  final bool list;
  final String? outputDir;
  final String? backupDir;
  final bool keepDirs;
  
  // Navigation
  final String? feed;
  final String? sitemap;
  final String? crawl;
  final String? explore;
  final String? probe;
  final bool archived;
  final List<String> urlFilter;
  
  // Extraction
  final bool fast;
  final bool formatting;
  final bool links;
  final bool images;
  final bool comments;
  final bool tables;
  final bool onlyWithMetadata;
  final bool withMetadata;
  final String? targetLanguage;
  final bool deduplicate;
  final String? configFile;
  final bool precision;
  final bool recall;
  
  // Format
  String outputFormat;
  final bool validateTei;
  
  // General
  final bool verbose;
  final bool version;
  final bool help;
  
  // Blacklist (loaded from file)
  Set<String>? blacklist;
  
  CliArgs({
    this.inputFile,
    this.inputDir,
    this.url,
    this.parallel = 4,
    this.blacklistFile,
    this.list = false,
    this.outputDir,
    this.backupDir,
    this.keepDirs = false,
    this.feed,
    this.sitemap,
    this.crawl,
    this.explore,
    this.probe,
    this.archived = false,
    this.urlFilter = const [],
    this.fast = false,
    this.formatting = false,
    this.links = false,
    this.images = false,
    this.comments = true,
    this.tables = true,
    this.onlyWithMetadata = false,
    this.withMetadata = false,
    this.targetLanguage,
    this.deduplicate = false,
    this.configFile,
    this.precision = false,
    this.recall = false,
    this.outputFormat = 'txt',
    this.validateTei = false,
    this.verbose = false,
    this.version = false,
    this.help = false,
    this.blacklist,
  });
  
  factory CliArgs.fromArgResults(ArgResults results) {
    // Determine output format from flags
    var format = results['output-format'] as String;
    for (var fmt in ['csv', 'html', 'json', 'markdown', 'xml', 'xmltei']) {
      if (results[fmt] == true) {
        format = fmt;
        break;
      }
    }
    
    return CliArgs(
      inputFile: results['input-file'] as String?,
      inputDir: results['input-dir'] as String?,
      url: results['URL'] as String?,
      parallel: int.tryParse(results['parallel'] as String) ?? 4,
      blacklistFile: results['blacklist'] as String?,
      list: results['list'] as bool,
      outputDir: results['output-dir'] as String?,
      backupDir: results['backup-dir'] as String?,
      keepDirs: results['keep-dirs'] as bool,
      feed: _getStringOrFlag(results, 'feed'),
      sitemap: _getStringOrFlag(results, 'sitemap'),
      crawl: _getStringOrFlag(results, 'crawl'),
      explore: _getStringOrFlag(results, 'explore'),
      probe: _getStringOrFlag(results, 'probe'),
      archived: results['archived'] as bool,
      urlFilter: results['url-filter'] as List<String>,
      fast: results['fast'] as bool,
      formatting: results['formatting'] as bool,
      links: results['links'] as bool,
      images: results['images'] as bool,
      comments: !(results['no-comments'] as bool),
      tables: !(results['no-tables'] as bool),
      onlyWithMetadata: results['only-with-metadata'] as bool,
      withMetadata: results['with-metadata'] as bool,
      targetLanguage: results['target-language'] as String?,
      deduplicate: results['deduplicate'] as bool,
      configFile: results['config-file'] as String?,
      precision: results['precision'] as bool,
      recall: results['recall'] as bool,
      outputFormat: format,
      validateTei: results['validate-tei'] as bool,
      verbose: results['verbose'] as bool,
      version: results['version'] as bool,
      help: results['help'] as bool,
    );
  }
  
  static String? _getStringOrFlag(ArgResults results, String name) {
    final value = results[name];
    if (value == null || value == false) return null;
    if (value == true) return '';
    return value as String;
  }
}

/// Main entry point for CLI.
Future<void> main(List<String> arguments) async {
  final args = parseArgs(arguments);
  await processArgs(args);
}

/// Process parsed arguments.
Future<void> processArgs(CliArgs args) async {
  var exitCode = 0;
  
  // Help
  if (args.help) {
    final parser = buildParser();
    print('Trafilatura - Web scraping and text extraction');
    print('');
    print('Usage: trafilatura [options]');
    print('');
    print(parser.usage);
    return;
  }
  
  // Version
  if (args.version) {
    print('Trafilatura 2.0.0 - Dart');
    return;
  }
  
  // Load blacklist
  if (args.blacklistFile != null) {
    args.blacklist = await loadBlacklist(args.blacklistFile!);
  }
  
  // Processing based on options
  if (args.explore != null || args.feed != null || args.sitemap != null) {
    exitCode = await cliDiscovery(args);
  } else if (args.crawl != null) {
    await cliCrawler(args);
  } else if (args.probe != null) {
    await probeHomepage(args);
  } else if (args.inputDir != null) {
    await fileProcessingPipeline(args);
  } else if (args.inputFile != null || args.url != null) {
    final urlStore = await loadInputDict(args);
    exitCode = await urlProcessingPipeline(args, urlStore);
  } else {
    // Read from stdin
    final input = await stdin.transform(systemEncoding.decoder).join();
    final result = await examine(input, args, url: args.url);
    writeResult(result, args);
  }
  
  // Exit with error code if needed
  if (exitCode != 0) {
    exit(exitCode);
  }
}
