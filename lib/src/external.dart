/// Functions grounding on third-party software.
/// 
/// Provides fallback extraction algorithms similar to readability and justext.
library;

import 'package:html/dom.dart' as dom;
import 'package:xml/xml.dart';

import 'baseline.dart';
import 'htmlprocessing.dart';
import 'readability_lxml.dart';
import 'settings.dart';
import 'utils.dart';
import 'xml_utils.dart';
import 'xpaths.dart';

/// Stoplist cache for justext
Set<String>? _jtStoplist;

/// XPath for sanitized elements
const _sanitizedSelector = 'aside, audio, button, fieldset, figure, footer, '
    'iframe, input, label, link, nav, noindex, noscript, object, option, '
    'select, source, svg, time';

/// Try with the generic algorithm readability as safety net.
dom.Element tryReadability(dom.Element htmlinput) {
  try {
    final doc = ReadabilityDocument(htmlinput, minTextLength: 25, retryLength: 250);
    final summary = doc.summary();
    return summary ?? dom.Element.tag('div');
  } catch (e) {
    return dom.Element.tag('div');
  }
}

/// Decide whether to choose own or external extraction based on heuristics.
(XmlElement, String, int) compareExtraction(
  dom.Element tree,
  dom.Element backupTree,
  XmlElement body,
  String text,
  int lenText,
  Extractor options,
) {
  // Bypass for recall
  if (options.focus == 'recall' && lenText > options.minExtractedSize * 10) {
    return (body, text, lenText);
  }
  
  var useReadability = false;
  var jtResult = false;
  
  // Prior cleaning
  if (options.focus == 'precision') {
    backupTree = pruneUnwantedNodes(backupTree, selectOverallDiscardElements);
  }
  
  // Try with readability
  final temppostAlgo = tryReadability(backupTree);
  final algoText = trim(temppostAlgo.text);
  final lenAlgo = algoText.length;
  
  // Compare
  if (lenAlgo == 0 || lenAlgo == lenText) {
    useReadability = false;
  } else if (lenText == 0 && lenAlgo > 0) {
    useReadability = true;
  } else if (lenText > 2 * lenAlgo) {
    useReadability = false;
  } else if (lenAlgo > 2 * lenText && !algoText.startsWith('{')) {
    useReadability = true;
  } else if (body.findAllElements('p').isEmpty && lenAlgo > options.minExtractedSize * 2) {
    useReadability = true;
  } else if (body.findAllElements('table').length > body.findAllElements('p').length &&
      lenAlgo > options.minExtractedSize * 2) {
    useReadability = true;
  } else if (options.focus == 'recall' &&
      body.findAllElements('head').isEmpty &&
      temppostAlgo.querySelectorAll('h2, h3, h4').isNotEmpty &&
      lenAlgo > lenText) {
    useReadability = true;
  } else {
    useReadability = false;
  }
  
  // Apply decision
  if (useReadability) {
    body = _domToXml(temppostAlgo);
    text = algoText;
    lenText = lenAlgo;
  }
  
  // Override faulty extraction: try with justext
  final sanitizedElements = temppostAlgo.querySelectorAll(_sanitizedSelector);
  if (sanitizedElements.isNotEmpty || lenText < options.minExtractedSize) {
    final (body2, text2, lenText2) = justextRescue(tree, options);
    jtResult = text2.isNotEmpty;
    
    // Prevent too short documents from replacing the main text
    if (text2.isNotEmpty && !(lenText > 4 * lenText2)) {
      body = body2;
      text = text2;
      lenText = lenText2;
    }
  }
  
  // Post-processing: remove unwanted sections
  if (useReadability && !jtResult) {
    final (sanitizedBody, sanitizedText, sanitizedLen) = sanitizeTree(temppostAlgo, options);
    body = sanitizedBody;
    text = sanitizedText;
    lenText = sanitizedLen;
  }
  
  return (body, text, lenText);
}

