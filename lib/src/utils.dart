/// Utility functions for HTML and text processing.
///
/// Contains functions for encoding detection, HTML parsing, text normalization,
/// content filtering, and language detection.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart';

/// Flag indicating if language identification is available
const bool langidFlag = false; // Would need external package

/// Unicode alias encodings
const Set<String> unicodeAliases = {'utf-8', 'utf_8'};

/// DOCTYPE tag regex pattern
final RegExp doctypeTag = RegExp(r'^< ?! ?DOCTYPE[^>]*/[^<]*>', caseSensitive: false);

/// Faulty HTML regex pattern
final RegExp faultyHtml = RegExp(r'(<html.*?)\s*/>', caseSensitive: false);

/// HTML strip tags regex
final RegExp htmlStripTags = RegExp(r'(<!--.*?-->|<[^>]*>)');

/// Lines trimming regex
final RegExp linesTrimming = RegExp(r'(?<![p{P}>])\n', unicode: true, multiLine: true);

/// URL blacklist regex
final RegExp urlBlacklistRegex = RegExp(r'^https?://|/+$');

/// Image extension regex
final RegExp imageExtension = RegExp(r'[^\s]+\.(avif|bmp|gif|hei[cf]|jpe?g|png|webp)(\b|$)');

/// Protected formatting tags
const Set<String> formattingProtected = {'cell', 'head', 'hi', 'item', 'p', 'quote', 'ref', 'td'};

/// Protected spacing tags
const Set<String> spacingProtected = {'code', 'pre'};

/// Target language attributes
const List<String> targetLangAttrs = ['http-equiv="content-language"', 'property="og:locale"'];

/// HTML language regex
final RegExp reHtmlLang = RegExp(r'([a-z]{2})');

/// Filter regex for social media and other unwanted content
final RegExp reFilter = RegExp(
  r'\W*(Drucken|E-?Mail|Facebook|Flipboard|Google|Instagram|'
  r'Linkedin|Mail|PDF|Pinterest|Pocket|Print|QQ|Reddit|Twitter|'
  r'WeChat|WeiBo|Whatsapp|Xing|Mehr zum Thema:?|More on this.{0,8}$)$',
  caseSensitive: false,
);

/// Handle compressed file content.
///
/// Try to decompress a binary content using various compression algorithms.
/// Use magic numbers when available.
Uint8List handleCompressedFile(Uint8List filecontent) {
  // GZip magic number: 1f 8b 08
  if (filecontent.length >= 3 &&
      filecontent[0] == 0x1f &&
      filecontent[1] == 0x8b &&
      filecontent[2] == 0x08) {
    try {
      return Uint8List.fromList(gzip.decode(filecontent));
    } catch (e) {
      // Invalid GZ file
    }
  }
  
  // ZStandard magic number: 28 b5 2f fd
  if (filecontent.length >= 4 &&
      filecontent[0] == 0x28 &&
      filecontent[1] == 0xb5 &&
      filecontent[2] == 0x2f &&
      filecontent[3] == 0xfd) {
    // ZStandard not natively supported in Dart, return as-is
  }

  // Zlib/deflate
  try {
    return Uint8List.fromList(zlib.decode(filecontent));
  } catch (e) {
    // Not zlib compressed
  }

  return filecontent;
}

/// Simple heuristic to determine if a bytestring uses standard unicode encoding.
bool isUtf8(Uint8List data) {
  try {
    utf8.decode(data);
    return true;
  } catch (e) {
    return false;
  }
}

/// Read all input and return a list of possible encodings.
List<String> detectEncoding(Uint8List bytesobject) {
  if (isUtf8(bytesobject)) {
    return ['utf-8'];
  }
  
  // In Dart, charset detection is more limited
  // We try common encodings
  final guesses = <String>[];
  
  // Try Latin-1 as fallback
  try {
    latin1.decode(bytesobject);
    guesses.add('iso-8859-1');
  } catch (e) {
    // Not Latin-1
  }
  
  return guesses.where((g) => !unicodeAliases.contains(g)).toList();
}

/// Decode file content from bytes to string.
///
/// Handles compressed content and encoding detection.
String decodeFile(dynamic filecontent) {
  if (filecontent is String) {
    return filecontent;
  }
  
  if (filecontent is! Uint8List) {
    if (filecontent is List<int>) {
      filecontent = Uint8List.fromList(filecontent);
    } else {
      return filecontent.toString();
    }
  }
  
  String? htmltext;
  
  // Handle compressed content
  filecontent = handleCompressedFile(filecontent);
  
  // Try to detect encoding and decode
  for (final guessedEncoding in detectEncoding(filecontent)) {
    try {
      if (guessedEncoding == 'utf-8') {
        htmltext = utf8.decode(filecontent);
      } else if (guessedEncoding == 'iso-8859-1') {
        htmltext = latin1.decode(filecontent);
      }
      if (htmltext != null) break;
    } catch (e) {
      htmltext = null;
    }
  }
  
  // Fallback to UTF-8 with replacement
  return htmltext ?? utf8.decode(filecontent, allowMalformed: true);
}

