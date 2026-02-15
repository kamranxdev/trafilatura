/// Web crawling and spidering functions for Trafilatura.
///
/// This module provides functionality for website navigation and
/// focused crawling.
library;

import 'dart:async';
import 'dart:collection';

import 'downloads.dart';
import 'feeds.dart';
import 'utils.dart';

/// Robots.txt URL suffix.
const String _robotsTxtUrl = '/robots.txt';

/// Maximum number of URLs to visit by default.
const int maxSeenUrls = 10;

/// Maximum number of known URLs to track.
const int maxKnownUrls = 100000;

/// Global URL store for crawling.
final UrlStore urlStore = UrlStore();

/// Store for visited and unvisited URLs.
class UrlStore {
  /// Known URLs.
  final Set<String> _known = {};
  
  /// Visited URLs.
  final Set<String> _visited = {};
  
  /// URLs to visit (queue).
  final Queue<String> _todo = Queue();
  
  /// Robots.txt rules per domain.
  final Map<String, RobotRules?> _rules = {};
  
  /// Add URLs to the store.
  void addUrls(List<String> urls, {bool visited = false, List<String>? appendleft}) {
    for (var url in urls) {
      _known.add(url);
      if (visited) {
        _visited.add(url);
      } else if (!_visited.contains(url)) {
        _todo.addLast(url);
      }
    }
    
    // Add priority URLs to front
    if (appendleft != null) {
      for (var url in appendleft.reversed) {
        _known.add(url);
        if (!_visited.contains(url)) {
          _todo.addFirst(url);
        }
      }
    }
  }
  
  /// Get next URL to visit.
  String? getUrl(String baseUrl) {
    while (_todo.isNotEmpty) {
      final url = _todo.removeFirst();
      if (!_visited.contains(url) && url.contains(baseUrl)) {
        return url;
      }
    }
    return null;
  }
  
  /// Find unvisited URLs for a domain.
  List<String> findUnvisitedUrls(String baseUrl) {
    return _known
        .where((url) => !_visited.contains(url) && url.contains(baseUrl))
        .toList();
  }
  
  /// Find known URLs for a domain.
  List<String> findKnownUrls(String baseUrl) {
    return _known.where((url) => url.contains(baseUrl)).toList();
  }
  
  /// Store robots.txt rules for a domain.
  void storeRules(String baseUrl, RobotRules? rules) {
    _rules[baseUrl] = rules;
  }
  
  /// Get crawl delay for a domain.
  double getCrawlDelay(String baseUrl, {double defaultDelay = 2.0}) {
    final rules = _rules[baseUrl];
    return rules?.crawlDelay ?? defaultDelay;
  }
  
  /// Clear all stored data.
  void clear() {
    _known.clear();
    _visited.clear();
    _todo.clear();
    _rules.clear();
  }
}

/// Simple robots.txt rules parser.
class RobotRules {
  /// Disallowed paths.
  final Set<String> disallowedPaths = {};
  
  /// Allowed paths.
  final Set<String> allowedPaths = {};
  
  /// Crawl delay in seconds.
  double? crawlDelay;
  
  /// Parse robots.txt content.
  static RobotRules? parse(String content) {
    final rules = RobotRules();
    var isRelevantBlock = false;
    
    for (var line in content.split('\n')) {
      // Remove comments
      final commentIndex = line.indexOf('#');
      if (commentIndex >= 0) {
        line = line.substring(0, commentIndex);
      }
      line = line.trim().toLowerCase();
      
      if (line.isEmpty) continue;
      
      final parts = line.split(':');
      if (parts.length < 2) continue;
      
      final key = parts[0].trim();
      final value = parts.sublist(1).join(':').trim();
      
      if (key == 'user-agent') {
        isRelevantBlock = value == '*' || value.contains('bot');
      } else if (isRelevantBlock) {
        if (key == 'disallow' && value.isNotEmpty) {
          rules.disallowedPaths.add(value);
        } else if (key == 'allow' && value.isNotEmpty) {
          rules.allowedPaths.add(value);
        } else if (key == 'crawl-delay') {
          rules.crawlDelay = double.tryParse(value);
        }
      }
    }
    
    return rules;
  }
  
