/// Sitemap parsing and link extraction for Trafilatura.
///
/// This module handles sitemap discovery and parsing to extract links
/// for further crawling.
library;

import 'dart:async';

import 'deduplication.dart';
import 'downloads.dart';
import 'feeds.dart';
import 'settings.dart';

/// Pattern to match sitemap link elements.
final _linkRegex = RegExp(r'<loc>(?:<!\[CDATA\[)?(http.+?)(?:\]\]>)?</loc>');

/// Pattern to match xhtml:link elements.
final _xhtmlRegex = RegExp(r'<xhtml:link.+?>', dotAll: true);

/// Pattern to extract href from xhtml links.
final _hreflangRegex = RegExp(r'''href=["'](.+?)["']''');

/// Pattern for whitelisted blogging platforms.
final _whitelistedPlatforms = RegExp(
  r'(?:blogger|blogpost|ghost|hubspot|livejournal|medium|typepad|squarespace|tumblr|weebly|wix|wordpress)\.',
);

/// Pattern to detect sitemap format.
final _sitemapFormat = RegExp(r'^.{0,5}<\?xml|<sitemap|<urlset');

/// Pattern to detect sitemap links.
final _detectSitemapLink = RegExp(r'\.xml(\..{2,4})?$|\.xml[?#]');

/// Pattern to detect links in plain text.
final _detectLinks = RegExp(r'https?://[^\s<"]+');

/// Pattern to scrub query and fragments.
final _scrubRegex = RegExp(r'\?.*$|#.*$');

/// Pattern to detect potential sitemap.
final _potentialSitemap = RegExp(r'\.xml\b');

/// Default sitemap guesses.
const List<String> _guesses = [
  'sitemap.xml',
  'sitemap.xml.gz',
  'sitemap',
  'sitemap_index.xml',
  'sitemap_news.xml',
];

/// Store all necessary information on sitemap download and processing.
class SitemapObject {
  /// Base URL of the website.
  final String baseUrl;
  
  /// Domain name.
  final String domain;
  
  /// Whether to include external links.
  final bool external;
  
  /// Target language for filtering.
  final String? targetLang;
  
  /// Current sitemap content.
  String content = '';
  
  /// Currently processing URL.
  String currentUrl = '';
  
  /// Set of seen sitemap URLs.
  final Set<String> seen = {};
  
  /// List of sitemap URLs to process.
  List<String> sitemapUrls;
  
  /// List of extracted page URLs.
  final List<String> urls = [];
  
  SitemapObject({
    required this.baseUrl,
    required this.domain,
    required this.sitemapUrls,
    this.targetLang,
    this.external = false,
  });
  
  /// Fetch a sitemap over the network.
  Future<void> fetch() async {
    final downloaded = await fetchUrl(currentUrl);
    content = downloaded ?? '';
    seen.add(currentUrl);
  }
  
  /// Examine a link and determine if it's valid.
  void handleLink(String link) {
    if (link == currentUrl) return;
    
    // Fix, check, clean and normalize
    link = fixRelativeUrls(baseUrl, link);
    link = cleanUrl(link);
    
    if (link.isEmpty) return;
    
    // Language filter
    if (targetLang != null && !_langFilter(link, targetLang!)) {
      return;
    }
    
    final newDomain = _extractDomain(link);
    if (newDomain == null) return;
    
    // Domain check
    if (!external && 
        !_whitelistedPlatforms.hasMatch(newDomain) &&
        !isSimilarDomain(domain, newDomain)) {
      return;
    }
    
    if (_detectSitemapLink.hasMatch(link)) {
      sitemapUrls.add(link);
    } else {
      urls.add(link);
    }
  }
  
  /// Extract links from content using regex.
  void extractLinks(RegExp regex, int index, void Function(String) handler) {
    var count = 0;
    for (var match in regex.allMatches(content)) {
      if (count >= DefaultConfig.maxLinks) break;
      final value = match.group(index);
      if (value != null) {
        handler(value);
      }
      count++;
    }
  }
  
  /// Extract links corresponding to target language.
  void extractSitemapLanglinks() {
    if (!content.contains('hreflang=')) return;
    
    final langRegex = RegExp(
      '''hreflang=["'](${targetLang}.*?|x-default)["']''',
      dotAll: true,
    );
    
    void handleLangLink(String attrs) {
      if (langRegex.hasMatch(attrs)) {
        final langMatch = _hreflangRegex.firstMatch(attrs);
        if (langMatch != null) {
          handleLink(langMatch.group(1)!);
        }
      }
    }
    
    extractLinks(_xhtmlRegex, 0, handleLangLink);
  }
  
  /// Extract sitemap links and web page links.
  void extractSitemapLinks() {
    extractLinks(_linkRegex, 1, handleLink);
  }
  
  /// Download a sitemap and extract links.
  void process() {
    final plausible = isPlausibleSitemap(currentUrl, content);
    if (!plausible) return;
    
    // Try to extract links from TXT file
    if (!_sitemapFormat.hasMatch(content)) {
      extractLinks(_detectLinks, 0, handleLink);
      return;
    }
    
    // Process XML sitemap
    if (targetLang != null) {
      extractSitemapLanglinks();
      if (sitemapUrls.isNotEmpty || urls.isNotEmpty) {
        return;
      }
    }
    extractSitemapLinks();
  }
}