/// Assess if the object is proper HTML (with a corresponding tag or declaration).
bool isDubiousHtml(String beginning) {
  return !beginning.contains('html');
}

/// Repair faulty HTML strings to make them palatable for parsing.
String repairFaultyHtml(String htmlstring, String beginning) {
  var result = htmlstring;
  
  // Remove DOCTYPE if malformed
  if (beginning.contains('doctype')) {
    final lines = result.split('\n');
    if (lines.isNotEmpty) {
      lines[0] = lines[0].replaceFirst(doctypeTag, '');
      result = lines.join('\n');
    }
  }
  
  // Fix malformed self-closing html tags
  final lines = result.split('\n');
  for (var i = 0; i < lines.length && i <= 2; i++) {
    if (lines[i].contains('<html') && lines[i].endsWith('/>')) {
      result = result.replaceFirst(faultyHtml, r'$1>');
      break;
    }
  }
  
  return result;
}

/// Load object given as input and validate its type.
///
/// Accepts: DOM Document, bytestring, and string.
dom.Document? loadHtml(dynamic htmlobject) {
  // Already a document
  if (htmlobject is dom.Document) {
    return htmlobject;
  }
  
  // Handle bytes
  if (htmlobject is Uint8List || htmlobject is List<int>) {
    htmlobject = decodeFile(htmlobject);
  }
  
  // Must be a string at this point
  if (htmlobject is! String) {
    throw TypeError();
  }
  
  // Sanity checks
  final beginning = htmlobject.substring(0, htmlobject.length < 50 ? htmlobject.length : 50).toLowerCase();
  final checkFlag = isDubiousHtml(beginning);
  
  // Repair first
  htmlobject = repairFaultyHtml(htmlobject, beginning);
  
  // Parse HTML
  dom.Document? tree;
  try {
    tree = html_parser.parse(htmlobject);
  } catch (e) {
    // Parsing failed
    return null;
  }
  
  // Rejection test
  if (tree != null && checkFlag && (tree.body?.children.length ?? 0) < 2) {
    return null;
  }
  
  return tree;
}

/// Cache for printable character lookup
final Map<String, String> _printablesCache = {};

/// Return a character if it belongs to printable classes.
String returnPrintablesAndSpaces(String char) {
  if (_printablesCache.containsKey(char)) {
    return _printablesCache[char]!;
  }
  
  final codeUnit = char.codeUnitAt(0);
  // Check if printable or space
  final isPrintable = codeUnit >= 32 && codeUnit != 127;
  final isSpace = char == ' ' || char == '\t' || char == '\n' || char == '\r';
  
  final result = (isPrintable || isSpace) ? char : '';
  _printablesCache[char] = result;
  return result;
}

/// Prevent non-printable and XML invalid character errors.
String removeControlCharacters(String string) {
  return string.split('').map(returnPrintablesAndSpaces).join();
}

/// Normalize the given string to the specified unicode format.
String normalizeUnicode(String string, [String unicodeform = 'NFC']) {
  // Dart doesn't have built-in Unicode normalization like Python
  // For now, return as-is
  return string;
}

/// Cache for line processing
final Map<String, String?> _lineProcessingCache = {};

/// Remove HTML space entities, then discard incompatible unicode
/// and invalid XML characters on line level.
String? lineProcessing(String line, {bool preserveSpace = false, bool trailingSpace = false}) {
  final cacheKey = '$line|$preserveSpace|$trailingSpace';
  if (_lineProcessingCache.containsKey(cacheKey)) {
    return _lineProcessingCache[cacheKey];
  }
  
  // Spacing HTML entities
  var newLine = removeControlCharacters(
    line.replaceAll('&#13;', '\r')
        .replaceAll('&#10;', '\n')
        .replaceAll('&nbsp;', '\u00A0')
  );
  
  String? result;
  if (!preserveSpace) {
    // Remove newlines and normalize space
    newLine = trim(newLine.replaceAll(linesTrimming, ' '));
    
    // Prune empty lines
    if (newLine.split('').every((c) => c.trim().isEmpty)) {
      result = null;
    } else if (trailingSpace) {
      final spaceBefore = line.isNotEmpty && line[0].trim().isEmpty ? ' ' : '';
      final spaceAfter = line.isNotEmpty && line[line.length - 1].trim().isEmpty ? ' ' : '';
      result = '$spaceBefore$newLine$spaceAfter';
    } else {
      result = newLine;
    }
  } else {
    result = newLine;
  }
  
  _lineProcessingCache[cacheKey] = result;
  return result;
}

