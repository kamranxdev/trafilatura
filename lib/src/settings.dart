/// Settings and configuration for Trafilatura.
///
/// Contains all configuration classes, constants, and default settings
/// used throughout the library.
library;

import 'dart:io';
import 'package:xml/xml.dart';

/// Supported output formats for CLI
const List<String> supportedFmtCli = [
  'csv',
  'json',
  'html',
  'markdown',
  'txt',
  'xml',
  'xmltei'
];

/// All supported output formats including 'python' for bare extraction
final Set<String> supportedFormats = {...supportedFmtCli, 'python'};

/// Default configuration values
class DefaultConfig {
  static const int minExtractedSize = 250;
  static const int minOutputSize = 200;
  static const int minOutputCommSize = 100;
  static const int minExtractedCommSize = 100;
  static const int minDuplcheckSize = 100;
  static const int maxRepetitions = 2;
  static const int maxFileSize = 20000000;
  static const int minFileSize = 200;
  static const bool extensiveDateSearch = true;
  static const int parallelCores = 4;
  static const int maxLinks = 10000;
  static const int maxSitemapsSeen = 500;
  
  /// Default tag catalog for body/comment content detection
  static const Map<String, Set<String>> tagCatalog = {
    'body': {
      'article', 'div', 'main', 'section', 'p', 'blockquote', 'pre',
      'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'ul', 'ol', 'li', 'dl', 'dt', 'dd',
      'table', 'tr', 'td', 'th', 'thead', 'tbody', 'figure', 'figcaption'
    },
    'comments': {
      'div', 'section', 'article', 'aside', 'p', 'li', 'span'
    }
  };
}

/// Configuration mapping between option names and config keys
const Map<String, String> configMapping = {
  'minExtractedSize': 'MIN_EXTRACTED_SIZE',
  'minOutputSize': 'MIN_OUTPUT_SIZE',
  'minOutputCommSize': 'MIN_OUTPUT_COMM_SIZE',
  'minExtractedCommSize': 'MIN_EXTRACTED_COMM_SIZE',
  'minDuplcheckSize': 'MIN_DUPLCHECK_SIZE',
  'maxRepetitions': 'MAX_REPETITIONS',
  'maxFileSize': 'MAX_FILE_SIZE',
  'minFileSize': 'MIN_FILE_SIZE',
};

/// Class to store all extraction options.
class Extractor {
  /// Configuration parser
  Map<String, dynamic> config;

  /// Output format
  String format;

  /// Fast extraction mode
  bool fast;

  /// Focus mode: 'balanced', 'precision', or 'recall'
  String focus;

  /// Include comments
  bool comments;

  /// Include formatting
  bool formatting;

  /// Include links
  bool links;

  /// Include images
  bool images;

  /// Include tables
  bool tables;

  /// Deduplicate content
  bool dedup;

  /// Target language
  String? lang;

  // Extraction size thresholds
  int minExtractedSize;
  int minOutputSize;
  int minOutputCommSize;
  int minExtractedCommSize;

  // Deduplication settings
  int minDuplcheckSize;
  int maxRepetitions;

  // File size limits
  int maxFileSize;
  int minFileSize;
  int? maxTreeSize;

  // Meta information
  String? source;
  String? url;
  bool withMetadata;
  bool onlyWithMetadata;
  bool teiValidation;
  Map<String, dynamic> dateParams;
  Set<String> authorBlacklist;
  Set<String> urlBlacklist;