  /// Check if a URL is allowed.
  bool canFetch(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    
    final path = uri.path;
    
    // Check explicitly allowed paths first
    for (var allowed in allowedPaths) {
      if (path.startsWith(allowed)) {
        return true;
      }
    }
    
    // Check disallowed paths
    for (var disallowed in disallowedPaths) {
      if (path.startsWith(disallowed)) {
        return false;
      }
    }
    
    return true;
  }
}

/// Store necessary information to manage a focused crawl.
class CrawlParameters {
  /// Starting URL.
  final String start;
  
  /// Base URL of the website.
  final String base;
  
  /// Reference URL for filtering.
  final String ref;
  
  /// Target language.
  final String? lang;
  
  /// Robots.txt rules.
  RobotRules? rules;
  
  /// XPath expression for pruning.
  final String? pruneXpath;
  
  /// Iteration counter.
  int i = 0;
  
  /// Number of known URLs.
  int knownNum = 0;
  
  /// Whether crawl is still active.
  bool isOn = true;
  
  CrawlParameters({
    required this.start,
    this.lang,
    this.rules,
    this.pruneXpath,
  })  : base = _getBaseUrl(start),
        ref = _getReference(start);
  
  static String _getBaseUrl(String start) {
    final uri = Uri.tryParse(start);
    if (uri == null || uri.host.isEmpty) {
      throw ArgumentError('Cannot start crawl: $start');
    }
    return '${uri.scheme}://${uri.host}';
  }
  
  static String _getReference(String start) {
    if (start.split('/').length >= 4) {
      return start.substring(0, start.lastIndexOf('/'));
    }
    return start;
  }
  
  /// Update metadata based on URL store info.
  void updateMetadata(UrlStore store) {
    isOn = store.findUnvisitedUrls(base).isNotEmpty;
    knownNum = store.findKnownUrls(base).length;
  }
  
  /// Prepare the todo list, excluding invalid URLs.
  List<String> filterList(List<String>? todo) {
    if (todo == null) return [];
    return todo.where((u) => u != start && u.contains(ref)).toList();
  }
  
  /// Check if a link is valid for crawling.
  bool isValidLink(String link) {
    if (rules != null && !rules!.canFetch(link)) {
      return false;
    }
    if (!link.contains(ref)) {
      return false;
    }
    if (_isNotCrawlable(link)) {
      return false;
    }
    return true;
  }
}

/// Check if URL should not be crawled.
bool _isNotCrawlable(String url) {
  final lower = url.toLowerCase();
  // Skip common non-content URLs
  return lower.contains('/login') ||
         lower.contains('/logout') ||
         lower.contains('/register') ||
         lower.contains('/signup') ||
         lower.contains('/signin') ||
         lower.contains('/cart') ||
         lower.contains('/checkout') ||
         lower.contains('/search?') ||
         lower.endsWith('.pdf') ||
         lower.endsWith('.zip') ||
         lower.endsWith('.exe') ||
         lower.endsWith('.dmg');
}

/// Check if URL is a navigation page.
bool _isNavigationPage(String url) {
  final lower = url.toLowerCase();
  return lower.contains('/page/') ||
         lower.contains('/category/') ||
         lower.contains('/tag/') ||
         lower.contains('/author/') ||
         lower.contains('/archive') ||
         RegExp(r'/\d{4}/\d{2}/?$').hasMatch(url);
}

