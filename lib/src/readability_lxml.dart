/// Minimalistic fork of readability-lxml code
///
/// This is a Dart port of a Python port of a Ruby port of arc90's readability project
///
/// http://lab.arc90.com/experiments/readability/
///
/// Given a html document, it pulls out the main body text and cleans it up.
///
/// License of forked code: Apache-2.0.
library;

import 'dart:math';

import 'package:html/dom.dart' as dom;

import 'utils.dart';

/// Dot space pattern
final _dotSpace = RegExp(r'\.( |$)');

/// Div score elements
const Set<String> _divScores = {'div', 'article'};

/// Block score elements
const Set<String> _blockScores = {'pre', 'td', 'blockquote'};

/// Bad element scores
const Set<String> _badElemScores = {'address', 'ol', 'ul', 'dl', 'dd', 'dt', 'li', 'form', 'aside'};

/// Structure scores
const Set<String> _structureScores = {'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'th', 'header', 'footer', 'nav'};

/// Text clean elements
const Set<String> _textCleanElems = {'p', 'img', 'li', 'a', 'embed', 'input'};

/// Regexes for readability
final Map<String, RegExp> _regexes = {
  'unlikelyCandidatesRe': RegExp(
    r'combx|comment|community|disqus|extra|foot|header|menu|remark|rss|shoutbox|sidebar|sponsor|ad-break|agegate|pagination|pager|popup|tweet|twitter',
    caseSensitive: false,
  ),
  'okMaybeItsACandidateRe': RegExp(r'and|article|body|column|main|shadow', caseSensitive: false),
  'positiveRe': RegExp(
    r'article|body|content|entry|hentry|main|page|pagination|post|text|blog|story',
    caseSensitive: false,
  ),
  'negativeRe': RegExp(
    r'button|combx|comment|com-|contact|figure|foot|footer|footnote|form|input|masthead|media|meta|outbrain|promo|related|scroll|shoutbox|sidebar|sponsor|shopping|tags|tool|widget',
    caseSensitive: false,
  ),
  'divToPElementsRe': RegExp(r'<(?:a|blockquote|dl|div|img|ol|p|pre|table|ul)', caseSensitive: false),
  'videoRe': RegExp(r'https?:\/\/(?:www\.)?(?:youtube|vimeo)\.com', caseSensitive: false),
};

/// Frame tags
const Set<String> _frameTags = {'body', 'html'};

/// List tags
const Set<String> _listTags = {'ol', 'ul'};

/// Return the length of the element with all its contents.
int textLength(dom.Element elem) {
  return trim(elem.text).length;
}

/// Defines a class to score candidate elements.
class Candidate {
  /// Score value
  double score;
  
  /// Element being scored
  final dom.Element elem;
  
  /// Create a new Candidate.
  Candidate(this.score, this.elem);
}

/// Class to build a document out of html for readability extraction.
class ReadabilityDocument {
  /// The HTML document
  dom.Element doc;
  
  /// Minimum text length
  final int minTextLength;
  
  /// Retry length threshold
  final int retryLength;
  
  /// Create a new Document.
  ReadabilityDocument(
    this.doc, {
    this.minTextLength = 25,
    this.retryLength = 250,
  });
  
  /// Extract the main content from the HTML.
  dom.Element? summary() {
    // Remove script and style elements
    for (final elem in doc.querySelectorAll('script, style').toList()) {
      elem.remove();
    }
    
    var ruthless = true;
    while (true) {
      if (ruthless) {
        _removeUnlikelyCandidates();
      }
      _transformMisusedDivsIntoParagraphs();
      final candidates = _scoreParagraphs();
      
      final bestCandidate = _selectBestCandidate(candidates);
      
      dom.Element article;
      if (bestCandidate != null) {
        article = _getArticle(candidates, bestCandidate);
      } else {
        if (ruthless) {
          ruthless = false;
          continue;
        }
        // Return raw html
        final body = doc.querySelector('body');
        article = body ?? doc;
      }
      
      final cleanedArticle = _sanitize(article, candidates);
      final articleLength = cleanedArticle?.text.length ?? 0;
      
      if (ruthless && articleLength < retryLength) {
        ruthless = false;
        continue;
      }
      
      return cleanedArticle;
    }
  }
  
  /// Get article from best candidate and siblings.
  dom.Element _getArticle(Map<dom.Element, Candidate> candidates, Candidate bestCandidate) {
    final siblingScoreThreshold = max(10.0, bestCandidate.score * 0.2);
    final output = dom.Element.tag('div');
    
    final parent = bestCandidate.elem.parent;
    final siblings = parent?.children ?? [bestCandidate.elem];
    
    for (final sibling in siblings) {
      var append = false;
      
      if (sibling == bestCandidate.elem ||
          (candidates.containsKey(sibling) && candidates[sibling]!.score >= siblingScoreThreshold)) {
        append = true;
      } else if (sibling.localName == 'p') {
        final linkDensity = _getLinkDensity(sibling);
        final nodeContent = sibling.text;
        final nodeLength = nodeContent.length;
        
        if ((nodeLength > 80 && linkDensity < 0.25) ||
            (nodeLength <= 80 && linkDensity == 0 && _dotSpace.hasMatch(nodeContent))) {
          append = true;
        }
      }
      
      if (append) {
        output.append(sibling.clone(true));
      }
    }
    
    return output;
  }
  
  /// Select the best candidate from scored elements.
  Candidate? _selectBestCandidate(Map<dom.Element, Candidate> candidates) {
    if (candidates.isEmpty) return null;
    
    final sortedCandidates = candidates.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    
    return sortedCandidates.first;
  }
  
  /// Calculate link density for an element.
  double _getLinkDensity(dom.Element elem) {
    final totalLength = textLength(elem);
    if (totalLength == 0) return 0;
    
    final linkLength = elem.querySelectorAll('a')
        .map((link) => textLength(link))
        .fold(0, (sum, len) => sum + len);
    
    return linkLength / totalLength;
  }
  
  /// Score paragraphs in the document.
  Map<dom.Element, Candidate> _scoreParagraphs() {
    final candidates = <dom.Element, Candidate>{};
    
    for (final elem in doc.querySelectorAll('p, pre, td')) {
      final parentNode = elem.parent;
      if (parentNode == null) continue;
      
      final grandParentNode = parentNode.parent;
      
      final elemText = trim(elem.text);
      final elemTextLen = elemText.length;
      
      // Discard too short paragraphs
      if (elemTextLen < minTextLength) continue;
      
      for (final node in [parentNode, grandParentNode]) {
        if (node != null && !candidates.containsKey(node)) {
          candidates[node] = _scoreNode(node);
        }
      }
      
      final score = 1 + elemText.split(',').length + min((elemTextLen / 100), 3);
      
      candidates[parentNode]!.score += score;
      if (grandParentNode != null && candidates.containsKey(grandParentNode)) {
        candidates[grandParentNode]!.score += score / 2;
      }
    }
    
    // Scale candidates by link density
    for (final entry in candidates.entries) {
      entry.value.score *= (1 - _getLinkDensity(entry.key));
    }
    
    return candidates;
  }
  
  /// Calculate class weight for an element.
  double _classWeight(dom.Element elem) {
    var weight = 0.0;
    
    for (final attribute in [elem.attributes['class'], elem.attributes['id']]) {
      if (attribute == null || attribute.isEmpty) continue;
      
      if (_regexes['negativeRe']!.hasMatch(attribute)) {
        weight -= 25;
      }
      if (_regexes['positiveRe']!.hasMatch(attribute)) {
        weight += 25;
      }
    }
    
    return weight;
  }
  
  /// Score a node.
  Candidate _scoreNode(dom.Element elem) {
    var score = _classWeight(elem);
    final name = (elem.localName ?? '').toLowerCase();
    
    if (_divScores.contains(name)) {
      score += 5;
    } else if (_blockScores.contains(name)) {
      score += 3;
    } else if (_badElemScores.contains(name)) {
      score -= 3;
    } else if (_structureScores.contains(name)) {
      score -= 5;
    }
    
    return Candidate(score, elem);
  }
  
  /// Remove unlikely candidates.
  void _removeUnlikelyCandidates() {
    for (final elem in doc.querySelectorAll('*').toList()) {
      final elemClass = elem.attributes['class'] ?? '';
      final elemId = elem.attributes['id'] ?? '';
      final attrs = '$elemClass $elemId'.trim();
      
      if (attrs.length < 2) continue;
      
      final tag = elem.localName ?? '';
      if (!_frameTags.contains(tag) &&
          _regexes['unlikelyCandidatesRe']!.hasMatch(attrs) &&
          !_regexes['okMaybeItsACandidateRe']!.hasMatch(attrs)) {
        elem.remove();
      }
    }
  }
  
  /// Transform misused divs into paragraphs.
  void _transformMisusedDivsIntoParagraphs() {
    for (final elem in doc.querySelectorAll('div').toList()) {
      final innerHTML = elem.children.map((c) => c.outerHtml).join();
      if (!_regexes['divToPElementsRe']!.hasMatch(innerHTML)) {
        // Convert div to p by replacing tag
        final p = dom.Element.tag('p');
        for (final node in elem.nodes.toList()) {
          p.append(node);
        }
        elem.replaceWith(p);
      }
    }
    
    for (final elem in doc.querySelectorAll('div')) {
      if (elem.nodes.isNotEmpty) {
        // Handle text before first child
        final firstTextNode = elem.nodes.whereType<dom.Text>().firstOrNull;
        if (firstTextNode != null && firstTextNode.text.trim().isNotEmpty) {
          final p = dom.Element.tag('p')..text = firstTextNode.text;
          firstTextNode.replaceWith(p);
        }
      }
      
      // Handle br elements
      for (final br in elem.querySelectorAll('br').toList()) {
        br.remove();
      }
    }
  }
  
  /// Sanitize the article element.
  dom.Element? _sanitize(dom.Element node, Map<dom.Element, Candidate> candidates) {
    // Remove headers with low score or high link density
    for (final header in node.querySelectorAll('h1, h2, h3, h4, h5, h6').toList()) {
      if (_classWeight(header) < 0 || _getLinkDensity(header) > 0.33) {
        header.remove();
      }
    }
    
    // Remove forms and textareas
    for (final elem in node.querySelectorAll('form, textarea').toList()) {
      elem.remove();
    }
    
    // Handle iframes
    for (final elem in node.querySelectorAll('iframe').toList()) {
      final src = elem.attributes['src'] ?? '';
      if (_regexes['videoRe']!.hasMatch(src)) {
        elem.text = 'VIDEO';
      } else {
        elem.remove();
      }
    }
    
    final allowed = <dom.Element>{};
    
    // Conditionally clean tables, lists, and divs
    for (final elem in node.querySelectorAll('table, ul, div, aside, header, footer, section').toList().reversed) {
      if (allowed.contains(elem)) continue;
      
      final weight = _classWeight(elem);
      final score = candidates[elem]?.score ?? 0;
      
      if (weight + score < 0) {
        elem.remove();
      } else if (elem.text.split(',').length < 10) {
        var toRemove = true;
        
        final counts = <String, int>{
          for (final kind in _textCleanElems)
            kind: elem.querySelectorAll(kind).length,
        };
        counts['li'] = (counts['li'] ?? 0) - 100;
        counts['input'] = (counts['input'] ?? 0) -
            elem.querySelectorAll('input[type="hidden"]').length;
        
        final contentLength = textLength(elem);
        final linkDensity = _getLinkDensity(elem);
        
        if ((counts['p'] ?? 0) > 0 && (counts['img'] ?? 0) > 1 + (counts['p']! * 1.3)) {
          // too many images
        } else if ((counts['li'] ?? 0) > (counts['p'] ?? 0) && !_listTags.contains(elem.localName)) {
          // more <li>s than <p>s
        } else if ((counts['input'] ?? 0) > ((counts['p'] ?? 0) / 3)) {
          // less than 3x <p>s than <input>s
        } else if (contentLength < minTextLength && (counts['img'] ?? 0) == 0) {
          // too short without images
        } else if (contentLength < minTextLength && (counts['img'] ?? 0) > 2) {
          // too short and too many images
        } else if (weight < 25 && linkDensity > 0.2) {
          // too many links for weight
        } else if (weight >= 25 && linkDensity > 0.5) {
          // too many links for weight
        } else if (((counts['embed'] ?? 0) == 1 && contentLength < 75) || (counts['embed'] ?? 0) > 1) {
          // embed issues
        } else if (contentLength == 0) {
          // no content
          
          // Check siblings
          final siblings = <int>[];
          var sibling = elem.nextElementSibling;
          while (sibling != null && siblings.length < 1) {
            final sibLen = textLength(sibling);
            if (sibLen > 0) siblings.add(sibLen);
            sibling = sibling.nextElementSibling;
          }
          
          if (siblings.isNotEmpty && siblings.reduce((a, b) => a + b) > 1000) {
            toRemove = false;
            for (final child in elem.querySelectorAll('table, ul, div, section')) {
              allowed.add(child);
            }
          }
        } else {
          toRemove = false;
        }
        
        if (toRemove) {
          elem.remove();
        }
      }
    }
    
    return node;
  }
}

/// Readability regex patterns
final Map<String, RegExp> _readabilityRegexps = {
  'unlikelyCandidates': RegExp(
    r'-ad-|ai2html|banner|breadcrumbs|combx|comment|community|cover-wrap|disqus|extra|footer|gdpr|header|legends|menu|related|remark|replies|rss|shoutbox|sidebar|skyscraper|social|sponsor|supplemental|ad-break|agegate|pagination|pager|popup|yom-remote',
    caseSensitive: false,
  ),
  'okMaybeItsACandidate': RegExp(r'and|article|body|column|content|main|shadow', caseSensitive: false),
};

/// Display none regex
final _displayNone = RegExp(r'display:\s*none', caseSensitive: false);

/// Check if a node is visible.
bool isNodeVisible(dom.Element node) {
  final style = node.attributes['style'] ?? '';
  if (_displayNone.hasMatch(style)) {
    return false;
  }
  if (node.attributes.containsKey('hidden')) {
    return false;
  }
  if (node.attributes['aria-hidden'] == 'true' &&
      !(node.attributes['class'] ?? '').contains('fallback-image')) {
    return false;
  }
  return true;
}

/// Decide whether or not the document is reader-able without parsing the whole thing.
bool isProbablyReaderable(
  dom.Element html, {
  int minContentLength = 140,
  int minScore = 20,
  bool Function(dom.Element)? visibilityChecker,
}) {
  final doc = html;
  visibilityChecker ??= isNodeVisible;
  
  final nodes = <dom.Element>{};
  nodes.addAll(doc.querySelectorAll('p, pre, article'));
  
  // Add parent divs of br elements
  for (final br in doc.querySelectorAll('div > br')) {
    final parent = br.parent;
    if (parent != null) {
      nodes.add(parent);
    }
  }
  
  var score = 0.0;
  for (final node in nodes) {
    if (!visibilityChecker(node)) continue;
    
    final classAndId = '${node.attributes['class'] ?? ''} ${node.attributes['id'] ?? ''}';
    if (_readabilityRegexps['unlikelyCandidates']!.hasMatch(classAndId) &&
        !_readabilityRegexps['okMaybeItsACandidate']!.hasMatch(classAndId)) {
      continue;
    }
    
    // Check if node is p within li
    if (node.parent?.localName == 'li' && node.localName == 'p') {
      continue;
    }
    
    final textContentLength = node.text.trim().length;
    if (textContentLength < minContentLength) continue;
    
    score += sqrt(textContentLength - minContentLength);
    if (score > minScore) {
      return true;
    }
  }
  
  return false;
}
