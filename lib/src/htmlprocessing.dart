/// Functions to process nodes in HTML code.
///
/// Provides functions for HTML tree cleaning, tag conversion,
/// link density analysis, and text node processing.
library;

import 'package:html/dom.dart' as dom;
import 'package:xml/xml.dart';

import 'settings.dart';
import 'utils.dart' hide textfilter, isImageElement;
import 'deduplication.dart';

/// Rend tag mapping for formatting
const Map<String, String> rendTagMapping = {
  'em': '#i',
  'i': '#i',
  'b': '#b',
  'strong': '#b',
  'u': '#u',
  'kbd': '#t',
  'samp': '#t',
  'tt': '#t',
  'var': '#t',
  'sub': '#sub',
  'sup': '#sup',
};

/// Reverse mapping for HTML conversion
final Map<String, String> htmlTagMapping = {
  for (final entry in rendTagMapping.entries) entry.value: entry.key,
};

/// Image-related elements to preserve during cleaning
const Set<String> preserveImgCleaning = {'figure', 'picture', 'source'};

/// Code indicators for detection
const List<String> codeIndicators = ['{', '("', "('", '\n    '];

/// Prune the tree by discarding unwanted elements.
dom.Element treeCleaning(dom.Element tree, Extractor options) {
  // Determine cleaning strategy
  var cleaningList = List<String>.from(manuallyCleaned);
  var strippingList = List<String>.from(manuallyStripped);
  
  if (!options.tables) {
    cleaningList.addAll(['table', 'td', 'th', 'tr']);
  } else {
    // Prevent issue with figure containing table
    for (final elem in tree.querySelectorAll('figure')) {
      if (elem.querySelector('table') != null) {
        // Replace figure with div
        final div = dom.Element.tag('div');
        for (final child in elem.children.toList()) {
          div.append(child);
        }
        elem.replaceWith(div);
      }
    }
  }
  
  if (options.images) {
    cleaningList = cleaningList.where((e) => !preserveImgCleaning.contains(e)).toList();
    strippingList.remove('img');
  }
  
  // Strip targeted elements (keep content, remove tags)
  for (final tagName in strippingList) {
    for (final elem in tree.querySelectorAll(tagName).toList()) {
      _stripTag(elem);
    }
  }
  
  // Delete targeted elements
  if (options.focus == 'recall' && tree.querySelector('p') != null) {
    final treeCopy = tree.clone(true);
    for (final tagName in cleaningList) {
      for (final elem in tree.querySelectorAll(tagName).toList()) {
        elem.remove();
      }
    }
    if (tree.querySelector('p') == null) {
      // Restore from copy
      tree.children.clear();
      for (final child in treeCopy.children) {
        tree.append(child);
      }
    }
  } else {
    for (final tagName in cleaningList) {
      for (final elem in tree.querySelectorAll(tagName).toList()) {
        elem.remove();
      }
    }
  }
  
  return pruneHtml(tree, options.focus);
}

/// Strip a tag but keep its content.
void _stripTag(dom.Element elem) {
  final parent = elem.parent;
  if (parent == null) return;
  
  final index = parent.nodes.indexOf(elem);
  final children = elem.nodes.toList();
  
  // Insert children at the element's position
  for (var i = children.length - 1; i >= 0; i--) {
    parent.nodes.insert(index, children[i]);
  }
  
  elem.remove();
}

/// Delete selected empty elements to save space and processing time.
dom.Element pruneHtml(dom.Element tree, String focus) {
  final keepTails = focus != 'precision';
  
  // Remove processing instructions and empty elements
  for (final elem in tree.querySelectorAll('*').toList()) {
    if (cutEmptyElems.contains(elem.localName) &&
        elem.children.isEmpty &&
        elem.text.trim().isEmpty) {
      if (keepTails) {
        // Preserve any trailing text
        final nextSibling = elem.nextElementSibling;
        if (elem.text.trim().isNotEmpty && nextSibling != null) {
          // Prepend text to next sibling
        }
      }
      elem.remove();
    }
  }
  
  return tree;
}

/// Prune the HTML tree by removing unwanted sections.
dom.Element pruneUnwantedNodes(
  dom.Element tree,
  List<dom.Element> Function(dom.Element) nodeSelector, {
  bool withBackup = false,
}) {
  int? oldLen;
  dom.Element? backup;
  
  if (withBackup) {
    oldLen = tree.text.length;
    backup = tree.clone(true);
  }
  
  for (final subtree in nodeSelector(tree).toList()) {
    subtree.remove();
  }
  
  if (withBackup && backup != null) {
    final newLen = tree.text.length;
    if (newLen <= oldLen! ~/ 7) {
      return backup;
    }
  }
  
  return tree;
}

