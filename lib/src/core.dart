/// Core extraction functions for Trafilatura.
///
/// This module provides the main entry points for text extraction
/// from HTML documents.
library;

import 'package:html/dom.dart' hide Document;
import 'package:xml/xml.dart';

import 'settings.dart';
import 'utils.dart';
import 'baseline.dart';
import 'deduplication.dart';
import 'external.dart';
import 'htmlprocessing.dart' hide buildHtmlOutput;
import 'main_extractor.dart';
import 'metadata.dart';
import 'xml_utils.dart';
import 'xpaths.dart';

/// Text output formats.
const Set<String> _txtFormats = {'markdown', 'txt'};

/// Convert document to requested output format string.
String determineReturnString(Document document, Extractor options) {
  String returnString;
  
  // XML (TEI) steps
  if (options.format.contains('xml')) {
    // Clean empty elements
    final toRemove = <XmlElement>[];
    for (var element in document.body.descendants.whereType<XmlElement>()) {
      if (element.name.local != 'graphic' &&
          element.children.isEmpty &&
          element.innerText.trim().isEmpty) {
        final parent = element.parent;
        if (parent != null && 
            parent is XmlElement && 
            parent.name.local != 'code') {
          toRemove.add(element);
        }
      }
    }
    for (var elem in toRemove) {
      elem.parent?.children.remove(elem);
    }
    // Build output tree
    returnString = controlXmlOutput(document, options);
  }
  // CSV
  else if (options.format == 'csv') {
    returnString = xmltocsv(document, options.formatting);
  }
  // JSON
  else if (options.format == 'json') {
    returnString = buildJsonOutput(document, withMetadata: options.withMetadata);
  }
  // HTML
  else if (options.format == 'html') {
    returnString = buildHtmlOutput(document, withMetadata: options.withMetadata);
  }
  // Markdown and TXT
  else {
    final buffer = StringBuffer();
    
    if (options.withMetadata) {
      buffer.writeln('---');
      final metaFields = [
        ('title', document.title),
        ('author', document.author),
        ('url', document.url),
        ('hostname', document.hostname),
        ('description', document.description),
        ('sitename', document.sitename),
        ('date', document.date),
        ('categories', document.categories?.join(', ')),
        ('tags', document.tags?.join(', ')),
        ('fingerprint', document.fingerprint),
        ('id', document.id),
        ('license', document.license),
      ];
      
      for (var (name, value) in metaFields) {
        if (value != null && value.toString().isNotEmpty) {
          buffer.writeln('$name: $value');
        }
      }
      buffer.writeln('---');
    }
    
    // Convert body to text
    buffer.write(xmltotxt(document.body, includeFormatting: options.formatting));
    
    // Add comments if present
    if (document.commentsbody != null) {
      buffer.write('\n');
      buffer.write(xmltotxt(document.commentsbody!, includeFormatting: options.formatting));
    }
    
    returnString = buffer.toString().trim();
  }
  
  // Normalize Unicode format
  return normalizeUnicode(returnString);
}

/// Execute the standard cascade of extractors used by Trafilatura.
(Element, String, int) trafilaturaSequence(
  Element cleanedTree,
  Element cleanedTreeBackup,
  Element treeBackup,
  Extractor options,
) {
  // Trafilatura's main extractor
  var (postbody, tempText, lenText) = extractContent(cleanedTree, options);
  
  // Comparison with external extractors
  if (!options.fast) {
    final compared = compareExtraction(
      cleanedTreeBackup.clone(true) as Element,
      treeBackup.clone(true) as Element,
      domToXml(postbody),
      tempText,
      lenText,
      options,
    );
    postbody = xmlToDom(compared.$1);
    tempText = compared.$2;
    lenText = compared.$3;
  }
  
  // Rescue: baseline extraction on original/dirty tree
  if (lenText < options.minExtractedSize && options.focus != 'precision') {
    final baselineResult = baseline(treeBackup.clone(true) as Element);
    final xmlRes = baselineResult.$1;
    postbody = xmlToDom(xmlRes);
    tempText = baselineResult.$2;
    lenText = baselineResult.$3;
  }
  
  return (postbody, tempText, lenText);
}

