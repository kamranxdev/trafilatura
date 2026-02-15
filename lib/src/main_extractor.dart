/// Main content extraction logic for Trafilatura.
///
/// This module handles the core extraction of text content, formatting,
/// and structure from HTML documents.
library;

import 'package:html/dom.dart';

import 'settings.dart';
import 'xpaths.dart';

/// Tags that should not appear at the end of extracted content.
const Set<String> _notAtTheEnd = {'head', 'fw'};

/// Tags for code and quotes.
const Set<String> _codesQuotes = {'pre', 'code', 'blockquote', 'q', 'quote'};

/// Formatting tags.
const Set<String> _formatting = {'em', 'i', 'b', 'strong', 'u', 'sub', 'sup', 'del', 'strike', 'abbr'};

/// List tags.
const Set<String> _listTags = {'ul', 'ol', 'dl'};

/// Ensure elem.text is not null, empty, or just whitespace.
bool _textCharsTest(String? text) {
  return text != null && text.trim().isNotEmpty;
}

/// Safely get element text.
String _getText(Element elem) {
  return elem.text.trim();
}

/// Get all text content including nested elements.
String _getAllText(Element elem) {
  return elem.text;
}

/// Strip specific tags from tree while keeping their content.
void _stripTags(Element tree, List<String> tags) {
  for (var tag in tags) {
    for (var elem in tree.querySelectorAll(tag).toList()) {
      // Move children to parent before removing
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

/// Strip elements completely (remove them and their content).
void _stripElements(Element tree, String tag) {
  for (var elem in tree.querySelectorAll(tag).toList()) {
    elem.remove();
  }
}

/// Create a new element with optional text content.
Element _createElement(String tag, {String? text, Map<String, String>? attributes}) {
  final elem = Element.tag(tag);
  if (text != null) elem.text = text;
  if (attributes != null) {
    elem.attributes.addAll(attributes);
  }
  return elem;
}

/// Handle title/heading elements.
Element? handleTitles(Element element, Extractor options) {
  final text = _getText(element);
  if (!_textCharsTest(text)) return null;
  
  // Determine heading level
  var tag = element.localName ?? 'head';
  if (tag.startsWith('h') && tag.length == 2) {
    // h1-h6 -> keep level
    final level = int.tryParse(tag.substring(1));
    if (level != null && level >= 1 && level <= 6) {
      // Create head element with level
      final headElem = _createElement('head', text: text);
      headElem.attributes['rend'] = 'h$level';
      return headElem;
    }
  }
  
  // Default heading
  final headElem = _createElement('head', text: text);
  return headElem;
}

/// Handle formatting elements (em, strong, etc.).
Element? handleFormatting(Element element, Extractor options) {
  final text = _getText(element);
  if (!_textCharsTest(text)) return null;
  
  final tag = element.localName ?? 'hi';
  
  // Map HTML formatting to TEI-like elements
  String? rend;
  switch (tag) {
    case 'em':
    case 'i':
      rend = 'italic';
      break;
    case 'b':
    case 'strong':
      rend = 'bold';
      break;
    case 'u':
      rend = 'underline';
      break;
    case 'sub':
      rend = 'subscript';
      break;
    case 'sup':
      rend = 'superscript';
      break;
    case 'del':
    case 'strike':
      rend = 'strikethrough';
      break;
    case 'abbr':
      rend = 'abbr';
      break;
    default:
      rend = null;
  }
  
  final hiElem = _createElement('hi', text: text);
  if (rend != null) {
    hiElem.attributes['rend'] = rend;
  }
  return hiElem;
}

/// Handle list elements (ul, ol, dl).
Element? handleLists(Element element, Extractor options) {
  final listElem = _createElement('list');
  
  // Process list items
  final items = element.querySelectorAll('li, dt, dd');
  if (items.isEmpty) return null;
  
  var hasContent = false;
  for (var item in items) {
    final text = _getText(item);
    if (_textCharsTest(text)) {
      final itemElem = _createElement('item', text: text);
      listElem.append(itemElem);
      hasContent = true;
    }
  }
  
  return hasContent ? listElem : null;
}

/// Handle blockquote and quote elements.
Element? handleQuotes(Element element, Extractor options) {
  final text = _getAllText(element);
  if (!_textCharsTest(text)) return null;
  
  final quoteElem = _createElement('quote');
  
  // Process paragraphs within quote
  final paragraphs = element.querySelectorAll('p');
  if (paragraphs.isNotEmpty) {
    for (var p in paragraphs) {
      final pText = _getText(p);
      if (_textCharsTest(pText)) {
        final pElem = _createElement('p', text: pText);
        quoteElem.append(pElem);
      }
    }
  } else {
    // No paragraphs, use text directly
    quoteElem.text = text.trim();
  }
  
  return quoteElem.children.isNotEmpty || _textCharsTest(quoteElem.text) 
      ? quoteElem : null;
}

/// Handle code/pre elements.
Element? handleCodeBlocks(Element element, Extractor options) {
  final tag = element.localName;
  final text = _getAllText(element);
  if (!_textCharsTest(text)) return null;
  
  // Preserve code formatting
  Element codeElem;
  if (tag == 'pre') {
    codeElem = _createElement('code');
    // Try to detect language from class
    final className = element.className;
    if (className.isNotEmpty) {
      final langMatch = RegExp(r'language-(\w+)').firstMatch(className);
      if (langMatch != null) {
        codeElem.attributes['lang'] = langMatch.group(1)!;
      }
    }
  } else {
    codeElem = _createElement('code');
  }
  
  codeElem.text = text;
  return codeElem;
}

/// Handle paragraphs.
Element? handleParagraphs(Element element, Set<String> potentialTags, Extractor options) {
  final text = _getText(element);
  
  // Check minimum length
  if (text.length < options.minExtractedSize ~/ 4) {
    return null;
  }
  
  if (!_textCharsTest(text)) return null;
  
  final pElem = _createElement('p');
  
  // Handle inline elements if links are enabled
  if (potentialTags.contains('ref') && options.links) {
    // Process links within paragraph
    final links = element.querySelectorAll('a[href]');
    if (links.isNotEmpty) {
      // Complex case: preserve link structure
      for (var link in links) {
        final linkText = _getText(link);
        final href = link.attributes['href'];
        if (_textCharsTest(linkText) && href != null) {
          final refElem = _createElement('ref', text: linkText);
          refElem.attributes['target'] = href;
          pElem.append(refElem);
        }
      }
      if (pElem.children.isEmpty) {
        pElem.text = text;
      }
    } else {
      pElem.text = text;
    }
  } else {
    pElem.text = text;
  }
  
  return pElem;
}

/// Handle table elements.
Element? handleTable(Element element, Set<String> potentialTags, Extractor options) {
  if (!options.tables) return null;
  
  final tableElem = _createElement('table');
  
  // Process rows
  final rows = element.querySelectorAll('tr');
  var hasContent = false;
  
  for (var row in rows) {
    final rowElem = _createElement('row');
    final cells = row.querySelectorAll('td, th');
    
    for (var cell in cells) {
      final text = _getText(cell);
      final cellElem = _createElement('cell');
      if (cell.localName == 'th') {
        cellElem.attributes['role'] = 'head';
      }
      cellElem.text = text;
      rowElem.append(cellElem);
    }
    
    if (rowElem.children.isNotEmpty) {
      tableElem.append(rowElem);
      hasContent = true;
    }
  }
  
  return hasContent ? tableElem : null;
}

/// Handle image/graphic elements.
Element? handleImage(Element element, Extractor options) {
  if (!options.images) return null;
  
  final src = element.attributes['src'] ?? 
              element.attributes['data-src'] ?? '';
  if (src.isEmpty) return null;
  
  final graphicElem = _createElement('graphic');
  graphicElem.attributes['src'] = src;
  
  // Add alt text if available
  final alt = element.attributes['alt'];
  if (alt != null && alt.isNotEmpty) {
    graphicElem.attributes['alt'] = alt;
  }
  
  // Add title if available
  final title = element.attributes['title'];
  if (title != null && title.isNotEmpty) {
    graphicElem.attributes['title'] = title;
  }
  
  return graphicElem;
}

/// Handle other/miscellaneous elements.
Element? handleOtherElements(Element element, Set<String> potentialTags, Extractor options) {
  final tag = element.localName ?? 'div';
  
  // Handle divs that might contain useful content
  if (tag == 'div') {
    final text = _getText(element);
    if (_textCharsTest(text) && text.length >= options.minExtractedSize ~/ 2) {
      return _createElement('p', text: text);
    }
  }
  
  // Handle line breaks with text
  if (tag == 'lb' || tag == 'br') {
    // These don't typically have content
    return null;
  }
  
  // Handle spans if needed
  if (tag == 'span' && potentialTags.contains('span')) {
    final text = _getText(element);
    if (_textCharsTest(text)) {
      return _createElement('hi', text: text);
    }
  }
  
  return null;
}

/// Process text element and determine how to deal with its content.
Element? handleTextElem(Element element, Set<String> potentialTags, Extractor options) {
  final tag = element.localName ?? '';
  
  // Handle lists
  if (_listTags.contains(tag) || tag == 'list') {
    return handleLists(element, options);
  }
  
  // Handle code and quotes
  if (_codesQuotes.contains(tag)) {
    if (tag == 'pre' || tag == 'code') {
      return handleCodeBlocks(element, options);
    } else {
      return handleQuotes(element, options);
    }
  }
  
  // Handle headings
  if (tag == 'head' || (tag.startsWith('h') && tag.length == 2)) {
    return handleTitles(element, options);
  }
  
  // Handle paragraphs
  if (tag == 'p') {
    return handleParagraphs(element, potentialTags, options);
  }
  
  // Handle line breaks with trailing text
  if (tag == 'lb' || tag == 'br') {
    // In Dart DOM, we handle this differently
    return null;
  }
  
  // Handle formatting
  if (_formatting.contains(tag)) {
    return handleFormatting(element, options);
  }
  
  // Handle tables
  if (tag == 'table' && potentialTags.contains('table')) {
    return handleTable(element, potentialTags, options);
  }
  
  // Handle images
  if ((tag == 'img' || tag == 'graphic') && potentialTags.contains('graphic')) {
    return handleImage(element, options);
  }
  
  // Other elements
  return handleOtherElements(element, potentialTags, options);
}

/// Look for all previously unconsidered wild elements to recover potentially missing text.
Element recoverWildText(Element tree, Element resultBody, Extractor options, Set<String> potentialTags) {
  // Search for various text-containing elements
  final searchSelectors = [
    'blockquote', 'code', 'p', 'pre', 'q', 'table',
    'div.w3-code'
  ];
  
  if (options.focus == 'recall') {
    potentialTags.addAll(['div', 'lb']);
    searchSelectors.addAll(['div', 'ul', 'ol']);
  }
  
  // Prune unwanted sections first
  final searchTree = pruneUnwantedSections(tree, potentialTags, options);
  
  // Strip tags based on options
  if (!potentialTags.contains('ref')) {
    _stripTags(searchTree, ['a', 'ref', 'span']);
  } else {
    _stripTags(searchTree, ['span']);
  }
  
  // Find elements
  for (var selector in searchSelectors) {
    try {
      final elems = searchTree.querySelectorAll(selector);
      for (var elem in elems) {
        final processed = handleTextElem(elem, potentialTags, options);
        if (processed != null) {
          resultBody.append(processed);
        }
      }
    } catch (_) {
      // Selector might not be valid, skip
    }
  }
  
  return resultBody;
}

/// Rule-based deletion of targeted document sections.
Element pruneUnwantedSections(Element tree, Set<String> potentialTags, Extractor options) {
  final favorPrecision = options.focus == 'precision';
  
  // Prune overall discard elements
  for (var elem in selectElementsToDiscard(tree)) {
    elem.remove();
  }
  
  // Decide if images are preserved
  if (!potentialTags.contains('graphic')) {
    // Remove image elements
    for (var elem in tree.querySelectorAll('img, figure, picture').toList()) {
      elem.remove();
    }
  }
  
  // Balance precision/recall
  if (options.focus != 'recall') {
    // Remove teaser/promo elements
    for (var selector in ['.teaser', '.promo', '.advertisement', '.sponsored']) {
      try {
        for (var elem in tree.querySelectorAll(selector).toList()) {
          elem.remove();
        }
      } catch (_) {}
    }
    
    if (favorPrecision) {
      // More aggressive pruning for precision
      for (var selector in ['.related', '.sidebar', 'aside', '.widget', '.share']) {
        try {
          for (var elem in tree.querySelectorAll(selector).toList()) {
            elem.remove();
          }
        } catch (_) {}
      }
    }
  }
  
  // Remove elements by link density (multiple passes)
  for (var i = 0; i < 2; i++) {
    _deleteByLinkDensity(tree, 'div', favorPrecision: favorPrecision);
    _deleteByLinkDensity(tree, 'ul', favorPrecision: favorPrecision);
    _deleteByLinkDensity(tree, 'p', favorPrecision: favorPrecision);
  }
  
  // Handle tables
  if (potentialTags.contains('table') || favorPrecision) {
    for (var elem in tree.querySelectorAll('table').toList()) {
      final linkDensity = _calculateLinkDensity(elem);
      if (linkDensity > 0.5) {
        elem.remove();
      }
    }
  }
  
  // Additional precision filtering
  if (favorPrecision) {
    // Delete trailing titles
    while (tree.children.isNotEmpty && tree.children.last.localName == 'head') {
      tree.children.last.remove();
    }
    
    _deleteByLinkDensity(tree, 'head', favorPrecision: true);
    _deleteByLinkDensity(tree, 'blockquote', favorPrecision: true);
  }
  
  return tree;
}

/// Calculate link density for an element.
double _calculateLinkDensity(Element elem) {
  final text = _getAllText(elem);
  if (text.isEmpty) return 0.0;
  
  var linkText = '';
  for (var link in elem.querySelectorAll('a')) {
    linkText += _getAllText(link);
  }
  
  return linkText.length / text.length;
}

/// Delete elements by link density.
void _deleteByLinkDensity(Element tree, String tag, {bool favorPrecision = false}) {
  final threshold = favorPrecision ? 0.25 : 0.5;
  
  for (var elem in tree.querySelectorAll(tag).toList()) {
    final density = _calculateLinkDensity(elem);
    if (density > threshold) {
      elem.remove();
    }
  }
}

/// Internal extraction function.
(Element, String, Set<String>) _extract(Element tree, Extractor options) {
  // Initialize potential tags
  Set<String> potentialTags = {};
  final tagCatalog = DefaultConfig.tagCatalog;
  if (tagCatalog.containsKey('body')) {
    potentialTags.addAll(tagCatalog['body']!);
  }
  
  if (options.tables) {
    potentialTags.addAll(['table', 'td', 'th', 'tr']);
  }
  if (options.images) {
    potentialTags.add('graphic');
  }
  if (options.links) {
    potentialTags.add('ref');
  }
  
  final resultBody = _createElement('body');
  
  // Get body selection expressions
  final bodyElements = selectBodyElements(tree);
  
  for (var subtree in bodyElements) {
    // Prune the subtree
    subtree = pruneUnwantedSections(subtree, potentialTags, options);
    
    // Skip if empty
    if (subtree.children.isEmpty && subtree.text.trim().isEmpty) {
      continue;
    }
    
    // Check paragraph content
    final paragraphs = subtree.querySelectorAll('p');
    final pText = paragraphs.map((e) => _getAllText(e)).join('');
    
    final factor = options.focus == 'precision' ? 1 : 3;
    if (paragraphs.isEmpty || pText.length < options.minExtractedSize * factor) {
      potentialTags.add('div');
    }
    
    // Strip tags based on options
    if (!potentialTags.contains('ref')) {
      _stripTags(subtree, ['ref']);
    }
    if (!potentialTags.contains('span')) {
      _stripTags(subtree, ['span']);
    }
    
    // Extract content from all subelements
    for (var elem in subtree.querySelectorAll('*')) {
      final processed = handleTextElem(elem, potentialTags, options);
      if (processed != null) {
        resultBody.append(processed);
      }
    }
    
    // Remove trailing titles
    while (resultBody.children.isNotEmpty && 
           _notAtTheEnd.contains(resultBody.children.last.localName)) {
      resultBody.children.last.remove();
    }
    
    // Exit if we have content
    if (resultBody.children.length > 1) {
      break;
    }
  }
  
  final tempText = _getAllText(resultBody).trim();
  return (resultBody, tempText, potentialTags);
}

/// Find the main content of a page using XPath expressions.
///
/// Returns a tuple of (body element, text content, text length).
(Element, String, int) extractContent(Element cleanedTree, Extractor options) {
  // Make a backup for recovery
  final backupTree = cleanedTree.clone(true);
  
  var (resultBody, tempText, potentialTags) = _extract(cleanedTree, options);
  
  // Try parsing wild elements if nothing found or text too short
  if (resultBody.children.isEmpty || tempText.length < options.minExtractedSize) {
    resultBody = recoverWildText(backupTree, resultBody, options, potentialTags);
    tempText = resultBody.text.trim();
  }
  
  // Filter output
  _stripElements(resultBody, 'done');
  _stripTags(resultBody, ['div']);
  
  return (resultBody, tempText, tempText.length);
}

/// Process comment node and determine how to deal with its content.
Element? processCommentsNode(Element elem, Set<String> potentialTags, Extractor options) {
  final tag = elem.localName ?? '';
  
  if (potentialTags.contains(tag)) {
    final text = _getText(elem);
    if (_textCharsTest(text)) {
      final processedElem = _createElement('p', text: text);
      return processedElem;
    }
  }
  
  return null;
}

/// Try to extract comments out of potential sections in the HTML.
///
/// Returns a tuple of (comments body, text, length, modified tree).
(Element, String, int, Element) extractComments(Element tree, Extractor options) {
  final commentsBody = _createElement('body');
  
  // Define potential tags for comments
  Set<String> potentialTags = {};
  final tagCatalog = DefaultConfig.tagCatalog;
  if (tagCatalog.containsKey('comments')) {
    potentialTags.addAll(tagCatalog['comments']!);
  }
  
  // Get comment elements
  final commentElements = selectCommentElements(tree);
  
  for (var subtree in commentElements) {
    // Prune unwanted nodes from comments
    for (var discardSelector in ['.reply', '.respond', 'form', '.hidden']) {
      try {
        for (var elem in subtree.querySelectorAll(discardSelector).toList()) {
          elem.remove();
        }
      } catch (_) {}
    }
    
    // Strip tags
    _stripTags(subtree, ['a', 'ref', 'span']);
    
    // Extract comment content
    for (var elem in subtree.querySelectorAll('*')) {
      final processed = processCommentsNode(elem, potentialTags, options);
      if (processed != null) {
        commentsBody.append(processed);
      }
    }
    
    // If we found comments, remove the subtree and exit
    if (commentsBody.children.isNotEmpty) {
      subtree.remove();
      break;
    }
  }
  
  final tempComments = _getAllText(commentsBody).trim();
  return (commentsBody, tempComments, tempComments.length, tree);
}

/// Handle text node processing with optional comments fix.
Element? handleTextNode(Element element, Extractor options, {bool commentsFix = false}) {
  var text = _getText(element);
  
  if (!_textCharsTest(text)) return null;
  
  // Clean up text
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  
  // Create output element
  final tag = element.localName ?? 'p';
  Element outputElem;
  
  // Determine output tag based on input
  if (tag == 'head' || (tag.startsWith('h') && tag.length == 2)) {
    outputElem = _createElement('head', text: text);
  } else if (_formatting.contains(tag)) {
    outputElem = _createElement('hi', text: text);
    String? rend;
    switch (tag) {
      case 'em':
      case 'i':
        rend = 'italic';
        break;
      case 'b':
      case 'strong':
        rend = 'bold';
        break;
      case 'u':
        rend = 'underline';
        break;
    }
    if (rend != null) {
      outputElem.attributes['rend'] = rend;
    }
  } else if (_codesQuotes.contains(tag)) {
    outputElem = _createElement(tag == 'code' || tag == 'pre' ? 'code' : 'quote', text: text);
  } else {
    outputElem = _createElement('p', text: text);
  }
  
  return outputElem;
}

/// Main function to extract text content from HTML.
///
/// This is the primary entry point for content extraction.
ExtractedContent extract(Element tree, Extractor options) {
  // Extract main content
  final (contentBody, contentText, contentLength) = extractContent(tree, options);
  
  // Extract comments if requested
  Element? commentsBody;
  String commentsText = '';
  int commentsLength = 0;
  
  if (options.comments) {
    final (cBody, cText, cLen, _) = extractComments(tree, options);
    commentsBody = cBody;
    commentsText = cText;
    commentsLength = cLen;
  }
  
  return ExtractedContent(
    body: contentBody,
    text: contentText,
    length: contentLength,
    commentsBody: commentsBody,
    commentsText: commentsText,
    commentsLength: commentsLength,
  );
}

/// Container for extracted content.
class ExtractedContent {
  /// The extracted body element.
  final Element body;
  
  /// The extracted text content.
  final String text;
  
  /// Length of extracted text.
  final int length;
  
  /// The extracted comments body element (if any).
  final Element? commentsBody;
  
  /// The extracted comments text.
  final String commentsText;
  
  /// Length of extracted comments.
  final int commentsLength;
  
  ExtractedContent({
    required this.body,
    required this.text,
    required this.length,
    this.commentsBody,
    this.commentsText = '',
    this.commentsLength = 0,
  });
  
  /// Check if content was successfully extracted.
  bool get hasContent => length > 0;
  
  /// Check if comments were extracted.
  bool get hasComments => commentsLength > 0;
  
  /// Get total extracted length (content + comments).
  int get totalLength => length + commentsLength;
}