/// Simple language filter based on URL patterns.
bool _langFilter(String url, String targetLang) {
  // Accept all URLs that don't have explicit language markers
  final langPattern = RegExp(r'/[a-z]{2}(-[a-z]{2})?/|[?&]lang=([a-z]{2})', caseSensitive: false);
  final match = langPattern.firstMatch(url);
  
  if (match == null) return true;
  
  final matched = match.group(0)?.toLowerCase() ?? '';
  return matched.contains(targetLang.toLowerCase());
}

/// Extract domain from URL.
String? _extractDomain(String url) {
  final uri = Uri.tryParse(url);
  return uri?.host;
}

/// Look for sitemaps for the given URL and gather links.
///
/// Args:
///   url: Webpage or sitemap URL as string.
///        Triggers URL-based filter if the webpage isn't a homepage.
///   targetLang: Define a language to filter URLs based on heuristics
///               (two-letter string, ISO 639-1 format).
///   external: Similar hosts only or external URLs (defaults to false).
///   sleepTime: Wait between requests on the same website.
///   maxSitemaps: Maximum number of sitemaps to process.
///
/// Returns the extracted links as a list.
Future<List<String>> sitemapSearch(
  String url, {
  String? targetLang,
  bool external = false,
  Duration sleepTime = const Duration(seconds: 2),
  int? maxSitemaps,
}) async {
  maxSitemaps ??= DefaultConfig.maxSitemapsSeen;
  
  final (domainname, baseurl) = getHostInfo(url);
  if (domainname == null) {
    return [];
  }
  
  // Check if base URL is reachable
  if (!await isLivePage(baseurl)) {
    return [];
  }
  
  String? urlfilter;
  List<String> sitemapurls;
  
  if (url.endsWith('.gz') || url.endsWith('sitemap') || url.endsWith('.xml')) {
    sitemapurls = [url];
  } else {
    sitemapurls = [];
    // Set url filter to target subpages
    if (url.length > baseurl.length + 2) {
      urlfilter = url;
    }
  }
  
  final sitemap = SitemapObject(
    baseUrl: baseurl,
    domain: domainname,
    sitemapUrls: sitemapurls,
    targetLang: targetLang,
    external: external,
  );
  
  // Try sitemaps in robots.txt file
  if (sitemap.sitemapUrls.isEmpty) {
    sitemap.sitemapUrls = await findRobotsSitemaps(baseurl);
    if (sitemap.sitemapUrls.isEmpty) {
      sitemap.sitemapUrls = _guesses.map((g) => '$baseurl/$g').toList();
    }
  }
  
  // Iterate through nested sitemaps and results
  while (sitemap.sitemapUrls.isNotEmpty && sitemap.seen.length < maxSitemaps) {
    sitemap.currentUrl = sitemap.sitemapUrls.removeLast();
    await sitemap.fetch();
    sitemap.process();
    
    // Keep track of visited sitemaps and exclude them
    sitemap.sitemapUrls = sitemap.sitemapUrls
        .where((s) => !sitemap.seen.contains(s))
        .toList();
    
    if (sitemap.seen.length < maxSitemaps) {
      await Future.delayed(sleepTime);
    }
  }
  
  if (urlfilter != null) {
    return filterUrls(sitemap.urls, urlfilter);
  }
  
  return sitemap.urls;
}

/// Check if the sitemap corresponds to an expected format.
bool isPlausibleSitemap(String url, String? contents) {
  if (contents == null) return false;
  
  // Strip query and fragments
  url = _scrubRegex.firstMatch(url)?.group(0) ?? url;
  
  // Check content
  if (_potentialSitemap.hasMatch(url) &&
      !_sitemapFormat.hasMatch(contents)) {
    return false;
  }
  
  if (contents.length > 150 && 
      contents.substring(0, 150).toLowerCase().contains('<html')) {
    return false;
  }
  
  return true;
}

/// Check if a page is accessible.
Future<bool> isLivePage(String url) async {
  final response = await fetchUrl(url);
  return response != null;
}

/// Guess the location of robots.txt and extract sitemap URLs.
Future<List<String>> findRobotsSitemaps(String baseurl) async {
  final robotstxt = await fetchUrl('$baseurl/robots.txt');
  return extractRobotsSitemaps(robotstxt, baseurl);
}

/// Read a robots.txt file and find sitemap links.
List<String> extractRobotsSitemaps(String? robotstxt, String baseurl) {
  // Sanity check on length
  if (robotstxt == null || robotstxt.length > 10000) {
    return [];
  }
  
  final candidates = <String>[];
  
  for (var line in robotstxt.split('\n')) {
    // Remove optional comment
    final commentIndex = line.indexOf('#');
    if (commentIndex >= 0) {
      line = line.substring(0, commentIndex);
    }
    line = line.trim();
    
    if (line.isEmpty) continue;
    
    final parts = line.split(':');
    if (parts.length >= 2) {
      final key = parts[0].trim().toLowerCase();
      if (key == 'sitemap') {
        final value = parts.sublist(1).join(':').trim();
        if (value.isNotEmpty) {
          candidates.add(value);
        }
      }
    }
  }
  
  // Deduplicate and fix relative URLs
  final seen = <String>{};
  final sitemapurls = <String>[];
  
  for (var url in candidates) {
    if (!seen.contains(url)) {
      seen.add(url);
      sitemapurls.add(fixRelativeUrls(baseurl, url));
    }
  }
  
  return sitemapurls;
}

/// Synchronous version that returns empty list.
/// Users should prefer the async version.
List<String> sitemapSearchSync(
  String url, {
  String? targetLang,
  bool external = false,
}) {
  return [];
}
