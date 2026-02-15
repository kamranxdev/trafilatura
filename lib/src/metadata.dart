/// Module bundling all functions needed to scrape metadata from webpages.
library;

import 'dart:convert';

import 'package:html/dom.dart' as dom;

import 'htmlprocessing.dart';
import 'json_metadata.dart';
import 'settings.dart';
import 'utils.dart';
import 'xpaths.dart';

/// Meta URL regex
final _metaUrlRegex = RegExp(r'https?://(?:www\.|w[0-9]+\.)?([^/]+)');

/// JSON minifier regex
final _jsonMinifyRegex = RegExp(r'("(?:\\"|[^"])*")|\s');

/// HTML title regex
final _htmlTitleRegex = RegExp(r'^(.+)?\s+[–•·—|⁄*⋆~‹«<›»>:-]\s+(.+)$');

/// Clean meta tags regex
final _cleanMetaTagsRegex = RegExp(r'''["\']''');

/// License regex
final _licenseRegex = RegExp(
  r'/(by-nc-nd|by-nc-sa|by-nc|by-nd|by-sa|by|zero)/([1-9]\.[0-9])',
);

/// Text license regex
final _textLicenseRegex = RegExp(
  r'(cc|creative commons) (by-nc-nd|by-nc-sa|by-nc|by-nd|by-sa|by|zero) ?([1-9]\.[0-9])?',
  caseSensitive: false,
);

/// Meta name author attributes
const Set<String> _metanameAuthor = {
  'article:author',
  'atc-metaauthor',
  'author',
  'authors',
  'byl',
  'citation_author',
  'creator',
  'dc.creator',
  'dc.creator.aut',
  'dc:creator',
  'dcterms.creator',
  'dcterms.creator.aut',
  'dcsext.author',
  'parsely-author',
  'rbauthors',
  'sailthru.author',
  'shareaholic:article_author_name',
};

/// Meta name description attributes
const Set<String> _metanameDescription = {
  'dc.description',
  'dc:description',
  'dcterms.abstract',
  'dcterms.description',
  'description',
  'sailthru.description',
  'twitter:description',
};

/// Meta name publisher attributes
const Set<String> _metanamePublisher = {
  'article:publisher',
  'citation_journal_title',
  'copyright',
  'dc.publisher',
  'dc:publisher',
  'dcterms.publisher',
  'publisher',
  'sailthru.publisher',
  'rbpubname',
  'twitter:site',
};

/// Meta name tag attributes
const Set<String> _metanameTag = {
  'citation_keywords',
  'dcterms.subject',
  'keywords',
  'parsely-tags',
  'shareaholic:keywords',
  'tags',
};

/// Meta name title attributes
const Set<String> _metanameTitle = {
  'citation_title',
  'dc.title',
  'dcterms.title',
  'fb_title',
  'headline',
  'parsely-title',
  'sailthru.title',
  'shareaholic:title',
  'rbtitle',
  'title',
  'twitter:title',
};

/// Meta name URL attributes
const Set<String> _metanameUrl = {'rbmainurl', 'twitter:url'};

/// Meta name image attributes
const Set<String> _metanameImage = {
  'image',
  'og:image',
  'og:image:url',
  'og:image:secure_url',
  'twitter:image',
  'twitter:image:src',
};

/// Property author attributes
const Set<String> _propertyAuthor = {'author', 'article:author'};

/// Twitter attributes
const Set<String> _twitterAttrs = {'twitter:site', 'application-name'};

/// Extra meta attributes
const Set<String> _extraMeta = {'charset', 'http-equiv', 'property'};

/// OpenGraph properties mapping
const Map<String, String> _ogProperties = {
  'og:title': 'title',
  'og:description': 'description',
  'og:site_name': 'sitename',
  'og:image': 'image',
  'og:image:url': 'image',
  'og:image:secure_url': 'image',
  'og:type': 'pagetype',
};

/// OpenGraph author properties
const Set<String> _ogAuthor = {'og:author', 'og:article:author'};

/// URL selectors
const List<String> _urlSelectors = [
  'head link[rel="canonical"]',
  'head base',
  'head link[rel="alternate"][hreflang="x-default"]',
];