/// Check for meta-refresh redirection.
Future<(String?, String?)> refreshDetection(String htmlstring, String homepage) async {
  if (!htmlstring.contains('"refresh"') && !htmlstring.contains('"REFRESH"')) {
    return (htmlstring, homepage);
  }
  
  final tree = loadHtml(htmlstring);
  if (tree == null) {
    return (htmlstring, homepage);
  }
  
  // Test meta-refresh redirection
  String? content;
  for (var meta in tree.querySelectorAll('meta[http-equiv]')) {
    final httpEquiv = meta.attributes['http-equiv']?.toLowerCase();
    if (httpEquiv == 'refresh') {
      content = meta.attributes['content'];
      break;
    }
  }
  
  if (content == null || !content.contains(';')) {
    return (htmlstring, homepage);
  }
  
  var url2 = content.split(';')[1].trim().toLowerCase().replaceFirst('url=', '');
  if (!url2.startsWith('http')) {
    // Relative URL, adapt
    final uri = Uri.tryParse(homepage);
    if (uri != null) {
      url2 = fixRelativeUrls('${uri.scheme}://${uri.host}', url2);
    }
  }
  
  // Second fetch
  final newhtmlstring = await fetchUrl(url2);
  if (newhtmlstring == null) {
    return (null, null);
  }
  
  return (newhtmlstring, url2);
}

/// Check if homepage is redirected and return appropriate values.
Future<(String?, String?, String?)> probeAlternativeHomepage(String homepage) async {
  final response = await fetchResponse(homepage, decode: false);
  if (response == null || response.data == null) {
    return (null, null, null);
  }
  
  // Get redirected URL
  if (response.url != homepage && response.url != '/') {
    homepage = response.url;
  }
  
  // Decode response
  final htmlstring = decodeResponse(response.data!);
  
  // Check for meta-refresh
  final (newHtmlstring, newHomepage) = await refreshDetection(htmlstring, homepage);
  if (newHomepage == null) {
    return (null, null, null);
  }
  
  final uri = Uri.tryParse(newHomepage);
  final baseUrl = uri != null ? '${uri.scheme}://${uri.host}' : null;
  
  return (newHtmlstring, newHomepage, baseUrl);
}

/// Attempt to fetch and parse robots.txt file.
Future<RobotRules?> getRules(String baseUrl) async {
  final robotsUrl = '$baseUrl$_robotsTxtUrl';
  final data = await fetchUrl(robotsUrl);
  return data != null ? RobotRules.parse(data) : null;
}

/// Check if content matches target language.
bool isTargetLanguage(String htmlstring, String? language) {
  // Simple implementation - would need language detection library
  // For now, accept all
  return true;
}

/// Check if there are still navigation URLs in the queue.
bool isStillNavigation(List<String> todo) {
  return todo.any(_isNavigationPage);
}

/// Extract links from HTML content.
List<String> extractLinks(String htmlstring, String baseUrl, {String? language}) {
  final tree = loadHtml(htmlstring);
  if (tree == null) return [];
  
  final links = <String>[];
  
  for (var anchor in tree.querySelectorAll('a[href]')) {
    var href = anchor.attributes['href'];
    if (href == null || href.isEmpty) continue;
    
    // Skip javascript and mailto links
    if (href.startsWith('javascript:') || href.startsWith('mailto:')) continue;
    
    // Fix relative URLs
    href = fixRelativeUrls(baseUrl, href);
    
    // Basic validation
    final uri = Uri.tryParse(href);
    if (uri == null || !uri.hasScheme) continue;
    
    links.add(href);
  }
  
  return links;
}

/// Process links from HTML content.
void processLinks(
  String htmlstring,
  CrawlParameters params, {
  String? url,
}) {
  if (!isTargetLanguage(htmlstring, params.lang)) {
    return;
  }
  
  final links = <String>[];
  final linksPriority = <String>[];
  
  for (var link in extractLinks(htmlstring, url ?? params.base, language: params.lang)) {
    if (!params.isValidLink(link)) continue;
    
    if (_isNavigationPage(link)) {
      linksPriority.add(link);
    } else {
      links.add(link);
    }
  }
  
  urlStore.addUrls(links, appendleft: linksPriority);
}

/// Convert response and extract links.
void processResponse(Response? response, CrawlParameters params) {
  if (response == null || response.data == null) return;
  
  // Add final document URL to known links
  urlStore.addUrls([response.url], visited: true);
  
  // Convert response to string and extract links
  final htmlstring = decodeResponse(response.data!);
  processLinks(htmlstring, params, url: params.base);
}