/// Collect heuristics on link text.
(int, int, int, List<String>) collectLinkInfo(List<dom.Element> linksXpath) {
  final mylist = linksXpath
      .map((e) => trim(e.text))
      .where((e) => e.isNotEmpty)
      .toList();
  
  final lengths = mylist.map((s) => s.length).toList();
  final shortelems = lengths.where((l) => l < 10).length;
  
  return (
    lengths.fold(0, (sum, l) => sum + l),
    mylist.length,
    shortelems,
    mylist,
  );
}

/// Remove sections which are rich in links (probably boilerplate).
(bool, List<String>) linkDensityTest(
  dom.Element element,
  String text, [
  bool favorPrecision = false,
]) {
  final linksXpath = element.querySelectorAll('ref, a');
  
  if (linksXpath.isEmpty) {
    return (false, []);
  }
  
  List<String> mylist = [];
  
  // Shortcut for single link
  if (linksXpath.length == 1) {
    final lenThreshold = favorPrecision ? 10 : 100;
    final linkText = trim(linksXpath.first.text);
    if (linkText.length > lenThreshold && linkText.length > text.length * 0.9) {
      return (true, []);
    }
  }
  
  int limitlen;
  if (element.localName == 'p') {
    limitlen = element.nextElementSibling == null ? 60 : 30;
  } else {
    limitlen = element.nextElementSibling == null ? 300 : 100;
  }
  
  final elemlen = text.length;
  if (elemlen < limitlen) {
    final (linklen, elemnum, shortelems, list) = collectLinkInfo(linksXpath.toList());
    mylist = list;
    
    if (elemnum == 0) {
      return (true, mylist);
    }
    
    if (linklen > elemlen * 0.8 || (elemnum > 1 && shortelems / elemnum > 0.8)) {
      return (true, mylist);
    }
  }
  
  return (false, mylist);
}

/// Remove tables which are rich in links (probably boilerplate).
bool linkDensityTestTables(dom.Element element) {
  final linksXpath = element.querySelectorAll('ref, a');
  
  if (linksXpath.isEmpty) {
    return false;
  }
  
  final elemlen = trim(element.text).length;
  if (elemlen < 200) {
    return false;
  }
  
  final (linklen, elemnum, _, _) = collectLinkInfo(linksXpath.toList());
  
  if (elemnum == 0) {
    return true;
  }
  
  return elemlen < 1000 ? linklen > 0.8 * elemlen : linklen > 0.5 * elemlen;
}

/// Determine the link density of elements and remove boilerplate.
dom.Element deleteByLinkDensity(
  dom.Element subtree,
  String tagname, {
  bool backtracking = false,
  bool favorPrecision = false,
}) {
  final deletions = <dom.Element>[];
  final lenThreshold = favorPrecision ? 200 : 100;
  final depthThreshold = favorPrecision ? 1 : 3;
  
  for (final elem in subtree.querySelectorAll(tagname)) {
    final elemtext = trim(elem.text);
    final (result, templist) = linkDensityTest(elem, elemtext, favorPrecision);
    
    if (result ||
        (backtracking &&
            templist.isNotEmpty &&
            elemtext.isNotEmpty &&
            elemtext.length < lenThreshold &&
            elem.children.length >= depthThreshold)) {
      deletions.add(elem);
    }
  }
  
  for (final elem in deletions.toSet()) {
    elem.remove();
  }
  
  return subtree;
}

/// Convert, format, and probe potential text elements.
XmlElement? handleTextnode(
  dom.Element elem,
  Extractor options, {
  bool commentsFix = true,
  bool preserveSpaces = false,
}) {
  final tag = elem.localName ?? '';
  
  // Handle graphic/image elements
  if (tag == 'graphic' || tag == 'img') {
    if (isImageElement(elem)) {
      return _domToXml(elem);
    }
  }
  
  if (tag == 'done' || (elem.children.isEmpty && elem.text.trim().isEmpty)) {
    return null;
  }
  
  // lb bypass
  if (!commentsFix && tag == 'lb') {
    final result = XmlElement(XmlName('lb'));
    if (!preserveSpaces) {
      final trimmedText = trim(elem.text);
      if (trimmedText.isNotEmpty) {
        result.innerText = trimmedText;
      }
    }
    return result;
  }
  
  var text = elem.text.trim();
  
  // Try the tail (text after element)
  if (text.isEmpty && elem.children.isEmpty) {
    // In DOM, we handle this differently
  }
  
  // Trim
  if (!preserveSpaces) {
    text = trim(text);
  }
  
  // Filter content
  if (text.isEmpty && textfilter(elem)) {
    return null;
  }
  
  if (options.dedup && duplicateTest(elem, options)) {
    return null;
  }
  
  return _domToXml(elem);
}