/// Remove special characters of tags.
String normalizeTags(String tags) {
  final trimmed = trim(_htmlUnescape(tags));
  if (trimmed.isEmpty) {
    return '';
  }
  final cleaned = _cleanMetaTagsRegex.hasMatch(trimmed)
      ? trimmed.replaceAll(_cleanMetaTagsRegex, '')
      : trimmed;
  return cleaned
      .split(', ')
      .where((s) => s.isNotEmpty)
      .join(', ');
}

/// Unescape HTML entities.
String _htmlUnescape(String text) {
  return text
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ');
}

/// Check if the authors string correspond to expected values.
String? checkAuthors(String authors, Set<String> authorBlacklist) {
  final blacklistLower = authorBlacklist.map((a) => a.toLowerCase()).toSet();
  final newAuthors = authors
      .split(';')
      .map((a) => a.trim())
      .where((a) => a.isNotEmpty && !blacklistLower.contains(a.toLowerCase()))
      .toList();
  
  if (newAuthors.isNotEmpty) {
    return newAuthors.join('; ').replaceAll(RegExp(r'^; |; $'), '');
  }
  return null;
}

/// Parse and extract metadata from JSON-LD data.
Document extractMetaJson(dom.Element tree, Document metadata) {
  final scripts = tree.querySelectorAll(
    'script[type="application/ld+json"], script[type="application/settings+json"]'
  );
  
  for (final elem in scripts) {
    final text = elem.text;
    if (text == null || text.isEmpty) continue;
    
    final elementText = normalizeJson(
      _jsonMinifyRegex.hasMatch(text)
          ? text.replaceAllMapped(_jsonMinifyRegex, (m) => m.group(1) ?? '')
          : text
    );
    
    try {
      final schema = jsonDecode(elementText);
      metadata = extractJson(schema, metadata);
    } catch (e) {
      metadata = extractJsonParseError(elementText, metadata);
    }
  }
  
  return metadata;
}

/// Search meta tags following the OpenGraph guidelines.
Map<String, String?> extractOpengraph(dom.Element tree) {
  final result = <String, String?>{
    'title': null,
    'author': null,
    'url': null,
    'description': null,
    'sitename': null,
    'image': null,
    'pagetype': null,
  };
  
  // Detect OpenGraph schema
  for (final elem in tree.querySelectorAll('head meta[property^="og:"]')) {
    final propertyName = elem.attributes['property'];
    final content = elem.attributes['content'];
    
    if (content != null && content.trim().isNotEmpty) {
      if (propertyName != null && _ogProperties.containsKey(propertyName)) {
        result[_ogProperties[propertyName]!] = content;
      } else if (propertyName == 'og:url' && isValidUrl(content)) {
        result['url'] = content;
      } else if (propertyName != null && _ogAuthor.contains(propertyName)) {
        result['author'] = normalizeAuthors(null, content);
      }
    }
  }
  
  return result;
}