  Extractor({
    Map<String, dynamic>? config,
    String outputFormat = 'txt',
    this.fast = false,
    bool precision = false,
    bool recall = false,
    this.comments = true,
    this.formatting = false,
    this.links = false,
    this.images = false,
    this.tables = true,
    this.dedup = false,
    this.lang,
    this.url,
    this.source,
    bool withMetadata = false,
    this.onlyWithMetadata = false,
    this.teiValidation = false,
    Set<String>? authorBlacklist,
    Set<String>? urlBlacklist,
    Map<String, dynamic>? dateParams,
  })  : config = config ?? {},
        format = outputFormat,
        focus = recall
            ? 'recall'
            : precision
                ? 'precision'
                : 'balanced',
        authorBlacklist = authorBlacklist ?? {},
        urlBlacklist = urlBlacklist ?? {},
        minExtractedSize = DefaultConfig.minExtractedSize,
        minOutputSize = DefaultConfig.minOutputSize,
        minOutputCommSize = DefaultConfig.minOutputCommSize,
        minExtractedCommSize = DefaultConfig.minExtractedCommSize,
        minDuplcheckSize = DefaultConfig.minDuplcheckSize,
        maxRepetitions = DefaultConfig.maxRepetitions,
        maxFileSize = DefaultConfig.maxFileSize,
        minFileSize = DefaultConfig.minFileSize,
        dateParams = dateParams ?? setDateParams(DefaultConfig.extensiveDateSearch),
        withMetadata = withMetadata ||
            onlyWithMetadata ||
            (urlBlacklist?.isNotEmpty ?? false) ||
            outputFormat == 'xmltei' {
    _setSource(url, source);
    _setFormat(outputFormat);
    if (config != null) {
      _addConfig(config);
    }
    // Markdown always needs formatting
    if (format == 'markdown') {
      this.formatting = true;
    }
  }

  void _setSource(String? url, String? source) {
    final src = url ?? source;
    this.source = src;
  }

  void _setFormat(String chosenFormat) {
    if (!supportedFormats.contains(chosenFormat)) {
      throw ArgumentError(
          'Cannot set format, must be one of: ${supportedFormats.toList()..sort()}');
    }
    format = chosenFormat;
  }

  void _addConfig(Map<String, dynamic> config) {
    if (config.containsKey('minExtractedSize')) {
      minExtractedSize = config['minExtractedSize'] as int;
    }
    if (config.containsKey('minOutputSize')) {
      minOutputSize = config['minOutputSize'] as int;
    }
    if (config.containsKey('minOutputCommSize')) {
      minOutputCommSize = config['minOutputCommSize'] as int;
    }
    if (config.containsKey('minExtractedCommSize')) {
      minExtractedCommSize = config['minExtractedCommSize'] as int;
    }
    if (config.containsKey('minDuplcheckSize')) {
      minDuplcheckSize = config['minDuplcheckSize'] as int;
    }
    if (config.containsKey('maxRepetitions')) {
      maxRepetitions = config['maxRepetitions'] as int;
    }
    if (config.containsKey('maxFileSize')) {
      maxFileSize = config['maxFileSize'] as int;
    }
    if (config.containsKey('minFileSize')) {
      minFileSize = config['minFileSize'] as int;
    }
  }
}

/// Derive extractor configuration from CLI args.
Extractor argsToExtractor(Map<String, dynamic> args, {String? url}) {
  final options = Extractor(
    outputFormat: args['outputFormat'] as String? ?? 'txt',
    formatting: args['formatting'] as bool? ?? false,
    precision: args['precision'] as bool? ?? false,
    recall: args['recall'] as bool? ?? false,
    comments: args['noComments'] as bool? ?? true,
    tables: args['noTables'] as bool? ?? true,
    dedup: args['deduplicate'] as bool? ?? false,
    lang: args['targetLanguage'] as String?,
    url: url,
    withMetadata: args['withMetadata'] as bool? ?? false,
    onlyWithMetadata: args['onlyWithMetadata'] as bool? ?? false,
    teiValidation: args['validateTei'] as bool? ?? false,
  );

  if (args.containsKey('fast')) {
    options.fast = args['fast'] as bool;
  }
  if (args.containsKey('images')) {
    options.images = args['images'] as bool;
  }
  if (args.containsKey('links')) {
    options.links = args['links'] as bool;
  }

  return options;
}

/// Provide default parameters for date extraction.
Map<String, dynamic> setDateParams([bool extensive = true]) {
  return {
    'originalDate': true,
    'extensiveSearch': extensive,
    'maxDate': DateTime.now().toIso8601String().substring(0, 10),
  };
}