/// Convert text and discard incompatible and invalid characters.
String? sanitize(String text, {bool preserveSpace = false, bool trailingSpace = false}) {
  if (trailingSpace) {
    return lineProcessing(text, preserveSpace: preserveSpace, trailingSpace: true);
  }
  
  try {
    final processed = text
        .split('\n')
        .map((l) => lineProcessing(l, preserveSpace: preserveSpace))
        .where((l) => l != null)
        .join('\n')
        .replaceAll('\u2424', '');
    return processed.isEmpty ? null : processed;
  } catch (e) {
    return null;
  }
}

/// Sanitize a DOM tree - trims spaces, removes control characters.
void sanitizeTree(dom.Element tree) {
  for (final elem in tree.querySelectorAll('*')) {
    final parentTag = elem.parent?.localName ?? '';
    
    final preserveSpace = spacingProtected.contains(elem.localName) ||
        spacingProtected.contains(parentTag);
    final trailingSpace = formattingProtected.contains(elem.localName) ||
        formattingProtected.contains(parentTag) ||
        preserveSpace;
    
    // Process text nodes
    for (final node in elem.nodes.toList()) {
      if (node is dom.Text) {
        final sanitized = sanitize(node.text, preserveSpace: preserveSpace, trailingSpace: trailingSpace);
        if (sanitized != null) {
          node.replaceWith(dom.Text(sanitized));
        }
      }
    }
  }
}

/// Remove unnecessary spaces within a text string.
String trim(String string) {
  try {
    return string.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).join(' ').trim();
  } catch (e) {
    return '';
  }
}

/// Check if an element is a valid img element.
bool isImageElement(dom.Element element) {
  for (final attr in ['data-src', 'src']) {
    final src = element.attributes[attr] ?? '';
    if (isImageFile(src)) {
      return true;
    }
  }
  
  // Check data-src* attributes
  for (final entry in element.attributes.entries) {
    final key = entry.key.toString();
    if (key.startsWith('data-src') && isImageFile(entry.value)) {
      return true;
    }
  }
  
  return false;
}

/// Check if the observed string corresponds to a valid image extension.
bool isImageFile(String? imagesrc) {
  if (imagesrc == null || imagesrc.length > 8192) {
    return false;
  }
  return imageExtension.hasMatch(imagesrc);
}

/// Chunk data into smaller pieces.
Iterable<List<T>> makeChunks<T>(Iterable<T> iterable, int n) sync* {
  final iterator = iterable.iterator;
  while (true) {
    final batch = <T>[];
    for (var i = 0; i < n; i++) {
      if (iterator.moveNext()) {
        batch.add(iterator.current);
      } else {
        break;
      }
    }
    if (batch.isEmpty) break;
    yield batch;
  }
}

/// Check if the document length is within acceptable boundaries.
bool isAcceptableLength(int myLen, dynamic options) {
  if (myLen < options.minFileSize) {
    return false;
  }
  if (myLen > options.maxFileSize) {
    return false;
  }
  return true;
}

/// Check HTML meta-elements for language information.
bool checkHtmlLang(dom.Document tree, String targetLanguage, {bool strict = false}) {
  // Check meta elements
  for (final attr in targetLangAttrs) {
    final elems = tree.querySelectorAll('meta[$attr][content]');
    if (elems.isNotEmpty) {
      for (final elem in elems) {
        final content = elem.attributes['content']?.toLowerCase() ?? '';
        final langs = reHtmlLang.allMatches(content).map((m) => m.group(1)!).toList();
        if (langs.contains(targetLanguage)) {
          return true;
        }
      }
      return false;
    }
  }
  
  // Check HTML lang attribute
  if (strict) {
    final htmlElems = tree.querySelectorAll('html[lang]');
    if (htmlElems.isNotEmpty) {
      for (final elem in htmlElems) {
        final lang = elem.attributes['lang']?.toLowerCase() ?? '';
        final langs = reHtmlLang.allMatches(lang).map((m) => m.group(1)!).toList();
        if (langs.contains(targetLanguage)) {
          return true;
        }
      }
      return false;
    }
  }
  
  return true;
}

/// Run external component for language identification.
String? languageClassifier(String tempText, String tempComments) {
  // Language detection would require external package
  // For now, return null
  return null;
}