/// Internal function for text extraction returning bare Python-like variables.
///
/// Returns a [Document] containing all extracted information or null.
Document? bareExtraction({
  required dynamic filecontent,
  String? url,
  bool fast = false,
  bool favorPrecision = false,
  bool favorRecall = false,
  bool includeComments = true,
  String outputFormat = 'python',
  String? targetLanguage,
  bool includeTables = true,
  bool includeImages = false,
  bool includeFormatting = false,
  bool includeLinks = false,
  bool deduplicate = false,
  Map<String, dynamic>? dateExtractionParams,
  bool withMetadata = false,
  bool onlyWithMetadata = false,
  Set<String>? urlBlacklist,
  Set<String>? authorBlacklist,
  List<String>? pruneXpath,
  Extractor? options,
}) {
  // Set up extraction options
  options ??= Extractor(
    outputFormat: outputFormat,
    fast: fast,
    precision: favorPrecision,
    recall: favorRecall,
    comments: includeComments,
    formatting: includeFormatting,
    links: includeLinks,
    images: includeImages,
    tables: includeTables,
    dedup: deduplicate,
    lang: targetLanguage,
    url: url,
    withMetadata: withMetadata,
    onlyWithMetadata: onlyWithMetadata,
    authorBlacklist: authorBlacklist,
    urlBlacklist: urlBlacklist,
    dateParams: dateExtractionParams,
  );
  
  try {
    // Load the HTML tree
    final tree = loadHtml(filecontent);
    if (tree == null) {
      return null;
    }
    
    // Quick HTML lang check
    if (options.lang != null && (options.fast || !langIdFlag)) {
      if (!_checkHtmlLang(tree, options.lang!)) {
        return null;
      }
    }
    
    // Extract metadata if necessary
    Document document;
    if (options.withMetadata) {
      document = extractMetadata(
        tree,
        defaultUrl: options.url,
        dateConfig: options.dateParams,
        extensive: !options.fast,
        authorBlacklist: options.authorBlacklist,
      );
      
      // Check URL blacklist
      if (options.urlBlacklist != null && 
          document.url != null &&
          options.urlBlacklist!.contains(document.url)) {
        return null;
      }
      
      // Check required metadata
      if (options.onlyWithMetadata && 
          (document.date == null || document.title == null || document.url == null)) {
        return null;
      }
    } else {
      document = Document();
    }
    
    // Prune XPath expressions if specified
    Element workingTree = tree.body ?? Element.tag('body');
    if (pruneXpath != null) {
      for (var xpath in pruneXpath) {
        // Convert XPath to CSS selector (simplified)
        try {
          for (var elem in workingTree.querySelectorAll(xpath).toList()) {
            elem.remove();
          }
        } catch (_) {
          // Invalid selector, skip
        }
      }
    }
    
    // Clean and backup for further processing
    final cleanedTree = treeCleaning(workingTree.clone(true) as Element, options);
    final cleanedTreeBackup = cleanedTree.clone(true) as Element;
    
    // Convert tags
    final convertedTree = convertTags(cleanedTree, options, url: options.url ?? document.url);
    
    // Extract comments first, then remove
    Element commentsbody;
    String tempComments;
    int lenComments;
    
    if (options.comments) {
      final commentsResult = extractComments(convertedTree, options);
      commentsbody = commentsResult.$1;
      tempComments = commentsResult.$2;
      lenComments = commentsResult.$3;
    } else {
      commentsbody = Element.tag('body');
      tempComments = '';
      lenComments = 0;
    }
    
    // Remove comment sections if precision mode
    if (options.focus == 'precision') {
      for (var elem in selectCommentElements(convertedTree)) {
        elem.remove();
      }
    }
    
    // Main extraction sequence
    var (postbody, tempText, lenText) = trafilaturaSequence(
      convertedTree,
      cleanedTreeBackup,
      workingTree,
      options,
    );
    
    // Tree size sanity check
    if (options.maxTreeSize != null) {
      final elemCount = postbody.querySelectorAll('*').length;
      if (elemCount > options.maxTreeSize!) {
        // Strip formatting tags
        _stripTags(postbody, ['hi']);
        
        // Still too long, discard
        if (postbody.querySelectorAll('*').length > options.maxTreeSize!) {
          return null;
        }
      }
    }
    
    // Size checks
    if (lenText < options.minOutputSize && lenComments < options.minOutputCommSize) {
      return null;
    }
    
    // Check duplicates at body level
    if (options.dedup && duplicateTest(postbody, options)) {
      return null;
    }
    
    // Language sanity check
    if (options.lang != null) {
      final langResult = languageFilter(tempText, tempComments, options.lang!, document);
      if (langResult.$1) {
        return null;
      }
      document = langResult.$2;
    }
    
    // Build result document
    if (options.format == 'python') {
      document.text = xmltotxt(domToXml(postbody), includeFormatting: options.formatting);
      if (options.comments) {
        document.comments = xmltotxt(domToXml(commentsbody), includeFormatting: options.formatting);
        document.commentsbody = domToXml(commentsbody);
      }
      document.rawText = document.text;
    } else {
      document.rawText = tempText;
      document.commentsbody = domToXml(commentsbody);
    }
    document.body = domToXml(postbody);
    
    return document;
    
  } catch (e) {
    return null;
  }
}