/// Class to store all necessary data and metadata fields for extracted information.
class Document {
  String? title;
  String? author;
  String? url;
  String? hostname;
  String? description;
  String? sitename;
  String? date;
  List<String>? categories;
  List<String>? tags;
  String? fingerprint;
  String? id;
  String? license;
  XmlElement body;
  String? comments;
  XmlElement? commentsbody;
  String? rawText;
  String? text;
  String? language;
  String? image;
  String? pagetype;
  String? filedate;

  Document({
    this.title,
    this.author,
    this.url,
    this.hostname,
    this.description,
    this.sitename,
    this.date,
    this.categories,
    this.tags,
    this.fingerprint,
    this.id,
    this.license,
    XmlElement? body,
    this.comments,
    XmlElement? commentsbody,
    this.rawText,
    this.text,
    this.language,
    this.image,
    this.pagetype,
    this.filedate,
  })  : body = body ?? XmlElement(XmlName('body')),
        commentsbody = commentsbody;

  /// Create a Document from a dictionary.
  factory Document.fromDict(Map<String, dynamic> data) {
    return Document(
      title: data['title'] as String?,
      author: data['author'] as String?,
      url: data['url'] as String?,
      hostname: data['hostname'] as String?,
      description: data['description'] as String?,
      sitename: data['sitename'] as String?,
      date: data['date'] as String?,
      categories: (data['categories'] as List<dynamic>?)?.cast<String>(),
      tags: (data['tags'] as List<dynamic>?)?.cast<String>(),
      fingerprint: data['fingerprint'] as String?,
      id: data['id'] as String?,
      license: data['license'] as String?,
      comments: data['comments'] as String?,
      rawText: data['rawText'] as String?,
      text: data['text'] as String?,
      language: data['language'] as String?,
      image: data['image'] as String?,
      pagetype: data['pagetype'] as String?,
      filedate: data['filedate'] as String?,
    );
  }

  /// Limit text length and trim the attributes.
  void cleanAndTrim() {
    final stringFields = [
      'title',
      'author',
      'url',
      'hostname',
      'description',
      'sitename',
      'date',
      'fingerprint',
      'id',
      'license',
      'comments',
      'rawText',
      'text',
      'language',
      'image',
      'pagetype',
      'filedate',
    ];

    for (final field in stringFields) {
      var value = _getField(field);
      if (value != null) {
        // Length limit
        if (value.length > 10000) {
          value = '${value.substring(0, 9999)}…';
        }
        // HTML entities handled at parse time in Dart
        value = lineProcessing(value);
        _setField(field, value);
      }
    }
  }

  String? _getField(String name) {
    switch (name) {
      case 'title':
        return title;
      case 'author':
        return author;
      case 'url':
        return url;
      case 'hostname':
        return hostname;
      case 'description':
        return description;
      case 'sitename':
        return sitename;
      case 'date':
        return date;
      case 'fingerprint':
        return fingerprint;
      case 'id':
        return id;
      case 'license':
        return license;
      case 'comments':
        return comments;
      case 'rawText':
        return rawText;
      case 'text':
        return text;
      case 'language':
        return language;
      case 'image':
        return image;
      case 'pagetype':
        return pagetype;
      case 'filedate':
        return filedate;
      default:
        return null;
    }
  }

  void _setField(String name, String? value) {
    switch (name) {
      case 'title':
        title = value;
        break;
      case 'author':
        author = value;
        break;
      case 'url':
        url = value;
        break;
      case 'hostname':
        hostname = value;
        break;
      case 'description':
        description = value;
        break;
      case 'sitename':
        sitename = value;
        break;
      case 'date':
        date = value;
        break;
      case 'fingerprint':
        fingerprint = value;
        break;
      case 'id':
        id = value;
        break;
      case 'license':
        license = value;
        break;
      case 'comments':
        comments = value;
        break;
      case 'rawText':
        rawText = value;
        break;
      case 'text':
        text = value;
        break;
      case 'language':
        language = value;
        break;
      case 'image':
        image = value;
        break;
      case 'pagetype':
        pagetype = value;
        break;
      case 'filedate':
        filedate = value;
        break;
    }
  }

