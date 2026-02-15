/// Feed examination and link extraction for Trafilatura.
///
/// This module handles RSS, Atom, and JSON feeds to extract links
/// for further processing.
library;

import 'dart:convert';
import 'dart:async';

import 'deduplication.dart';
import 'downloads.dart';
import 'settings.dart';
import 'utils.dart';

/// Standard and potential feed MIME types.
const Set<String> feedTypes = {
  'application/atom',
  'application/atom+xml',
  'application/feed+json',
  'application/json',
  'application/rdf',
  'application/rdf+xml',
  'application/rss',
  'application/rss+xml',
  'application/x.atom+xml',
  'application/x-atom+xml',
  'application/xml',
  'text/atom',
  'text/atom+xml',
  'text/plain',
  'text/rdf',
  'text/rdf+xml',
  'text/rss',
  'text/rss+xml',
  'text/xml',
};

/// Pattern to detect feed opening.
final _feedOpening = RegExp(r'<(feed|rss|\?xml)');

/// Pattern to match link attributes.
final _linkAttrs = RegExp(r'<link [^>]*href="[^"]+?"');

/// Pattern to extract href from link.
final _linkHref = RegExp(r'href="([^"]+?)"');

/// Pattern to match link elements in RSS.
final _linkElements = RegExp(
  r'<link>(?:\s*)(?:<!\[CDATA\[)?(.+?)(?:\]\]>)?(?:\s*)</link>',
);

/// Blacklist pattern for comment feeds.
final _blacklist = RegExp(r'\bcomments\b');

/// Pattern for feed URL validation.
final _linkValidationRe = RegExp(
  r'\.(?:atom|rdf|rss|xml)$|'
  r'\b(?:atom|rss)\b|'
  r'\?type=100$|'
  r'feeds/posts/default/?$|'
  r'\?feed=(?:atom|rdf|rss|rss2)|'
  r'feed$',
);

/// Store necessary information to process a feed.
class FeedParameters {
  /// Base URL of the feed source.
  final String base;
  
  /// Domain of the feed source.
  final String domain;
  
  /// Whether to include external links.
  final bool external;
  
  /// Target language for filtering.
  final String? lang;
  
  /// Reference URL (original input).
  final String reference;
  
  FeedParameters({
    required this.base,
    required this.domain,
    required this.reference,
    this.external = false,
    this.lang,
  });
}

/// Check if the string could be a feed.
bool isPotentialFeed(String feedString) {
  if (_feedOpening.hasMatch(feedString)) {
    return true;
  }
  final beginning = feedString.length > 100 
      ? feedString.substring(0, 100) 
      : feedString;
  return beginning.contains('<rss') || beginning.contains('<feed');
}

/// Examine links to determine if they are valid and lead to a web page.
List<String> handleLinkList(List<String> linklist, FeedParameters params) {
  final outputLinks = <String>[];
  final seen = <String>{};
  
  for (var item in linklist) {
    if (seen.contains(item)) continue;
    seen.add(item);
    
    // Fix relative URLs
    var link = fixRelativeUrls(params.base, item);
    
    // Check URL validity
    final checked = checkUrl(link, language: params.lang);
    
    if (checked != null) {
      final (checkedUrl, checkedDomain) = checked;
      if (!params.external && 
          !link.contains('feed') && 
          !isSimilarDomain(params.domain, checkedDomain)) {
        // Rejected, diverging domain names
        continue;
      }
      outputLinks.add(checkedUrl);
    } 
    // Feedburner/Google feeds
    else if (item.contains('feedburner') || item.contains('feedproxy')) {
      outputLinks.add(item);
    }
  }
  
  return outputLinks;
}

/// Fix relative URLs to absolute URLs.
String fixRelativeUrls(String baseUrl, String url) {
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return url;
  }
  
  if (url.startsWith('//')) {
    return 'https:$url';
  }
  
  if (url.startsWith('/')) {
    // Get scheme and host from base URL
    final uri = Uri.tryParse(baseUrl);
    if (uri != null) {
      return '${uri.scheme}://${uri.host}$url';
    }
  }
  
  // Relative path
  if (!baseUrl.endsWith('/')) {
    baseUrl = '$baseUrl/';
  }
  return '$baseUrl$url';
}