/// Convert DOM element to XML element.
XmlElement _domToXml(dom.Element elem) {
  final xml = XmlElement(XmlName(elem.localName ?? 'div'));
  
  for (final entry in elem.attributes.entries) {
    xml.setAttribute(entry.key.toString(), entry.value);
  }
  
  // Process children
  for (final child in elem.children) {
    xml.children.add(_domToXml(child));
  }
  
  // Add text content
  final text = elem.nodes
      .whereType<dom.Text>()
      .map((t) => t.text)
      .join();
  if (text.isNotEmpty) {
    xml.children.insert(0, XmlText(text));
  }
  
  return xml;
}

/// Initialize justext stoplist.
Set<String> jtStoplistInit() {
  if (_jtStoplist == null) {
    _jtStoplist = <String>{};
    // Add common English stop words
    _jtStoplist!.addAll([
      'a', 'about', 'above', 'after', 'again', 'against', 'all', 'am', 'an',
      'and', 'any', 'are', "aren't", 'as', 'at', 'be', 'because', 'been',
      'before', 'being', 'below', 'between', 'both', 'but', 'by', "can't",
      'cannot', 'could', "couldn't", 'did', "didn't", 'do', 'does', "doesn't",
      'doing', "don't", 'down', 'during', 'each', 'few', 'for', 'from',
      'further', 'had', "hadn't", 'has', "hasn't", 'have', "haven't", 'having',
      'he', "he'd", "he'll", "he's", 'her', 'here', "here's", 'hers', 'herself',
      'him', 'himself', 'his', 'how', "how's", 'i', "i'd", "i'll", "i'm",
      "i've", 'if', 'in', 'into', 'is', "isn't", 'it', "it's", 'its', 'itself',
      "let's", 'me', 'more', 'most', "mustn't", 'my', 'myself', 'no', 'nor',
      'not', 'of', 'off', 'on', 'once', 'only', 'or', 'other', 'ought', 'our',
      'ours', 'ourselves', 'out', 'over', 'own', 'same', "shan't", 'she',
      "she'd", "she'll", "she's", 'should', "shouldn't", 'so', 'some', 'such',
      'than', 'that', "that's", 'the', 'their', 'theirs', 'them', 'themselves',
      'then', 'there', "there's", 'these', 'they', "they'd", "they'll",
      "they're", "they've", 'this', 'those', 'through', 'to', 'too', 'under',
      'until', 'up', 'very', 'was', "wasn't", 'we', "we'd", "we'll", "we're",
      "we've", 'were', "weren't", 'what', "what's", 'when', "when's", 'where',
      "where's", 'which', 'while', 'who', "who's", 'whom', 'why', "why's",
      'with', "won't", 'would', "wouldn't", 'you', "you'd", "you'll", "you're",
      "you've", 'your', 'yours', 'yourself', 'yourselves',
    ]);
  }
  return _jtStoplist!;
}

/// Simple paragraph classification based on justext algorithm.
List<_Paragraph> customJustext(dom.Element tree, Set<String> stoplist) {
  final paragraphs = <_Paragraph>[];
  
  // Extract paragraphs from tree
  for (final elem in tree.querySelectorAll('p, div, li, td, th')) {
    final text = trim(elem.text);
    if (text.isEmpty) continue;
    
    final words = text.split(RegExp(r'\s+'));
    final stopwordCount = words.where((w) => stoplist.contains(w.toLowerCase())).length;
    final linkDensity = _calculateLinkDensity(elem);
    
    // Classify paragraph
    final isBoilerplate = linkDensity > 0.4 ||
        (words.length < 10 && stopwordCount / words.length < 0.3) ||
        words.length < 3;
    
    paragraphs.add(_Paragraph(text: text, isBoilerplate: isBoilerplate));
  }
  
  return paragraphs;
}