/// Search meta tags for relevant information.
Document examineMeta(dom.Element tree) {
  // Bootstrap from potential OpenGraph tags
  final ogData = extractOpengraph(tree);
  var metadata = Document()
    ..title = ogData['title']
    ..author = ogData['author']
    ..url = ogData['url']
    ..description = ogData['description']
    ..sitename = ogData['sitename']
    ..image = ogData['image'];
  
  // Test if all values already assigned
  if (metadata.title != null &&
      metadata.author != null &&
      metadata.url != null &&
      metadata.description != null &&
      metadata.sitename != null &&
      metadata.image != null) {
    return metadata;
  }
  
  final tags = <String>[];
  String? backupSitename;
  
  // Iterate through meta tags
  for (final elem in tree.querySelectorAll('head meta[content]')) {
    final contentAttr = _stripHtmlTags(elem.attributes['content'] ?? '').trim();
    if (contentAttr.isEmpty) continue;
    
    // Property attribute
    if (elem.attributes.containsKey('property')) {
      final propertyAttr = (elem.attributes['property'] ?? '').toLowerCase();
      
      // Skip OpenGraph (already processed)
      if (propertyAttr.startsWith('og:')) continue;
      
      if (propertyAttr == 'article:tag') {
        tags.add(normalizeTags(contentAttr));
      } else if (_propertyAuthor.contains(propertyAttr)) {
        metadata.author = normalizeAuthors(metadata.author, contentAttr);
      } else if (propertyAttr == 'article:publisher') {
        metadata.sitename ??= contentAttr;
      } else if (_metanameImage.contains(propertyAttr)) {
        metadata.image ??= contentAttr;
      }
    }
    // Name attribute
    else if (elem.attributes.containsKey('name')) {
      final nameAttr = (elem.attributes['name'] ?? '').toLowerCase();
      
      if (_metanameAuthor.contains(nameAttr)) {
        metadata.author = normalizeAuthors(metadata.author, contentAttr);
      } else if (_metanameTitle.contains(nameAttr)) {
        metadata.title ??= contentAttr;
      } else if (_metanameDescription.contains(nameAttr)) {
        metadata.description ??= contentAttr;
      } else if (_metanamePublisher.contains(nameAttr)) {
        metadata.sitename ??= contentAttr;
      } else if (_metanameImage.contains(nameAttr)) {
        metadata.image ??= contentAttr;
      } else if (_twitterAttrs.contains(nameAttr) ||
          nameAttr.contains('twitter:app:name')) {
        backupSitename = contentAttr;
      } else if (nameAttr == 'twitter:url' &&
          metadata.url == null &&
          isValidUrl(contentAttr)) {
        metadata.url = contentAttr;
      } else if (_metanameTag.contains(nameAttr)) {
        tags.add(normalizeTags(contentAttr));
      }
    }
    // Itemprop attribute
    else if (elem.attributes.containsKey('itemprop')) {
      final itempropAttr = (elem.attributes['itemprop'] ?? '').toLowerCase();
      
      if (itempropAttr == 'author') {
        metadata.author = normalizeAuthors(metadata.author, contentAttr);
      } else if (itempropAttr == 'description') {
        metadata.description ??= contentAttr;
      } else if (itempropAttr == 'headline') {
        metadata.title ??= contentAttr;
      }
    }
  }
  
  // Backups
  metadata.sitename ??= backupSitename;
  metadata.tags = tags;
  
  return metadata;
}

/// Strip HTML tags from text.
final _htmlStripTagsRegex = RegExp(r'<[^>]+>');
String _stripHtmlTags(String text) {
  return text.replaceAll(_htmlStripTagsRegex, '');
}

/// Extract meta information using selectors.
String? extractMetainfo(
  dom.Element tree,
  List<List<dom.Element> Function(dom.Element)> expressions, {
  int lenLimit = 200,
}) {
  for (final expression in expressions) {
    final results = expression(tree);
    for (final elem in results) {
      final content = trim(elem.text);
      if (content.isNotEmpty && content.length > 2 && content.length < lenLimit) {
        return content;
      }
    }
  }
  return null;
}

/// Extract text segments out of main <title> element.
(String, String?, String?) examineTitleElement(dom.Element tree) {
  var title = '';
  final titleElement = tree.querySelector('head title');
  
  if (titleElement != null) {
    title = trim(titleElement.text);
    final match = _htmlTitleRegex.firstMatch(title);
    if (match != null) {
      return (title, match.group(1), match.group(2));
    }
  }
  
  return (title, null, null);
}

/// Extract the document title.
String? extractTitle(dom.Element tree) {
  // Only one h1-element: take it
  final h1Results = tree.querySelectorAll('h1');
  if (h1Results.length == 1) {
    final title = trim(h1Results.first.text);
    if (title.isNotEmpty) {
      return title;
    }
  }
  
  // Extract using selectors
  final titleSelectors = selectTitleElements;
  String? title = extractMetainfo(tree, [titleSelectors]);
  if (title != null && title.isNotEmpty) {
    return title;
  }
  
  // Extract using title tag
  final (titleText, first, second) = examineTitleElement(tree);
  for (final t in [first, second]) {
    if (t != null && !t.contains('.')) {
      return t;
    }
  }
  
  // Take first h1-title
  if (h1Results.isNotEmpty) {
    return h1Results.first.text;
  }
  
  // Take first h2-title
  final h2Results = tree.querySelectorAll('h2');
  if (h2Results.isNotEmpty) {
    return h2Results.first.text;
  }
  
  return titleText.isNotEmpty ? titleText : null;
}