/// Convert DOM element to XML element.
XmlElement _domToXml(dom.Element elem) {
  final xml = XmlElement(XmlName(elem.localName ?? 'span'));
  
  // Copy attributes
  for (final entry in elem.attributes.entries) {
    xml.setAttribute(entry.key.toString(), entry.value);
  }
  
  // Copy text content
  if (elem.text.isNotEmpty) {
    xml.innerText = elem.text;
  }
  
  return xml;
}

/// Convert, format, and probe potential text elements (light format).
XmlElement? processNode(dom.Element elem, Extractor options) {
  final tag = elem.localName ?? '';
  
  if (tag == 'done' || (elem.children.isEmpty && elem.text.trim().isEmpty)) {
    return null;
  }
  
  // Trim
  final text = trim(elem.text);
  
  // Content checks
  if (text.isNotEmpty || elem.text.isNotEmpty) {
    if (textfilter(elem)) {
      return null;
    }
    if (options.dedup && duplicateTest(elem, options)) {
      return null;
    }
  }
  
  return _domToXml(elem);
}

/// Convert <ul> and <ol> to <list> and underlying <li> elements to <item>.
void convertLists(dom.Element elem) {
  elem.attributes['rend'] = elem.localName ?? '';
  // We'll track this for XML conversion
  elem.attributes['_newtag'] = 'list';
  
  var i = 1;
  for (final subelem in elem.querySelectorAll('dd, dt, li')) {
    if (subelem.localName == 'dd' || subelem.localName == 'dt') {
      subelem.attributes['rend'] = '${subelem.localName}-$i';
      if (subelem.localName == 'dd') {
        i++;
      }
    }
    subelem.attributes['_newtag'] = 'item';
  }
}

/// Convert quoted elements while accounting for nested structures.
void convertQuotes(dom.Element elem) {
  var codeFlag = false;
  
  if (elem.localName == 'pre') {
    // Detect if there could be code inside
    if (elem.children.length == 1 && elem.children.first.localName == 'span') {
      codeFlag = true;
    }
    
    // Find hljs elements to detect if it's code
    final codeElems = elem.querySelectorAll('span[class^="hljs"]');
    if (codeElems.isNotEmpty) {
      codeFlag = true;
      for (final subelem in codeElems) {
        subelem.attributes.clear();
      }
    }
    
    if (_isCodeBlock(elem.text)) {
      codeFlag = true;
    }
  }
  
  elem.attributes['_newtag'] = codeFlag ? 'code' : 'quote';
}

/// Check if the element text is part of a code block.
bool _isCodeBlock(String? text) {
  if (text == null || text.isEmpty) {
    return false;
  }
  for (final indicator in codeIndicators) {
    if (text.contains(indicator)) {
      return true;
    }
  }
  return false;
}

/// Add head tags and delete attributes.
void convertHeadings(dom.Element elem) {
  elem.attributes.clear();
  elem.attributes['rend'] = elem.localName ?? '';
  elem.attributes['_newtag'] = 'head';
}

/// Convert <br> and <hr> to <lb>.
void convertLineBreaks(dom.Element elem) {
  elem.attributes['_newtag'] = 'lb';
}

/// Convert <del>, <s>, <strike> to <del rend="overstrike">.
void convertDeletions(dom.Element elem) {
  elem.attributes['_newtag'] = 'del';
  elem.attributes['rend'] = 'overstrike';
}

/// Handle details and summary.
void convertDetails(dom.Element elem) {
  elem.attributes['_newtag'] = 'div';
  for (final subelem in elem.querySelectorAll('summary')) {
    subelem.attributes['_newtag'] = 'head';
  }
}

/// Tag conversion map
final Map<String, void Function(dom.Element)> conversions = {
  'dl': convertLists,
  'ol': convertLists,
  'ul': convertLists,
  'h1': convertHeadings,
  'h2': convertHeadings,
  'h3': convertHeadings,
  'h4': convertHeadings,
  'h5': convertHeadings,
  'h6': convertHeadings,
  'br': convertLineBreaks,
  'hr': convertLineBreaks,
  'blockquote': convertQuotes,
  'pre': convertQuotes,
  'q': convertQuotes,
  'del': convertDeletions,
  's': convertDeletions,
  'strike': convertDeletions,
  'details': convertDetails,
};