/// Filter text based on language detection and store relevant information.
(bool, dynamic) languageFilter(
  String tempText,
  String tempComments,
  String? targetLanguage,
  dynamic docmeta,
) {
  if (targetLanguage != null) {
    docmeta.language = languageClassifier(tempText, tempComments);
    if (docmeta.language != null && docmeta.language != targetLanguage) {
      return (true, docmeta);
    }
  }
  return (false, docmeta);
}

/// Filter out unwanted text.
bool textfilter(dom.Element element) {
  final testtext = element.text;
  if (testtext.isEmpty || testtext.trim().isEmpty) {
    return true;
  }
  for (final line in testtext.split('\n')) {
    if (reFilter.hasMatch(line)) {
      return true;
    }
  }
  return false;
}

/// Determine if a string is only composed of spaces and/or control characters.
bool textCharsTest(String? string) {
  return string != null && string.isNotEmpty && string.trim().isNotEmpty;
}

/// Copy attributes from src element to dest element.
void copyAttributes(dom.Element destElem, dom.Element srcElem) {
  for (final entry in srcElem.attributes.entries) {
    destElem.attributes[entry.key] = entry.value;
  }
}

/// Check whether an element is in a table cell.
bool isInTableCell(dom.Element elem) {
  dom.Element? current = elem;
  while (current != null) {
    if (current.localName == 'cell' || current.localName == 'td' || current.localName == 'th') {
      return true;
    }
    current = current.parent;
  }
  return false;
}

/// Check whether an element is the last element in table cell.
bool isLastElementInCell(dom.Element elem) {
  if (!isInTableCell(elem)) {
    return false;
  }
  
  if (elem.localName == 'cell' || elem.localName == 'td' || elem.localName == 'th') {
    return elem.children.isEmpty || elem.children.last == elem;
  } else {
    final parent = elem.parent;
    if (parent == null) return false;
    return parent.children.isEmpty || parent.children.last == elem;
  }
}

/// Check whether an element is a list item or within a list item.
bool isElementInItem(dom.Element element) {
  dom.Element? current = element;
  while (current != null) {
    if (current.localName == 'item' || current.localName == 'li') {
      return true;
    }
    current = current.parent;
  }
  return false;
}

/// Check whether an element is the first element in list item.
bool isFirstElementInItem(dom.Element element) {
  if ((element.localName == 'item' || element.localName == 'li') && element.text.isNotEmpty) {
    return true;
  }
  
  dom.Element? current = element;
  dom.Element? itemAncestor;
  while (current != null) {
    if (current.localName == 'item' || current.localName == 'li') {
      itemAncestor = current;
      break;
    }
    current = current.parent;
  }
  
  if (itemAncestor == null) {
    return false;
  }
  
  // Check if item has no direct text
  for (final node in itemAncestor.nodes) {
    if (node is dom.Text && node.text.trim().isNotEmpty) {
      return false;
    }
  }
  return true;
}

/// Check whether an element is the last element in list item.
bool isLastElementInItem(dom.Element element) {
  if (!isElementInItem(element)) {
    return false;
  }
  
  // Pure text only in list item
  if (element.localName == 'item' || element.localName == 'li') {
    return element.children.isEmpty;
  }
  
  // Element within list item
  final parent = element.parent;
  if (parent == null) return false;
  
  final siblings = parent.children;
  final index = siblings.indexOf(element);
  if (index == siblings.length - 1) {
    return true;
  }
  
  final nextElement = siblings[index + 1];
  return nextElement.localName == 'item' || nextElement.localName == 'li';
}

/// Convert a DOM Element to an XmlElement.
XmlElement domToXml(dom.Element elem) {
  final xml = XmlElement(XmlName(elem.localName ?? 'div'));
  
  // Copy attributes
  for (final entry in elem.attributes.entries) {
    xml.setAttribute(entry.key.toString(), entry.value);
  }
  
  // Process children
  for (final node in elem.nodes) {
    if (node is dom.Element) {
      xml.children.add(domToXml(node));
    } else if (node is dom.Text) {
      if (node.text.isNotEmpty) {
        xml.children.add(XmlText(node.text));
      }
    }
  }
  
  return xml;
}

/// Convert an XmlElement to a DOM Element.
dom.Element xmlToDom(XmlElement elem) {
  final dom_ = dom.Element.tag(elem.name.local);
  
  // Copy attributes
  for (final attr in elem.attributes) {
    dom_.attributes[attr.name.local] = attr.value;
  }
  
  // Process children
  for (final child in elem.children) {
    if (child is XmlElement) {
      dom_.nodes.add(xmlToDom(child));
    } else if (child is XmlText) {
      if (child.value.isNotEmpty) {
        dom_.nodes.add(dom.Text(child.value));
      }
    }
  }
  
  return dom_;
}