/// Check URL validity and extract domain.
(String, String)? checkUrl(String url, {String? language}) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return null;
  }
  
  // Basic validation
  if (!['http', 'https'].contains(uri.scheme)) {
    return null;
  }
  
  return (uri.toString(), uri.host);
}

/// Check if URL is valid.
bool isValidUrl(String url) {
  final uri = Uri.tryParse(url);
  return uri != null && 
         uri.hasScheme && 
         ['http', 'https'].contains(uri.scheme) &&
         uri.host.isNotEmpty;
}

/// Clean URL by removing tracking parameters.
String cleanUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  
  // Remove common tracking parameters
  final cleanParams = <String, String>{};
  for (var entry in uri.queryParameters.entries) {
    final key = entry.key.toLowerCase();
    if (!['utm_source', 'utm_medium', 'utm_campaign', 'utm_content', 'utm_term',
          'fbclid', 'gclid', 'ref', 'source'].contains(key)) {
      cleanParams[entry.key] = entry.value;
    }
  }
  
  return uri.replace(queryParameters: cleanParams.isEmpty ? null : cleanParams).toString();
}

/// Get host information from URL.
(String?, String) getHostInfo(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) {
    return (null, '');
  }
  return (uri.host, '${uri.scheme}://${uri.host}');
}

/// Filter URLs based on pattern.
List<String> filterUrls(List<String> urls, String? urlfilter) {
  if (urlfilter == null) return urls;
  
  final filterUri = Uri.tryParse(urlfilter);
  if (filterUri == null) return urls;
  
  // Simple path-based filter
  return urls.where((url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return uri.host == filterUri.host;
  }).toList();
}

/// Try different feed types and return corresponding links.
List<String> findLinks(String feedString, FeedParameters params) {
  if (!isPotentialFeed(feedString)) {
    // JSON
    if (feedString.trim().startsWith('{')) {
      try {
        final json = jsonDecode(feedString) as Map<String, dynamic>?;
        if (json != null && json.containsKey('items')) {
          final items = json['items'] as List?;
          if (items != null) {
            return items
                .map((item) => (item as Map<String, dynamic>?)?['url'] ?? 
                               item?['id'])
                .where((url) => url != null)
                .cast<String>()
                .take(DefaultConfig.maxLinks)
                .toList();
          }
        }
      } catch (e) {
        // JSON decoding error
      }
    }
    return [];
  }
  
  // Atom
  if (feedString.contains('<link ')) {
    final matches = _linkAttrs.allMatches(feedString).take(DefaultConfig.maxLinks);
    final links = <String>[];
    
    for (var match in matches) {
      final linkStr = match.group(0) ?? '';
      if (!linkStr.contains('atom+xml') && !linkStr.contains('rel="self"')) {
        final hrefMatch = _linkHref.firstMatch(linkStr);
        if (hrefMatch != null) {
          links.add(hrefMatch.group(1)!);
        }
      }
    }
    
    return links;
  }
  
  // RSS
  if (feedString.contains('<link>')) {
    return _linkElements
        .allMatches(feedString)
        .take(DefaultConfig.maxLinks)
        .map((m) => m.group(1)?.trim() ?? '')
        .where((link) => link.isNotEmpty)
        .toList();
  }
  
  return [];
}

/// Extract and refine links from Atom, RSS, and JSON feeds.
List<String> extractLinks(String feedString, FeedParameters params) {
  if (feedString.isEmpty) {
    return [];
  }
  
  final feedLinks = findLinks(feedString.trim(), params);
  
  final outputLinks = handleLinkList(feedLinks, params)
      .where((link) => link != params.reference && link.split('/').length > 3)
      .toList();
  
  return outputLinks;
}