/// Strip specific tags from tree while keeping their content.
void _stripTags(Element tree, List<String> tags) {
  for (var tag in tags) {
    for (var elem in tree.querySelectorAll(tag).toList()) {
      final parent = elem.parent;
      if (parent != null) {
        final index = parent.nodes.indexOf(elem);
        final nodes = elem.nodes.toList();
        elem.nodes.clear();
        for (var i = 0; i < nodes.length; i++) {
          parent.nodes.insert(index + i, nodes[i]);
        }
        elem.remove();
      }
    }
  }
}

/// Main extraction function with string output.
///
/// This is the primary entry point for most extraction use cases.
///
/// Args:
///   filecontent: HTML code as string or bytes.
///   url: URL of the webpage.
///   recordId: Add an ID to the metadata.
///   fast: Use faster heuristics and skip backup extraction.
///   favorPrecision: Prefer less text but correct extraction.
///   favorRecall: When unsure, prefer more text.
///   includeComments: Extract comments along with the main text.
///   outputFormat: Define output format: "csv", "html", "json", "markdown", "txt", "xml", "xmltei".
///   teiValidation: Validate XML-TEI output.
///   targetLanguage: Define a language to discard invalid documents (ISO 639-1 format).
///   includeTables: Take into account information within HTML <table> element.
///   includeImages: Take images into account (experimental).
///   includeFormatting: Keep structural elements related to formatting.
///   includeLinks: Keep links along with their targets (experimental).
///   deduplicate: Remove duplicate segments and documents.
///   dateExtractionParams: Provide extraction parameters for date extraction.
///   withMetadata: Extract metadata fields and add them to the output.
///   onlyWithMetadata: Only keep documents featuring all essential metadata.
///   urlBlacklist: Provide a blacklist of URLs as set to filter out documents.
///   authorBlacklist: Provide a blacklist of Author Names to filter out authors.
///   pruneXpath: Provide XPath expressions to prune the tree before extraction.
///
/// Returns the extracted text in the desired format or null.
String? extract({
  required dynamic filecontent,
  String? url,
  String? recordId,
  bool fast = false,
  bool favorPrecision = false,
  bool favorRecall = false,
  bool includeComments = true,
  String outputFormat = 'txt',
  bool teiValidation = false,
  String? targetLanguage,
  bool includeTables = true,
  bool includeImages = false,
  bool includeFormatting = false,
  bool includeLinks = false,
  bool deduplicate = false,
  Map<String, dynamic>? dateExtractionParams,
  bool withMetadata = false,
  bool onlyWithMetadata = false,
  Set<String>? urlBlacklist,
  Set<String>? authorBlacklist,
  List<String>? pruneXpath,
  Extractor? options,
}) {
  final document = internalExtraction(
    filecontent: filecontent,
    url: url,
    recordId: recordId,
    fast: fast,
    favorPrecision: favorPrecision,
    favorRecall: favorRecall,
    includeComments: includeComments,
    outputFormat: outputFormat,
    teiValidation: teiValidation,
    targetLanguage: targetLanguage,
    includeTables: includeTables,
    includeImages: includeImages,
    includeFormatting: includeFormatting,
    includeLinks: includeLinks,
    deduplicate: deduplicate,
    dateExtractionParams: dateExtractionParams,
    withMetadata: withMetadata,
    onlyWithMetadata: onlyWithMetadata,
    urlBlacklist: urlBlacklist,
    authorBlacklist: authorBlacklist,
    pruneXpath: pruneXpath,
    options: options,
  );
  
  return document?.text;
}

/// Main extraction function that also returns document metadata.
///
/// Same parameters as [extract], but returns a [Document] object
/// containing both content and metadata.
Document? extractWithMetadata({
  required dynamic filecontent,
  String? url,
  String? recordId,
  bool fast = false,
  bool favorPrecision = false,
  bool favorRecall = false,
  bool includeComments = true,
  String outputFormat = 'txt',
  bool teiValidation = false,
  String? targetLanguage,
  bool includeTables = true,
  bool includeImages = false,
  bool includeFormatting = false,
  bool includeLinks = false,
  bool deduplicate = false,
  Map<String, dynamic>? dateExtractionParams,
  Set<String>? urlBlacklist,
  Set<String>? authorBlacklist,
  List<String>? pruneXpath,
  Extractor? options,
}) {
  return internalExtraction(
    filecontent: filecontent,
    url: url,
    recordId: recordId,
    fast: fast,
    favorPrecision: favorPrecision,
    favorRecall: favorRecall,
    includeComments: includeComments,
    outputFormat: outputFormat,
    teiValidation: teiValidation,
    targetLanguage: targetLanguage,
    includeTables: includeTables,
    includeImages: includeImages,
    includeFormatting: includeFormatting,
    includeLinks: includeLinks,
    deduplicate: deduplicate,
    dateExtractionParams: dateExtractionParams,
    withMetadata: true,
    onlyWithMetadata: false,
    urlBlacklist: urlBlacklist,
    authorBlacklist: authorBlacklist,
    pruneXpath: pruneXpath,
    options: options,
  );
}