/// Calculate link density for an element.
double _calculateLinkDensity(dom.Element elem) {
  final totalLength = elem.text.length;
  if (totalLength == 0) return 0;
  
  final linkLength = elem.querySelectorAll('a')
      .map((a) => a.text.length)
      .fold(0, (sum, len) => sum + len);
  
  return linkLength / totalLength;
}

/// Simple paragraph class for justext.
class _Paragraph {
  final String text;
  final bool isBoilerplate;
  
  _Paragraph({required this.text, required this.isBoilerplate});
}

/// Try with the generic algorithm justext as second safety net.
XmlElement tryJustext(dom.Element tree, String? url, String? targetLanguage) {
  final resultBody = XmlElement(XmlName('body'));
  
  // Get stoplist
  final justextStoplist = jtStoplistInit();
  
  // Extract
  try {
    final paragraphs = customJustext(tree, justextStoplist);
    
    for (final paragraph in paragraphs) {
      if (paragraph.isBoilerplate) continue;
      
      final elem = XmlElement(XmlName('p'));
      elem.innerText = paragraph.text;
      resultBody.children.add(elem);
    }
  } catch (e) {
    // Ignore errors
  }
  
  return resultBody;
}

/// Try to use justext algorithm as a second fallback.
(XmlElement, String, int) justextRescue(dom.Element tree, Extractor options) {
  // Additional cleaning - need a Document for basicCleaning
  // Create a temporary document
  final cleanTree = tree;
  
  // Proceed
  final temppostAlgo = tryJustext(cleanTree, options.url, options.lang);
  final tempText = trim(xmltotxt(temppostAlgo, includeFormatting: options.formatting) ?? '');
  
  return (temppostAlgo, tempText, tempText.length);
}

/// Convert and sanitize the output from the generic algorithm.
(XmlElement, String, int) sanitizeTree(dom.Element tree, Extractor options) {
  // 1. Clean
  var cleanedTree = treeCleaning(tree, options);
  
  // Remove links if not needed
  if (!options.links) {
    for (final a in cleanedTree.querySelectorAll('a').toList()) {
      _stripTag(a);
    }
  }
  
  // Strip spans
  for (final span in cleanedTree.querySelectorAll('span').toList()) {
    _stripTag(span);
  }
  
  // 2. Convert
  cleanedTree = convertTags(cleanedTree, options);
  
  // 3. Convert to XML
  final xml = _domToXml(cleanedTree);
  
  // Process table elements
  for (final elem in xml.descendants.whereType<XmlElement>()) {
    if (elem.name.local == 'tr') {
      final newElem = XmlElement(XmlName('row'));
      for (final child in elem.children.toList()) {
        newElem.children.add(child.copy());
      }
      final parent = elem.parent;
      if (parent != null) {
        final index = parent.children.indexOf(elem);
        parent.children[index] = newElem;
      }
    } else if (elem.name.local == 'td' || elem.name.local == 'th') {
      if (elem.name.local == 'th') {
        elem.setAttribute('role', 'head');
      }
      // Create new cell element
      final newElem = XmlElement(XmlName('cell'));
      for (final attr in elem.attributes) {
        newElem.setAttribute(attr.name.local, attr.value);
      }
      for (final child in elem.children.toList()) {
        newElem.children.add(child.copy());
      }
      final parent = elem.parent;
      if (parent != null) {
        final index = parent.children.indexOf(elem);
        parent.children[index] = newElem;
      }
    }
  }
  
  // 4. Return
  final text = trim(xmltotxt(xml, includeFormatting: options.formatting) ?? '');
  return (xml, text, text.length);
}

/// Strip a tag but keep its content.
void _stripTag(dom.Element elem) {
  final parent = elem.parent;
  if (parent == null) return;
  
  final index = parent.nodes.indexOf(elem);
  final children = elem.nodes.toList();
  
  for (var i = children.length - 1; i >= 0; i--) {
    parent.nodes.insert(index, children[i]);
  }
  
  elem.remove();
}