/// Replace link tags and href attributes, delete the rest.
void convertLink(dom.Element elem, String? baseUrl) {
  elem.attributes['_newtag'] = 'ref';
  final target = elem.attributes['href'];
  elem.attributes.clear();
  
  if (target != null) {
    // Convert relative URLs
    String finalTarget = target;
    if (baseUrl != null && !target.startsWith('http')) {
      finalTarget = Uri.parse(baseUrl).resolve(target).toString();
    }
    elem.attributes['target'] = finalTarget;
  }
}

/// Simplify markup and convert relevant HTML tags to an XML standard.
dom.Element convertTags(dom.Element tree, Extractor options, {String? url}) {
  // Delete links for faster processing
  if (!options.links) {
    final xpath = 'div a, li a, p a${options.tables ? ', table a' : ''}';
    for (final elem in tree.querySelectorAll(xpath)) {
      elem.attributes['_newtag'] = 'ref';
    }
    // Strip the rest
    for (final elem in tree.querySelectorAll('a').toList()) {
      if (elem.attributes['_newtag'] != 'ref') {
        _stripTag(elem);
      }
    }
  } else {
    // Convert all links
    final baseUrl = url != null ? _getBaseUrl(url) : null;
    for (final elem in tree.querySelectorAll('a, ref')) {
      convertLink(elem, baseUrl);
    }
  }
  
  // Handle formatting
  if (options.formatting) {
    for (final tagName in rendTagMapping.keys) {
      for (final elem in tree.querySelectorAll(tagName)) {
        elem.attributes.clear();
        elem.attributes['rend'] = rendTagMapping[tagName]!;
        elem.attributes['_newtag'] = 'hi';
      }
    }
  } else {
    for (final tagName in rendTagMapping.keys) {
      for (final elem in tree.querySelectorAll(tagName).toList()) {
        _stripTag(elem);
      }
    }
  }
  
  // Iterate over all concerned elements
  for (final entry in conversions.entries) {
    for (final elem in tree.querySelectorAll(entry.key)) {
      entry.value(elem);
    }
  }
  
  // Handle images
  if (options.images) {
    for (final elem in tree.querySelectorAll('img')) {
      elem.attributes['_newtag'] = 'graphic';
    }
  }
  
  return tree;
}

/// Get base URL for converting relative URLs.
String? _getBaseUrl(String url) {
  try {
    final uri = Uri.parse(url);
    return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  } catch (e) {
    return null;
  }
}

/// HTML conversion map
final Map<String, dynamic> htmlConversions = {
  'list': 'ul',
  'item': 'li',
  'code': 'pre',
  'quote': 'blockquote',
  'head': (dom.Element elem) => 'h${int.tryParse(elem.attributes['rend']?.substring(1) ?? '3') ?? 3}',
  'lb': 'br',
  'img': 'graphic',
  'ref': 'a',
  'hi': (dom.Element elem) => htmlTagMapping[elem.attributes['rend'] ?? '#i'] ?? 'em',
};

/// Convert XML to simplified HTML.
XmlElement convertToHtml(XmlElement tree) {
  // Clone the tree for modification
  final html = XmlElement(XmlName('html'));
  final body = XmlElement(XmlName('body'));
  
  for (final child in tree.children.toList()) {
    body.children.add(child.copy());
  }
  
  html.children.add(body);
  return html;
}

/// Convert the document to HTML and return a string.
String buildHtmlOutput(Document document, {bool withMetadata = false}) {
  final htmlTree = convertToHtml(document.body);
  
  if (withMetadata) {
    final head = XmlElement(XmlName('head'));
    
    if (document.title != null) {
      final meta = XmlElement(XmlName('meta'));
      meta.setAttribute('name', 'title');
      meta.setAttribute('content', document.title!);
      head.children.add(meta);
    }
    if (document.author != null) {
      final meta = XmlElement(XmlName('meta'));
      meta.setAttribute('name', 'author');
      meta.setAttribute('content', document.author!);
      head.children.add(meta);
    }
    if (document.date != null) {
      final meta = XmlElement(XmlName('meta'));
      meta.setAttribute('name', 'date');
      meta.setAttribute('content', document.date!);
      head.children.add(meta);
    }
    if (document.url != null) {
      final meta = XmlElement(XmlName('meta'));
      meta.setAttribute('name', 'url');
      meta.setAttribute('content', document.url!);
      head.children.add(meta);
    }
    if (document.description != null) {
      final meta = XmlElement(XmlName('meta'));
      meta.setAttribute('name', 'description');
      meta.setAttribute('content', document.description!);
      head.children.add(meta);
    }
    
    htmlTree.children.insert(0, head);
  }
  
  return htmlTree.toXmlString(pretty: true).trim();
}