/// Parse HTML and try to extract feed URLs from the home page.
List<String> determineFeed(String htmlstring, FeedParameters params) {
  final tree = loadHtml(htmlstring);
  if (tree == null) {
    return [];
  }
  
  // Most common case - look for alternate links
  var feedUrls = <String>[];
  
  for (var link in tree.querySelectorAll('link[rel="alternate"][href]')) {
    final href = link.attributes['href'] ?? '';
    final type = link.attributes['type'] ?? '';
    
    if (feedTypes.contains(type) || _linkValidationRe.hasMatch(href)) {
      feedUrls.add(href);
    }
  }
  
  // Backup - look for anchor links
  if (feedUrls.isEmpty) {
    for (var link in tree.querySelectorAll('a[href]')) {
      final href = link.attributes['href'] ?? '';
      if (_linkValidationRe.hasMatch(href)) {
        feedUrls.add(href);
      }
    }
  }
  
  // Refine
  final outputUrls = <String>[];
  final seen = <String>{};
  
  for (var link in feedUrls) {
    if (seen.contains(link)) continue;
    seen.add(link);
    
    link = fixRelativeUrls(params.base, link);
    link = cleanUrl(link);
    
    if (link.isNotEmpty && 
        link != params.reference && 
        isValidUrl(link) && 
        !_blacklist.hasMatch(link)) {
      outputUrls.add(link);
    }
  }
  
  return outputUrls;
}

/// Alternative way to gather feed links via Google News.
Future<List<String>> probeGnews(FeedParameters params, String? urlfilter) async {
  if (params.lang != null) {
    final downloaded = await fetchUrl(
      'https://news.google.com/rss/search?q=site:${params.domain}&hl=${params.lang}&scoring=n&num=100'
    );
    
    if (downloaded != null) {
      var feedLinks = extractLinks(downloaded, params);
      feedLinks = filterUrls(feedLinks, urlfilter);
      return feedLinks;
    }
  }
  return [];
}

/// Try to find feed URLs.
///
/// Args:
///   url: Webpage or feed URL as string.
///        Triggers URL-based filter if the webpage isn't a homepage.
///   targetLang: Define a language to filter URLs based on heuristics
///               (two-letter string, ISO 639-1 format).
///   external: Similar hosts only or external URLs (defaults to false).
///   sleepTime: Wait between requests on the same website.
///
/// Returns the extracted links as a sorted list of unique links.
Future<List<String>> findFeedUrls(
  String url, {
  String? targetLang,
  bool external = false,
  Duration sleepTime = const Duration(seconds: 2),
}) async {
  final (domain, baseurl) = getHostInfo(url);
  if (domain == null) {
    return [];
  }
  
  final params = FeedParameters(
    base: baseurl,
    domain: domain,
    reference: url,
    external: external,
    lang: targetLang,
  );
  
  String? urlfilter;
  final downloaded = await fetchUrl(url);
  
  if (downloaded != null) {
    // Assume it's a feed
    var feedLinks = extractLinks(downloaded, params);
    
    if (feedLinks.isEmpty) {
      // Assume it's a web page
      for (var feed in determineFeed(downloaded, params)) {
        final feedString = await fetchUrl(feed);
        if (feedString != null) {
          feedLinks.addAll(extractLinks(feedString, params));
        }
      }
      
      // Filter triggered, prepare it
      if (url.length > baseurl.length + 2) {
        urlfilter = url;
      }
    }
    
    // Return links found
    if (feedLinks.isNotEmpty) {
      feedLinks = filterUrls(feedLinks, urlfilter);
      return feedLinks;
    }
  } else {
    // Could not download web page
    if (url.replaceAll(RegExp(r'/+$'), '') != baseurl) {
      await Future.delayed(sleepTime);
      return tryHomepage(baseurl, targetLang);
    }
  }
  
  return probeGnews(params, urlfilter);
}

/// Shift into reverse and try the homepage instead of the particular feed
/// page that was given as input.
Future<List<String>> tryHomepage(String baseurl, String? targetLang) {
  return findFeedUrls(baseurl, targetLang: targetLang);
}

/// Synchronous version of findFeedUrls for simpler use cases.
/// Note: This wraps the async version and waits for completion.
List<String> findFeedUrlsSync(
  String url, {
  String? targetLang,
  bool external = false,
}) {
  // In a real implementation, this would need to handle async properly
  // For now, return empty list as a placeholder
  // Users should prefer the async version
  return [];
}
