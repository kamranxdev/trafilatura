/// Baseline and basic extraction functions.
///
/// Provides fallback extraction methods for content extraction.
library;

import 'dart:convert';
import 'package:html/dom.dart' as dom;
import 'package:xml/xml.dart';

import 'utils.dart';
import 'xpaths.dart';

/// Remove a few section types from the document.
dom.Document basicCleaning(dom.Document tree) {
  // Remove aside, footer, script, style elements
  for (final elem in selectBasicCleanElements(tree.documentElement!).toList()) {
    elem.remove();
  }
  return tree;
}

/// Use baseline extraction function targeting text paragraphs and/or JSON metadata.
///
/// Returns a tuple of (body element, main text, text length).
(XmlElement, String, int) baseline(dynamic filecontent) {
  final tree = loadHtml(filecontent);
  final postbody = XmlElement(XmlName('body'));
  
  if (tree == null) {
    return (postbody, '', 0);
  }
  
  // Scrape from json text
  var tempText = '';
  for (final elem in tree.querySelectorAll('script[type="application/ld+json"]')) {
    final scriptText = elem.text;
    if (scriptText.contains('articleBody')) {
      try {
        final json = jsonDecode(scriptText);
        String? jsonBody;
        
        if (json is Map) {
          jsonBody = json['articleBody'] as String?;
        }
        
        if (jsonBody != null && jsonBody.isNotEmpty) {
          String text;
          if (jsonBody.contains('<p>')) {
            final parsed = loadHtml(jsonBody);
            text = parsed?.body?.text.trim() ?? '';
          } else {
            text = trim(jsonBody);
          }
          
          final p = XmlElement(XmlName('p'));
          p.innerText = text;
          postbody.children.add(p);
          tempText += tempText.isEmpty ? text : ' $text';
        }
      } catch (e) {
        // JSON decode error
      }
    }
  }
  
  if (tempText.length > 100) {
    return (postbody, tempText, tempText.length);
  }
  
  // Clean tree
  basicCleaning(tree);
  
  // Scrape from article tag
  tempText = '';
  for (final articleElem in tree.querySelectorAll('article')) {
    final text = trim(articleElem.text);
    if (text.length > 100) {
      final p = XmlElement(XmlName('p'));
      p.innerText = text;
      postbody.children.add(p);
      tempText += tempText.isEmpty ? text : ' $text';
    }
  }
  
  if (postbody.children.isNotEmpty) {
    return (postbody, tempText, tempText.length);
  }
  
  // Scrape from text paragraphs
  final results = <String>{};
  tempText = '';
  final newPostbody = XmlElement(XmlName('body'));
  
  for (final tagName in ['blockquote', 'code', 'p', 'pre', 'q', 'quote']) {
    for (final element in tree.querySelectorAll(tagName)) {
      final entry = trim(element.text);
      if (!results.contains(entry)) {
        final p = XmlElement(XmlName('p'));
        p.innerText = entry;
        newPostbody.children.add(p);
        tempText += tempText.isEmpty ? entry : ' $entry';
        results.add(entry);
      }
    }
  }
  
  if (tempText.length > 100) {
    return (newPostbody, tempText, tempText.length);
  }
  
  // Default strategy: clean the tree and take everything
  final finalPostbody = XmlElement(XmlName('body'));
  final bodyElem = tree.body;
  
  if (bodyElem != null) {
    final pElem = XmlElement(XmlName('p'));
    final textElems = <String>[];
    
    // Get all text content
    void extractText(dom.Node node) {
      if (node is dom.Text) {
        final trimmed = trim(node.text);
        if (trimmed.isNotEmpty) {
          textElems.add(trimmed);
        }
      } else if (node is dom.Element) {
        for (final child in node.nodes) {
          extractText(child);
        }
      }
    }
    
    extractText(bodyElem);
    pElem.innerText = textElems.join('\n');
    finalPostbody.children.add(pElem);
    
    return (finalPostbody, pElem.innerText, pElem.innerText.length);
  }
  
  // New fallback
  final text = html2txt(tree, clean: false);
  final p = XmlElement(XmlName('p'));
  p.innerText = text;
  finalPostbody.children.add(p);
  
  return (finalPostbody, text, text.length);
}

/// Run basic html2txt on a document.
///
/// [content] - HTML document as string or DOM element.
/// [clean] - Remove potentially undesirable elements.
///
/// Returns the extracted text in the form of a string or an empty string.
String html2txt(dynamic content, {bool clean = true}) {
  final tree = loadHtml(content);
  if (tree == null) {
    return '';
  }
  
  final body = tree.body;
  if (body == null) {
    return '';
  }
  
  if (clean) {
    // Apply basic cleaning
    for (final elem in selectBasicCleanElements(body).toList()) {
      elem.remove();
    }
  }
  
  // Get text content and normalize whitespace
  return body.text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).join(' ').trim();
}