/// Decode response data to string.
String decodeResponse(dynamic data) {
  if (data is String) return data;
  if (data is List<int>) {
    return String.fromCharCodes(data);
  }
  return data.toString();
}

/// Initialize crawl with starting parameters.
Future<CrawlParameters> initCrawl(
  String start, {
  String? lang,
  RobotRules? rules,
  List<String>? todo,
  List<String>? known,
  String? pruneXpath,
}) async {
  final params = CrawlParameters(
    start: start,
    lang: lang,
    rules: rules,
    pruneXpath: pruneXpath,
  );
  
  // Add known URLs
  urlStore.addUrls(known ?? [], visited: true);
  urlStore.addUrls(params.filterList(todo));
  
  // Get rules if not provided
  params.rules ??= await getRules(params.base);
  urlStore.storeRules(params.base, params.rules);
  
  // Visit start page if necessary
  if (todo == null || todo.isEmpty) {
    urlStore.addUrls([params.start], visited: false);
    return await crawlPage(params, initial: true);
  }
  
  params.updateMetadata(urlStore);
  return params;
}

/// Examine a webpage and extract links.
Future<CrawlParameters> crawlPage(
  CrawlParameters params, {
  bool initial = false,
}) async {
  final url = urlStore.getUrl(params.base);
  if (url == null) {
    params.isOn = false;
    params.knownNum = urlStore.findKnownUrls(params.base).length;
    return params;
  }
  
  params.i++;
  
  if (initial) {
    // Probe and process homepage
    final (htmlstring, homepage, newBaseUrl) = await probeAlternativeHomepage(url);
    if (htmlstring != null && homepage != null && newBaseUrl != null) {
      // Register potentially new homepage
      urlStore.addUrls([homepage]);
      // Extract links on homepage
      processLinks(htmlstring, params, url: url);
    }
  } else {
    final response = await fetchResponse(url, decode: false);
    processResponse(response, params);
  }
  
  params.updateMetadata(urlStore);
  return params;
}

/// Basic crawler targeting pages of interest within a website.
///
/// Args:
///   homepage: URL of the first page to fetch, preferably the homepage.
///   maxSeenUrls: Maximum number of pages to visit.
///   maxKnownUrls: Stop if total known pages exceeds this number.
///   todo: Previously generated list of pages to visit.
///   knownLinks: List of previously known pages.
///   lang: Target links according to language heuristics.
///   rules: Politeness rules from robots.txt.
///   pruneXpath: Remove unwanted elements using XPath.
///
/// Returns:
///   Tuple of (pages to visit, known links).
Future<(List<String>, List<String>)> focusedCrawler(
  String homepage, {
  int maxSeenUrls = maxSeenUrls,
  int maxKnownUrls = maxKnownUrls,
  List<String>? todo,
  List<String>? knownLinks,
  String? lang,
  RobotRules? rules,
  String? pruneXpath,
  double sleepTime = 2.0,
}) async {
  var params = await initCrawl(
    homepage,
    lang: lang,
    rules: rules,
    todo: todo,
    known: knownLinks,
    pruneXpath: pruneXpath,
  );
  
  // Get crawl delay
  final delay = Duration(
    milliseconds: (urlStore.getCrawlDelay(params.base, defaultDelay: sleepTime) * 1000).round()
  );
  
  // Visit pages until limit is reached
  while (params.isOn && params.i < maxSeenUrls && params.knownNum < maxKnownUrls) {
    params = await crawlPage(params);
    await Future.delayed(delay);
  }
  
  // Get final lists
  final resultTodo = urlStore.findUnvisitedUrls(params.base).toSet().toList();
  final resultKnown = urlStore.findKnownUrls(params.base).toSet().toList();
  
  return (resultTodo, resultKnown);
}

/// Synchronous placeholder for focused crawler.
/// Users should prefer the async version.
(List<String>, List<String>) focusedCrawlerSync(String homepage) {
  return ([], []);
}