/// Extract the document author(s).
String? extractAuthor(dom.Element tree) {
  // Clone and prune unwanted nodes
  final subtree = tree.clone(true);
  pruneUnwantedNodes(subtree, selectAuthorDiscardElements);
  
  final authorSelectors = selectAuthorElements;
  var author = extractMetainfo(subtree, [authorSelectors], lenLimit: 120);
  
  if (author != null) {
    author = normalizeAuthors(null, author);
  }
  
  return author;
}

/// Extract the URL from the canonical link.
String? extractUrl(dom.Element tree, [String? defaultUrl]) {
  String? url;
  
  for (final selector in _urlSelectors) {
    final element = tree.querySelector(selector);
    url = element?.attributes['href'];
    if (url != null && url.isNotEmpty) break;
  }
  
  // Fix relative URLs
  if (url != null && url.startsWith('/')) {
    for (final element in tree.querySelectorAll('head meta[content]')) {
      final attrType = element.attributes['name'] ??
          element.attributes['property'] ??
          '';
      if (attrType.startsWith('og:') || attrType.startsWith('twitter:')) {
        final baseUrl = getBaseUrl(element.attributes['content'] ?? '');
        if (baseUrl != null) {
          url = baseUrl + url!;
          break;
        }
      }
    }
  }
  
  // Validate URL
  if (url != null) {
    if (isValidUrl(url)) {
      url = normalizeUrl(url);
    } else {
      url = null;
    }
  }
  
  return url ?? defaultUrl;
}

/// Extract the name of a site from the main title.
String? extractSitename(dom.Element tree) {
  final (_, first, second) = examineTitleElement(tree);
  for (final part in [first, second]) {
    if (part != null && part.contains('.')) {
      return part;
    }
  }
  return null;
}