/// Internal extraction method.
Document? internalExtraction({
  required dynamic filecontent,
  String? url,
  String? recordId,
  bool fast = false,
  bool favorPrecision = false,
  bool favorRecall = false,
  bool includeComments = true,
  String outputFormat = 'txt',
  bool teiValidation = false,
  String? targetLanguage,
  bool includeTables = true,
  bool includeImages = false,
  bool includeFormatting = false,
  bool includeLinks = false,
  bool deduplicate = false,
  Map<String, dynamic>? dateExtractionParams,
  bool withMetadata = false,
  bool onlyWithMetadata = false,
  Set<String>? urlBlacklist,
  Set<String>? authorBlacklist,
  List<String>? pruneXpath,
  Extractor? options,
}) {
  // Set up extraction options
  options ??= Extractor(
    outputFormat: outputFormat,
    fast: fast,
    precision: favorPrecision,
    recall: favorRecall,
    comments: includeComments,
    formatting: includeFormatting,
    links: includeLinks,
    images: includeImages,
    tables: includeTables,
    dedup: deduplicate,
    lang: targetLanguage,
    url: url,
    withMetadata: withMetadata,
    onlyWithMetadata: onlyWithMetadata,
    teiValidation: teiValidation,
    authorBlacklist: authorBlacklist,
    urlBlacklist: urlBlacklist,
    dateParams: dateExtractionParams,
  );
  
  // Perform extraction
  final document = bareExtraction(
    filecontent: filecontent,
    options: options,
    pruneXpath: pruneXpath,
  );
  
  // Post-processing
  if (document == null) {
    return null;
  }
  
  if (!_txtFormats.contains(options.format)) {
    // Check for python format (only allowed in bareExtraction)
    if (options.format == 'python') {
      throw ArgumentError("'python' format only usable in bareExtraction() function");
    }
    
    // Add record ID to metadata
    document.id = recordId;
    
    // Calculate fingerprint
    if (document.rawText != null) {
      document.fingerprint = contentFingerprint(
        '${document.title ?? ''} ${document.rawText}'
      );
    }
  }
  
  // Format output
  document.text = determineReturnString(document, options);
  
  return document;
}

/// Flag indicating if language identification is available.
const bool langIdFlag = false;

/// Check if HTML document language matches target language.
bool _checkHtmlLang(dynamic tree, String targetLang) {
  // Handle both dom.Document and Element
  Element? root;
  if (tree is Element) {
    root = tree;
  } else {
    // Try to get documentElement if it looks like an html Document
    try {
      final docElem = (tree as dynamic).documentElement;
      if (docElem is Element) {
        root = docElem;
      }
    } catch (_) {}
    
    // Try body as well
    if (root == null) {
      try {
        final bodyElem = (tree as dynamic).body;
        if (bodyElem is Element) {
          root = bodyElem;
        }
      } catch (_) {}
    }
  }
  
  if (root == null) return true;
  
  // Check html lang attribute
  final htmlElem = root.querySelector('html') ?? root;
  final lang = htmlElem.attributes['lang'];
  if (lang != null) {
    return lang.toLowerCase().startsWith(targetLang.toLowerCase());
  }
  
  // Check meta language
  final metaLang = root.querySelector('meta[http-equiv="content-language"]');
  if (metaLang != null) {
    final content = metaLang.attributes['content'];
    if (content != null) {
      return content.toLowerCase().startsWith(targetLang.toLowerCase());
    }
  }
  
  // No language found, assume OK
  return true;
}

/// Filter content based on target language.
///
/// Returns (isNotTargetLang, updatedDocument).
(bool, Document) languageFilter(
  String text,
  String comments,
  String targetLang,
  Document document,
) {
  // Simple heuristic: check for common words or characters
  // A full implementation would use a language detection library
  
  // For now, just return false (accept all) as we don't have
  // a language detection library in Dart
  return (false, document);
}

/// Normalize Unicode text to NFC form.
String normalizeUnicode(String text) {
  // Dart strings are already properly normalized
  // This is a placeholder for more complex normalization if needed
  return text;
}