  /// Convert the document to a dictionary.
  Map<String, dynamic> asDict() {
    return {
      'title': title,
      'author': author,
      'url': url,
      'hostname': hostname,
      'description': description,
      'sitename': sitename,
      'date': date,
      'categories': categories,
      'tags': tags,
      'fingerprint': fingerprint,
      'id': id,
      'license': license,
      'comments': comments,
      'rawText': rawText,
      'text': text,
      'language': language,
      'image': image,
      'pagetype': pagetype,
      'filedate': filedate,
    };
  }
}

/// Process a line of text (placeholder - will be implemented in utils.dart)
String lineProcessing(String text) {
  return text.trim().replaceAll(RegExp(r'\s+'), ' ');
}

// Safety checks
final int parallelCores = _getParallelCores();

int _getParallelCores() {
  final cpuCount = Platform.numberOfProcessors;
  return cpuCount < 16 ? cpuCount : 16;
}

const int lruSize = 4096;

// Files
const int maxFilesPerDirectory = 1000;
const int filenameLen = 8;

// Network
const int maxLinks = 1000000;
const int maxSitemapsSeen = 10000;

/// Elements that should be removed if empty
const Set<String> cutEmptyElems = {
  'article',
  'b',
  'blockquote',
  'dd',
  'div',
  'dt',
  'em',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'i',
  'li',
  'main',
  'p',
  'pre',
  'q',
  'section',
  'span',
  'strong',
};

/// Elements to be manually cleaned/removed
const List<String> manuallyCleaned = [
  // important
  'aside',
  'embed',
  'footer',
  'form',
  'head',
  'iframe',
  'menu',
  'object',
  'script',
  // other content
  'applet',
  'audio',
  'canvas',
  'figure',
  'map',
  'picture',
  'svg',
  'video',
  // secondary
  'area',
  'blink',
  'button',
  'datalist',
  'dialog',
  'frame',
  'frameset',
  'fieldset',
  'link',
  'input',
  'ins',
  'label',
  'legend',
  'marquee',
  'math',
  'menuitem',
  'nav',
  'noindex',
  'noscript',
  'optgroup',
  'option',
  'output',
  'param',
  'progress',
  'rp',
  'rt',
  'rtc',
  'select',
  'source',
  'style',
  'track',
  'textarea',
  'time',
  'use',
];

/// Elements to be stripped (keep content, remove tags)
const List<String> manuallyStripped = [
  'abbr',
  'acronym',
  'address',
  'bdi',
  'bdo',
  'big',
  'cite',
  'data',
  'dfn',
  'font',
  'hgroup',
  'img',
  'ins',
  'mark',
  'meta',
  'ruby',
  'small',
  'tbody',
  'template',
  'tfoot',
  'thead',
];

/// Tags used for content extraction
const Set<String> tagCatalog = {
  'blockquote',
  'code',
  'del',
  'head',
  'hi',
  'lb',
  'list',
  'p',
  'pre',
  'quote',
};

/// Language mappings for JusText
const Map<String, String> justextLanguages = {
  'ar': 'Arabic',
  'bg': 'Bulgarian',
  'cz': 'Czech',
  'da': 'Danish',
  'de': 'German',
  'en': 'English',
  'el': 'Greek',
  'es': 'Spanish',
  'fa': 'Persian',
  'fi': 'Finnish',
  'fr': 'French',
  'hr': 'Croatian',
  'hu': 'Hungarian',
  'ko': 'Korean',
  'id': 'Indonesian',
  'it': 'Italian',
  'no': 'Norwegian_Nynorsk',
  'nl': 'Dutch',
  'pl': 'Polish',
  'pt': 'Portuguese',
  'ro': 'Romanian',
  'ru': 'Russian',
  'sk': 'Slovak',
  'sl': 'Slovenian',
  'sr': 'Serbian',
  'sv': 'Swedish',
  'tr': 'Turkish',
  'uk': 'Ukrainian',
  'ur': 'Urdu',
  'vi': 'Vietnamese',
};