/// Find category and tag information.
List<String> extractCatstags(String metatype, dom.Element tree) {
  final results = <String>[];
  final regexpr = RegExp('/$metatype[s|ies]?/');
  
  final xpathExpression = metatype == 'category'
      ? selectCategoryElements
      : selectTagElements;
  
  // Search using custom expressions
  for (final elem in xpathExpression(tree)) {
    final href = elem.attributes['href'] ?? '';
    if (regexpr.hasMatch(href)) {
      results.add(elem.text);
    }
  }
  
  if (results.isNotEmpty) {
    return results
        .map((x) => lineProcessing(x))
        .where((x) => x != null && x.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
  }
  
  // Category fallback
  if (metatype == 'category' && results.isEmpty) {
    for (final element in tree.querySelectorAll(
      'head meta[property="article:section"][content], '
      'head meta[name*="subject"][content]'
    )) {
      final content = element.attributes['content'];
      if (content != null) {
        results.add(content);
      }
    }
  }
  
  return results
      .map((x) => lineProcessing(x))
      .where((x) => x != null && x.isNotEmpty)
      .cast<String>()
      .toSet()
      .toList();
}

/// Probe a link for identifiable free license cues.
String? parseLicenseElement(dom.Element element, {bool strict = false}) {
  // Look for Creative Commons elements
  final href = element.attributes['href'] ?? '';
  final match = _licenseRegex.firstMatch(href);
  if (match != null) {
    return 'CC ${match.group(1)!.toUpperCase()} ${match.group(2)}';
  }
  
  final text = element.text;
  if (text != null && text.isNotEmpty) {
    if (strict) {
      final textMatch = _textLicenseRegex.firstMatch(text);
      return textMatch?.group(0);
    }
    return trim(text);
  }
  
  return null;
}

/// Search the HTML code for license information and parse it.
String? extractLicense(dom.Element tree) {
  // Look for links labeled as license
  for (final element in tree.querySelectorAll('a[rel="license"][href]')) {
    final result = parseLicenseElement(element, strict: false);
    if (result != null) {
      return result;
    }
  }
  
  // Probe footer elements for CC links
  for (final element in tree.querySelectorAll(
    'footer a[href], div[class*="footer"] a[href], div[id*="footer"] a[href]'
  )) {
    final result = parseLicenseElement(element, strict: true);
    if (result != null) {
      return result;
    }
  }
  
  return null;
}

/// Check if URL is valid.
bool isValidUrl(String url) {
  try {
    final uri = Uri.parse(url);
    return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
  } catch (e) {
    return false;
  }
}

/// Get base URL from a URL string.
String? getBaseUrl(String url) {
  try {
    final uri = Uri.parse(url);
    if (uri.hasScheme && uri.hasAuthority) {
      return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    }
  } catch (e) {
    // Ignore
  }
  return null;
}

/// Normalize URL.
String normalizeUrl(String url) {
  try {
    final uri = Uri.parse(url);
    // Remove trailing slash, normalize path
    var path = uri.path;
    if (path.endsWith('/') && path.length > 1) {
      path = path.substring(0, path.length - 1);
    }
    return uri.replace(path: path).toString();
  } catch (e) {
    return url;
  }
}

/// Extract domain from URL.
String? extractDomain(String url) {
  try {
    final uri = Uri.parse(url);
    return uri.host;
  } catch (e) {
    return null;
  }
}

/// Process a line of text.
String? lineProcessing(String? text) {
  if (text == null) return null;
  return trim(text);
}

/// Main process for metadata extraction.
/// 
/// Args:
///   filecontent: HTML code as string or parsed tree.
///   defaultUrl: Previously known URL of the downloaded document.
///   dateConfig: Provide extraction parameters as Map.
///   extensive: Whether to use extensive date extraction.
///   authorBlacklist: Provide a blacklist of Author Names to filter out.
/// 
/// Returns:
///   A Document containing the extracted metadata information.
Document extractMetadata(
  dynamic filecontent, {
  String? defaultUrl,
  Map<String, dynamic>? dateConfig,
  bool extensive = true,
  Set<String>? authorBlacklist,
}) {
  authorBlacklist ??= {};
  dateConfig ??= setDateParams(extensive);
  
  // Load contents
  final tree = loadHtml(filecontent);
  if (tree == null || tree.documentElement == null) {
    return Document();
  }
  final root = tree.documentElement!;
  
  // Initialize and try to strip meta tags
  var metadata = examineMeta(root);
  
  // Check for single-word author
  if (metadata.author != null && !metadata.author!.contains(' ')) {
    metadata.author = null;
  }
  
  // Try JSON-LD metadata
  try {
    metadata = extractMetaJson(root, metadata);
  } catch (e) {
    // Ignore JSON metadata errors
  }
  
  // Title
  if (metadata.title == null) {
    metadata.title = extractTitle(root);
  }
  
  // Check author in blacklist
  if (metadata.author != null && authorBlacklist.isNotEmpty) {
    metadata.author = checkAuthors(metadata.author!, authorBlacklist);
  }
  
  // Author
  if (metadata.author == null) {
    metadata.author = extractAuthor(root);
  }
  
  // Recheck author in blacklist
  if (metadata.author != null && authorBlacklist.isNotEmpty) {
    metadata.author = checkAuthors(metadata.author!, authorBlacklist);
  }
  
  // URL
  if (metadata.url == null) {
    metadata.url = extractUrl(root, defaultUrl);
  }
  
  // Hostname
  if (metadata.url != null) {
    metadata.hostname = extractDomain(metadata.url!);
  }
  
  // Date extraction (simplified - htmldate functionality)
  dateConfig['url'] = metadata.url;
  metadata.date = findDate(root, dateConfig);
  
  // Sitename
  if (metadata.sitename == null) {
    metadata.sitename = extractSitename(root);
  }
  
  if (metadata.sitename != null) {
    // Scrap Twitter ID
    metadata.sitename = metadata.sitename!.replaceFirst(RegExp(r'^@'), '');
    // Capitalize
    if (metadata.sitename!.isNotEmpty &&
        !metadata.sitename!.contains('.') &&
        !metadata.sitename![0].toUpperCase().contains(metadata.sitename![0])) {
      metadata.sitename = _titleCase(metadata.sitename!);
    }
  } else if (metadata.url != null) {
    final mymatch = _metaUrlRegex.firstMatch(metadata.url!);
    if (mymatch != null) {
      metadata.sitename = mymatch.group(1);
    }
  }
  
  // Categories
  if (metadata.categories == null || metadata.categories!.isEmpty) {
    metadata.categories = extractCatstags('category', root);
  }
  
  // Tags
  if (metadata.tags == null || metadata.tags!.isEmpty) {
    metadata.tags = extractCatstags('tag', root);
  }
  
  // License
  metadata.license = extractLicense(root);
  
  // Safety checks
  metadata.filedate = dateConfig['max_date'] as String?;
  metadata.cleanAndTrim();
  
  return metadata;
}

/// Convert string to title case.
String _titleCase(String text) {
  return text
      .split(' ')
      .map((word) => word.isEmpty
          ? word
          : word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ');
}

/// Set date extraction parameters.
Map<String, dynamic> setDateParams(bool extensive) {
  return {
    'extensive_search': extensive,
    'max_date': DateTime.now().toIso8601String().substring(0, 10),
  };
}

/// Find date in the HTML tree.
/// This is a simplified version - the full functionality requires htmldate.
String? findDate(dom.Element tree, Map<String, dynamic> config) {
  // Look for common date meta tags
  final dateSelectors = [
    'meta[property="article:published_time"]',
    'meta[name="date"]',
    'meta[name="DC.date"]',
    'meta[name="dcterms.date"]',
    'meta[property="og:updated_time"]',
    'time[datetime]',
    'time[pubdate]',
  ];
  
  for (final selector in dateSelectors) {
    final element = tree.querySelector(selector);
    if (element != null) {
      final dateStr = element.attributes['content'] ??
          element.attributes['datetime'] ??
          element.text;
      if (dateStr != null && dateStr.isNotEmpty) {
        final parsed = _parseDate(dateStr);
        if (parsed != null) {
          return parsed;
        }
      }
    }
  }
  
  // Look in the text for date patterns
  final datePatterns = [
    RegExp(r'(\d{4}-\d{2}-\d{2})'),
    RegExp(r'(\d{2}/\d{2}/\d{4})'),
    RegExp(r'(\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{4})', caseSensitive: false),
  ];
  
  final text = tree.text;
  for (final pattern in datePatterns) {
    final match = pattern.firstMatch(text);
    if (match != null) {
      final parsed = _parseDate(match.group(1)!);
      if (parsed != null) {
        return parsed;
      }
    }
  }
  
  return null;
}

/// Parse a date string and return ISO format.
String? _parseDate(String dateStr) {
  // Try ISO format
  final isoMatch = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(dateStr);
  if (isoMatch != null) {
    return '${isoMatch.group(1)}-${isoMatch.group(2)}-${isoMatch.group(3)}';
  }
  
  // Try US format
  final usMatch = RegExp(r'(\d{2})/(\d{2})/(\d{4})').firstMatch(dateStr);
  if (usMatch != null) {
    return '${usMatch.group(3)}-${usMatch.group(1)}-${usMatch.group(2)}';
  }
  
  // Try text format
  final months = {
    'jan': '01', 'feb': '02', 'mar': '03', 'apr': '04',
    'may': '05', 'jun': '06', 'jul': '07', 'aug': '08',
    'sep': '09', 'oct': '10', 'nov': '11', 'dec': '12',
  };
  
  final textMatch = RegExp(
    r'(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+(\d{4})',
    caseSensitive: false,
  ).firstMatch(dateStr);
  
  if (textMatch != null) {
    final day = textMatch.group(1)!.padLeft(2, '0');
    final month = months[textMatch.group(2)!.toLowerCase().substring(0, 3)]!;
    final year = textMatch.group(3)!;
    return '$year-$month-$day';
  }
  
  return null;
}
